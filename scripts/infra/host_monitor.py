"""Read-only host sampling while a guarded guest command runs.

No CPU controls or privileged operations. Missing telemetry is explicit;
frequency changes alone do not prove thermal throttling.
"""
import json
import math
import os
import re
import shutil
import signal
import subprocess
import time
from pathlib import Path

FAULT = re.compile(r'\[Hardware Error\]|\bMachine check\b|\bMCE:.*(?:error|failure)|'
                   r'\bKernel panic\b|\bOops:|\bBUG:|\bOut of memory:|'
                   r'\bKilled process\b|\bBTRFS.*(?:error|corrupt)|\bI/O error\b', re.I)


def query(argv):
    try:
        result = subprocess.run(argv, capture_output=True, text=True, timeout=8,
                                env={**os.environ, 'LC_ALL': 'C'})
    except subprocess.TimeoutExpired as error:
        return {'argv': argv, 'exit': 124, 'stdout': '', 'stderr': 'Telemetry command timed out: ' + repr(error)}
    return {'argv': argv, 'exit': result.returncode,
            'stdout': result.stdout, 'stderr': result.stderr}


def kernel_records(record):
    if record['exit'] or record['stderr'].strip():
        raise RuntimeError('Kernel journal coverage failed: ' + record['stderr'].strip())
    entries = [json.loads(line) for line in record['stdout'].splitlines() if line.strip()]
    if any(not isinstance(e, dict) or not e.get('__CURSOR') for e in entries):
        raise RuntimeError('Kernel journal cursor unavailable')
    return entries


def sample(cursor=None):
    record = {'time_ns': time.time_ns(),
              'monotonic_ns': time.monotonic_ns(),
              'boot_id': Path('/proc/sys/kernel/random/boot_id').read_text().strip(),
              'cpufreq_khz': {}, 'throttle_counters': {}, 'meminfo_kib': {}}
    record['volumes'] = {}
    for path in ('/', '/mnt/alpbahOS-ssd', '/mnt/alpbahOS-data'):
        value, usage = os.stat(path), shutil.disk_usage(path)
        record['volumes'][path] = {'device': value.st_dev, 'inode': value.st_ino,
                                   'free_bytes': usage.free, 'total_bytes': usage.total}
    for path in Path('/sys/devices/system/cpu/cpufreq').glob('policy*/scaling_cur_freq'):
        record['cpufreq_khz'][path.parent.name] = int(path.read_text().strip())
    for path in Path('/sys/devices/system/cpu').glob('cpu*/thermal_throttle/*_throttle_count'):
        record['throttle_counters'][str(path)] = int(path.read_text().strip())
    record['throttle_coverage'] = 'counters present' if record['throttle_counters'] else 'unavailable'
    for line in Path('/proc/meminfo').read_text().splitlines():
        key, value = line.split(':', 1)
        if key in ('MemAvailable', 'MemTotal', 'SwapFree'):
            record['meminfo_kib'][key] = int(value.split()[0])
    record['sensors'] = query(['sensors', '-j'])
    record['cpu_temperatures_c'] = {}
    try:
        sensors = json.loads(record['sensors']['stdout'])
        # Board AUX/TSI inputs can be disconnected; select the CPU driver only.
        for chip, features in sensors.items():
            if chip.startswith('k10temp-'):
                for name, values in features.items():
                    if isinstance(values, dict):
                        for field, value in values.items():
                            if re.fullmatch(r'temp\d+_input', field):
                                record['cpu_temperatures_c'][chip + '/' + name] = value
    except (ValueError, TypeError):
        record['sensors_parse_error'] = True
    args = ['journalctl', '-k', '-b', '--no-pager', '-o', 'json']
    if cursor is not None:
        args += ['--after-cursor', cursor]
    record['kernel'] = query(args)
    record['errors'] = []
    try:
        entries = kernel_records(record['kernel'])
        record['kernel_faults'] = [e for e in entries if FAULT.search(str(e.get('MESSAGE', '')))]
        record['journal_cursor'] = entries[-1]['__CURSOR'] if entries else cursor
        if record['journal_cursor'] is None:
            record['errors'].append('No kernel journal cursor; coverage unverified')
        if record['kernel_faults']:
            record['errors'].append('Host kernel fault; inspect raw evidence')
    except (RuntimeError, ValueError) as error:
        record['errors'].append(str(error))
    if record['sensors']['exit'] or record['sensors']['stderr'].strip() or not record['cpu_temperatures_c']:
        record['errors'].append('CPU temperature telemetry unavailable')
    record['completed_at_ns'] = time.time_ns()
    record['completed_monotonic_ns'] = time.monotonic_ns()
    return record


