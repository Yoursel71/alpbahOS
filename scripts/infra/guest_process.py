"""Space monitoring for a guest command and its child process group.

The monitor itself is privilege-neutral for isolated tests. Production calls
must first pass the guest disk/writer guard; this module has no CLI.
"""
import json
import os
import shutil
import signal
import subprocess
import time
from pathlib import Path


def sample_space():
    volumes = {}
    for path in (Path('/'), Path('/srv/lfs')):
        usage, identity = shutil.disk_usage(path), path.stat()
        volumes[str(path)] = {'total': usage.total, 'available': usage.free,
                              'device': identity.st_dev, 'inode': identity.st_ino}
    return {'time_ns': time.time_ns(), 'volumes': volumes}


def check_space(previous, current):
    volumes = current.get('volumes')
    if not isinstance(volumes, dict) or set(volumes) != {'/', '/srv/lfs'}:
        raise RuntimeError('Guest space telemetry coverage invalid')
    for path, values in volumes.items():
        if not isinstance(values, dict) or any(type(values.get(field)) is not int or values[field] < 0
               for field in ('total', 'available', 'device', 'inode')) or not values['total'] or values['available'] > values['total']:
            raise RuntimeError('Guest space telemetry values invalid')
        if values['available'] * 100 < values['total'] * 15:
            raise RuntimeError('Guest free space below 15%: ' + path)
        if previous and any(previous['volumes'][path][field] != values[field] for field in ('device', 'inode')):
            raise RuntimeError('Guest filesystem identity changed: ' + path)


def stop_group(process, grace=5):
    # Group leaders can already have exited while descendants still write.
    def signal_group(sig):
        try:
            os.killpg(process.pid, sig)
        except ProcessLookupError:
            return False
        return True

    if signal_group(signal.SIGTERM):
        deadline = time.monotonic() + grace
        while time.monotonic() < deadline:
            process.poll()
            if not signal_group(0):
                break
            time.sleep(.05)
        signal_group(signal.SIGKILL)
    process.wait(timeout=5)


def monitor_command(argv, stdout, stderr, telemetry, cwd=None, env=None,
                    input=None, text=False, interval=5, sampler=sample_space):
    """No runtime cutoff. Fail before launch, during wait, and after exit."""
    if not 0 < interval <= 5:
        raise ValueError('Guest space sampling interval must be at most five seconds')
    if input is not None and (not isinstance(input, (str, bytes)) or len(input.encode() if isinstance(input, str) else input) > 4096):
        raise ValueError('Only small explicit command input is supported')
    previous = None

    def observe(event):
        nonlocal previous
        try:
            current = sampler()
        except Exception as error:
            telemetry.write(json.dumps({'event': event, 'time_ns': time.time_ns(), 'sample_error': repr(error)}) + '\n')
            telemetry.flush()
            raise RuntimeError('Guest space telemetry failed: ' + repr(error)) from error
        telemetry.write(json.dumps({'event': event, **current}, sort_keys=True) + '\n')
        telemetry.flush()
        check_space(previous, current)
        previous = current

    observe('before-command')
    process = subprocess.Popen([str(arg) for arg in argv], cwd=cwd, env=env,
        stdout=stdout, stderr=stderr, stdin=subprocess.PIPE if input is not None else subprocess.DEVNULL,
        text=text, start_new_session=True)
    try:
        telemetry.write(json.dumps({'event': 'command-started', 'pid': process.pid, 'argv': [str(a) for a in argv]}) + '\n')
        telemetry.flush()
        if input is not None:
            try:
                process.stdin.write(input)
                process.stdin.flush()
            except BrokenPipeError:
                pass  # The child's actual exit status still decides acceptance.
            finally:
                try:
                    process.stdin.close()
                except BrokenPipeError:
                    pass
        while True:
            try:
                code = process.wait(timeout=interval)
            except subprocess.TimeoutExpired:
                observe('command-running')
                continue
            observe('after-command')
            if code:
                raise subprocess.CalledProcessError(code, argv)
            return
    finally:
        stop_group(process)


def guarded_log(log):
    """Production guard occurs before any evidence file or child is opened."""
    from package_install import guest_install_guard, LFS
    guest_install_guard(LFS, log.parent)
    for path in (log, log.with_name(log.name + '.space.jsonl')):
        if path.resolve() != path or path.is_symlink():
            raise RuntimeError('Guest command log path is unresolved/symlink')


def run_logged(argv, log, cwd=None, env=None):
    guarded_log(log)
    with log.open('ab') as output, log.with_name(log.name + '.space.jsonl').open('a') as telemetry:
        output.write(('COMMAND ' + repr(argv) + '\n').encode()); output.flush()
        monitor_command(argv, output, subprocess.STDOUT, telemetry, cwd=cwd, env=env)