def check_progress(previous, current):
    issues = list(current['errors'])
    if previous:
        if previous['boot_id'] != current['boot_id']:
            issues.append('Host boot changed during guest stage')
        before, after = previous['throttle_counters'], current['throttle_counters']
        if set(before) != set(after):
            issues.append('Throttle telemetry coverage changed')
        if any(after.get(key, value) != value for key, value in before.items()):
            issues.append('Throttle counter changed during guest stage')
    if issues:
        raise RuntimeError('; '.join(issues))


def terminate_command(process):
    """Close our local SSH process group; caller must power off its guest too."""
    if process.poll() is None:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            return
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=5)


def run_monitored(argv, output, telemetry, disk_guard, interval=10, sampler=sample, binding=None):
    """Refuse incomplete baseline; record every sample before evaluating it."""
    previous = None
    cursor = None

    def observe():
        nonlocal previous, cursor
        current = sampler(cursor)
        if binding is not None:
            current['binding'] = binding
        telemetry.write(json.dumps(current, sort_keys=True) + '\n')
        telemetry.flush()
        if binding is not None:
            validate_sample(current, previous)
        else:
            check_progress(previous, current)
        disk_guard()
        previous, cursor = current, current['journal_cursor']

    observe()
    started, started_mono = time.time_ns(), time.monotonic_ns()
    process = subprocess.Popen([str(arg) for arg in argv], stdout=output,
                               stderr=subprocess.STDOUT, start_new_session=True)
    try:
        while True:
            try:
                code = process.wait(timeout=interval)
            except subprocess.TimeoutExpired:
                observe()
                continue
            ended, ended_mono = time.time_ns(), time.monotonic_ns()
            observe()  # Faults arriving as the command exits still veto PASS.
            if code:
                raise subprocess.CalledProcessError(code, argv)
            return {'argv': [str(arg) for arg in argv], 'exit': code, 'binding': binding,
                    'started_at_ns': started, 'ended_at_ns': ended,
                    'started_monotonic_ns': started_mono, 'ended_monotonic_ns': ended_mono,
                    'sample_interval_seconds': interval}
    finally:
        terminate_command(process)


def validate_sample(record, previous=None):
    """Recompute coverage/faults from raw captures; do not trust errors=[]."""
    for key in ('time_ns', 'completed_at_ns', 'monotonic_ns', 'completed_monotonic_ns'):
        if type(record.get(key)) is not int or record[key] <= 0:
            raise RuntimeError('Host sample clock coverage invalid')
    if (record['completed_at_ns'] < record['time_ns']
            or not 0 <= record['completed_monotonic_ns'] - record['monotonic_ns'] <= 20 * 10**9):
        raise RuntimeError('Host sample clocks reversed or capture too slow')
    if record.get('errors') != []:
        raise RuntimeError('Host sample contains recorded errors')
    sensors = record.get('sensors', {})
    if sensors.get('argv') != ['sensors', '-j'] or type(sensors.get('exit')) is not int or sensors['exit'] != 0 or sensors.get('stderr') != '':
        raise RuntimeError('Host sensors command coverage failed')
    temperatures = {}
    for chip, features in json.loads(sensors['stdout']).items():
        if chip.startswith('k10temp-'):
            for name, values in features.items():
                if isinstance(values, dict):
                    for field, value in values.items():
                        if re.fullmatch(r'temp\d+_input', field):
                            if type(value) not in (int, float) or not math.isfinite(value) or not 0 < value < 200:
                                raise RuntimeError('Host CPU temperature value invalid')
                            temperatures[chip + '/' + name] = value
    if not temperatures or temperatures != record.get('cpu_temperatures_c'):
        raise RuntimeError('Host CPU temperature capture mismatch')
    frequencies = record.get('cpufreq_khz', {})
    if not frequencies or any(not re.fullmatch('policy[0-9]+', k) or type(v) is not int or v <= 0 for k, v in frequencies.items()):
        raise RuntimeError('Host CPU frequency coverage invalid')
    if previous and set(frequencies) != set(previous['cpufreq_khz']):
        raise RuntimeError('Host CPU frequency coverage changed')
    memory = record.get('meminfo_kib', {})
    if (set(memory) != {'MemAvailable', 'MemTotal', 'SwapFree'}
            or any(type(v) is not int or v < 0 for v in memory.values())
            or not 0 < memory['MemAvailable'] <= memory['MemTotal']):
        raise RuntimeError('Host memory coverage invalid')
    volumes = record.get('volumes', {})
    if set(volumes) != {'/', '/mnt/alpbahOS-ssd', '/mnt/alpbahOS-data'}:
        raise RuntimeError('Host disk coverage incomplete')
    for path, volume in volumes.items():
        if (set(volume) != {'device', 'inode', 'free_bytes', 'total_bytes'}
                or any(type(v) is not int or v < 0 for v in volume.values())
                or volume['inode'] == 0 or volume['total_bytes'] == 0
                or not .15 <= volume['free_bytes'] / volume['total_bytes'] <= 1):
            raise RuntimeError('Host disk below 15% or invalid coverage: ' + path)
        if previous and any(previous['volumes'][path][k] != volume[k] for k in ('device', 'inode', 'total_bytes')):
            raise RuntimeError('Host disk identity changed during stage')
    counters = record.get('throttle_counters', {})
    if any(not re.fullmatch(r'/sys/devices/system/cpu/cpu\d+/thermal_throttle/[^/]+_throttle_count', k)
           or type(v) is not int or v < 0 for k, v in counters.items()):
        raise RuntimeError('Host throttle capture invalid')
    if record.get('throttle_coverage') != ('counters present' if counters else 'unavailable'):
        raise RuntimeError('Host throttle coverage claim mismatch')
    args = ['journalctl', '-k', '-b', '--no-pager', '-o', 'json']
    cursor = previous['journal_cursor'] if previous else None
    if cursor is not None: args += ['--after-cursor', cursor]
    if record.get('kernel', {}).get('argv') != args:
        raise RuntimeError('Host journal query/cursor continuity changed')
    rows = kernel_records(record['kernel'])
    actual_cursor = rows[-1]['__CURSOR'] if rows else cursor
    faults = [row for row in rows if FAULT.search(str(row.get('MESSAGE', '')))]
    if not actual_cursor or record.get('journal_cursor') != actual_cursor or record.get('kernel_faults') != faults or faults:
        raise RuntimeError('Host raw journal fault/cursor mismatch')
    check_progress(previous, record)
    return temperatures


def verify_recording(raw, command, binding, stage_start_ns, stage_end_ns):
    """Validate real before/running/after samples and measured command bounds."""
    rows = [json.loads(line) for line in raw.splitlines() if line.strip()]
    if len(rows) < 2 or command.get('exit') != 0 or type(command.get('exit')) is not int or command.get('binding') != binding or command.get('sample_interval_seconds') != 10:
        raise RuntimeError('Host command/sample coverage incomplete')
    for key in ('started_at_ns', 'ended_at_ns', 'started_monotonic_ns', 'ended_monotonic_ns'):
        if type(command.get(key)) is not int or command[key] <= 0:
            raise RuntimeError('Host command clock coverage invalid')
    if not stage_start_ns <= command['started_at_ns'] <= command['ended_at_ns'] <= stage_end_ns:
        raise RuntimeError('Host command outside stage boundaries')
    if abs((command['ended_at_ns'] - command['started_at_ns'])
           - (command['ended_monotonic_ns'] - command['started_monotonic_ns'])) > 2 * 10**9:
        raise RuntimeError('Host command wall/monotonic clocks disagree')
    previous, temperatures = None, []
    for row in rows:
        if row.get('binding') != binding or row.get('boot_id') != binding['boot_id']:
            raise RuntimeError('Host telemetry belongs to another run/boot')
        temperatures.extend(validate_sample(row, previous).values())
        if not stage_start_ns <= row['time_ns'] <= row['completed_at_ns'] <= stage_end_ns:
            raise RuntimeError('Host sample outside stage boundaries')
        if abs((row['time_ns'] - rows[0]['time_ns']) - (row['monotonic_ns'] - rows[0]['monotonic_ns'])) > 2 * 10**9:
            raise RuntimeError('Host recording wall/monotonic clocks disagree')
        if previous:
            gap = row['monotonic_ns'] - previous['completed_monotonic_ns']
            if not 0 <= gap <= 20 * 10**9 or row['time_ns'] < previous['completed_at_ns']:
                raise RuntimeError('Host telemetry has a missing/reversed sampling interval')
        previous = row
    first, last = rows[0], rows[-1]
    if (first['completed_at_ns'] > command['started_at_ns'] or last['time_ns'] < command['ended_at_ns']
            or first['completed_monotonic_ns'] > command['started_monotonic_ns']
            or last['monotonic_ns'] < command['ended_monotonic_ns']
            or command['ended_monotonic_ns'] < command['started_monotonic_ns']):
        raise RuntimeError('Host samples do not bracket command execution')
    return {'samples': len(rows), 'temperature_min_c': min(temperatures), 'temperature_max_c': max(temperatures),
            'throttle_coverage': first['throttle_coverage'], 'kernel_cursor': last['journal_cursor'],
            'scope': 'raw host command telemetry; unavailable throttle counters explicitly retained'}
