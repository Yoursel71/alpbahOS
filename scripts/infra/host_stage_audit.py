"""User-run read-only root audit and unprivileged stage-bound verification.

Root mode executes fixed inspection commands and writes only its
fixed root-owned evidence store. Request data never supplies commands/paths.
This file imports only stdlib so the human can run it with python3 -I.
"""
import argparse
import hashlib
import json
import os
import re
import secrets
import stat
import subprocess
import time
from pathlib import Path

REQUESTS = Path('/mnt/alpbahOS-data/alpbahos-infra-rebuild/state/audit-requests')
STORE = Path('/var/lib/alpbahos-infra-audits')
BOOT = Path('/proc/sys/kernel/random/boot_id')
USER_UID = USER_GID = 1000
SCHEMA = 'alpbahOS.stage-audit-request/v2'
STAGES = ('stability', 'toolchain', 'base', 'kernel', 'blfs-core', 'plasma', 'profiles', 'iso')
VERIFY_SCRIPT_QUERY = ['/usr/bin/rpm', '-qa', '--queryformat', '%|VERIFYSCRIPT?{%{NAME}\\n}:{}|']
COMMANDS = {'scripts_before': VERIFY_SCRIPT_QUERY,
            'rpm': ['/usr/bin/rpm', '-Va', '--noscript'],
            'scripts_after': VERIFY_SCRIPT_QUERY,
            'kernel': ['/usr/bin/journalctl', '-k', '-b', '--no-pager', '-o', 'json']}
FAULT = re.compile(r'\[Hardware Error\]|\bMachine check\b|\bMCE:.*(?:error|failure)|'
                   r'\bKernel panic\b|\bOops:|\bBUG:|\bOut of memory:|'
                   r'\bKilled process\b|\bBTRFS.*(?:error|corrupt)|\bI/O error\b', re.I)
# Same-boot, root-captured audit before a Builder stage. The exact observed
# host state includes the existing Windows EFI chainloader stanza in
# /etc/grub.d/40_custom. Permit only this RPM verification output; any further
# file or metadata drift changes the digest and stops the stage.
KNOWN_RPM_BASELINE_SHA256 = '2ae99151a7213553c55656e37637870996a85e9cdceefea62d53ddd0370c2ead'


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def checked_request(raw, now_ns=None):
    value = json.loads(raw)
    keys = {'schema', 'stage', 'phase', 'run_id', 'audit_id', 'boot_id', 'inputs_sha256', 'sources_sha256', 'requested_at_ns', 'outcome_sha256'}
    if (not isinstance(value, dict) or set(value) != keys or value['schema'] != SCHEMA
            or value['stage'] not in STAGES or value['phase'] not in ('before', 'after')
            or not isinstance(value['run_id'], str) or not re.fullmatch('[0-9a-f]{32}', value['run_id'])
            or not isinstance(value['audit_id'], str) or not re.fullmatch('[0-9a-f]{32}', value['audit_id'])
            or not isinstance(value['boot_id'], str) or not re.fullmatch('[0-9a-f-]{36}', value['boot_id'])
            or any(not isinstance(value[key], str) or not re.fullmatch('[0-9a-f]{64}', value[key])
                   for key in ('inputs_sha256', 'sources_sha256'))
            or type(value['requested_at_ns']) is not int
            or (value['phase'] == 'before' and value['outcome_sha256'] is not None)
            or (value['phase'] == 'after' and (not isinstance(value['outcome_sha256'], str)
                    or not re.fullmatch('[0-9a-f]{64}', value['outcome_sha256'])))):
        raise RuntimeError('Stage audit request schema/identity invalid')
    now_ns = time.time_ns() if now_ns is None else now_ns
    if not 0 <= now_ns - value['requested_at_ns'] <= 24 * 3600 * 10**9:
        raise RuntimeError('Stage audit request stale/future')
    if value['boot_id'] != BOOT.read_text().strip():
        raise RuntimeError('Stage audit request boot changed')
    return value


def directory_fd(path, root_owned=False):
    """Traverse pinned directory components without following symlinks."""
    path = Path(path)
    if not path.is_absolute() or '..' in path.parts:
        raise RuntimeError('Audit directory must be absolute/canonical')
    fd = os.open('/', os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        value = os.fstat(fd)
        if root_owned and (value.st_uid != 0 or value.st_mode & 0o022):
            raise RuntimeError('Audit filesystem root is not protected root-owned')
        for name in path.parts[1:]:
            child = os.open(name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd); fd = child
            value = os.fstat(fd)
            if root_owned and (value.st_uid != 0 or value.st_mode & 0o022):
                raise RuntimeError('Audit store ancestor is not protected root-owned')
        return fd
    except BaseException:
        os.close(fd); raise


def read_file(path, owner, maximum=64 * 1024**2):
    fd = directory_fd(path.parent, root_owned=owner == 0)
    try:
        file_fd = os.open(path.name, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=fd)
        with os.fdopen(file_fd, 'rb') as stream:
            value = os.fstat(stream.fileno())
            if (not stat.S_ISREG(value.st_mode) or value.st_uid != owner or value.st_nlink != 1
                    or value.st_mode & 0o022 or value.st_size > maximum):
                raise RuntimeError('Audit file type/owner/links/mode/size invalid')
            raw = stream.read(maximum + 1)
            if len(raw) > maximum:
                raise RuntimeError('Audit file exceeds evidence bound')
            return raw
    finally:
        os.close(fd)


def request(stage, phase, run_id, inputs_sha256, sources_sha256, outcome_sha256=None):
    if os.geteuid() != USER_UID:
        raise RuntimeError('Audit request is unprivileged host-user only')
    value = {'schema': SCHEMA, 'stage': stage, 'phase': phase, 'run_id': run_id,
             'audit_id': secrets.token_hex(16),
             'outcome_sha256': outcome_sha256,
             'inputs_sha256': inputs_sha256, 'sources_sha256': sources_sha256,
             'boot_id': BOOT.read_text().strip(), 'requested_at_ns': time.time_ns()}
    raw = (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()
    checked_request(raw)
    fd = directory_fd(REQUESTS.parent)
    try:
        try:
            os.mkdir(REQUESTS.name, 0o700, dir_fd=fd)
        except FileExistsError:
            pass
        child = os.open(REQUESTS.name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
        try:
            if os.fstat(child).st_uid != USER_UID or os.fstat(child).st_mode & 0o077:
                raise RuntimeError('Audit request directory must be private user-owned')
            name = run_id + '-' + phase + '-' + value['audit_id'] + '.json'
            output = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=child)
            with os.fdopen(output, 'wb') as stream:
                stream.write(raw); stream.flush(); os.fsync(stream.fileno())
            os.fsync(child)
        finally:
            os.close(child)
    finally:
        os.close(fd)
    return REQUESTS / name, digest(raw)


def root_child(parent, name):
    try:
        os.mkdir(name, 0o750, dir_fd=parent)
        created = True
    except FileExistsError:
        created = False
    fd = os.open(name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=parent)
    if created:
        os.fchown(fd, 0, USER_GID); os.fchmod(fd, 0o750)
    value = os.fstat(fd)
    if value.st_uid != 0 or value.st_gid != USER_GID or value.st_mode & 0o022:
        os.close(fd); raise RuntimeError('Audit output directory is not protected root-owned')
    return fd


def write_root(fd, name, raw):
    output = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o640, dir_fd=fd)
    with os.fdopen(output, 'wb') as stream:
        os.fchown(stream.fileno(), 0, USER_GID); os.fchmod(stream.fileno(), 0o640)
        stream.write(raw); stream.flush(); os.fsync(stream.fileno())


def inspect_outputs(outputs):
    """Pure content validation; caller separately verifies root provenance."""
    # --noscript prevents verifier script execution. Do not narrow coverage:
    # an installed verifier script at either endpoint rejects this audit.
    for name in ('scripts_before', 'scripts_after'):
        inventory = outputs[name]
        if inventory['exit'] != 0 or inventory['stdout'].strip() or inventory['stderr'].strip():
            raise RuntimeError('RPM verify-script inventory nonempty/unavailable; full verification needs review')
    rpm, kernel = outputs['rpm'], outputs['kernel']
    rpm_hash = digest(rpm['stdout'].encode())
    rpm_pristine = rpm['exit'] == 0 and not rpm['stdout'].strip() and not rpm['stderr'].strip()
    rpm_baseline = (rpm['exit'] == 1 and not rpm['stderr'].strip()
                    and rpm_hash == KNOWN_RPM_BASELINE_SHA256)
    if not rpm_pristine and not rpm_baseline:
        raise RuntimeError('Privileged stage RPM verification differs from pristine or pinned host baseline')
    if kernel['exit'] != 0 or kernel['stderr'].strip():
        raise RuntimeError('Privileged stage kernel journal coverage failed')
    rows = [json.loads(line) for line in kernel['stdout'].splitlines() if line.strip()]
    if not rows or any(not isinstance(row, dict) or not isinstance(row.get('__CURSOR'), str)
                       or not row['__CURSOR'] for row in rows):
        raise RuntimeError('Privileged stage kernel journal cursor coverage missing')
    if any(FAULT.search(str(row.get('MESSAGE', ''))) for row in rows):
        raise RuntimeError('Privileged stage kernel fault; retain evidence and STOP')
    return {'pristine_rpm': rpm_pristine, 'pinned_preexisting_rpm_baseline': rpm_baseline,
            'rpm_stdout_sha256': rpm_hash, 'verify_script_inventory_empty': True,
            'kernel_records': len(rows), 'kernel_cursor': rows[-1]['__CURSOR']}


def capture(request_path, request_sha256, script_sha256):
    if os.geteuid() != 0:
        raise RuntimeError('Root audit requires human-run root; agent must not invoke sudo')
    if digest(Path(__file__).read_bytes()) != script_sha256:
        raise RuntimeError('Root audit producer source hash changed')
    if request_path.parent != REQUESTS:
        raise RuntimeError('Root audit request path outside allowlist')
    raw = read_file(request_path, USER_UID, 65536)
    if digest(raw) != request_sha256:
        raise RuntimeError('Root audit request bytes changed')
    value = checked_request(raw)
    if request_path.name != value['run_id'] + '-' + value['phase'] + '-' + value['audit_id'] + '.json':
        raise RuntimeError('Root audit request filename/phase mismatch')
    outcome_path = REQUESTS.parent / 'stage-runs' / value['run_id'] / 'outcome.json'
    if value['phase'] == 'after' and digest(read_file(outcome_path, USER_UID)) != value['outcome_sha256']:
        raise RuntimeError('Root post audit outcome bytes changed before capture')
    parent = directory_fd(STORE.parent, root_owned=True)
    try:
        store = root_child(parent, STORE.name)
        try:
            run = root_child(store, value['run_id'])
            try:
                phase_parent = root_child(run, value['phase'])
                try:
                    # Every capture is single-use, including failed captures.
                    # A fresh audit_id preserves an earlier attempt for this job.
                    os.mkdir(value['audit_id'], 0o750, dir_fd=phase_parent)
                    phase = os.open(value['audit_id'], os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=phase_parent)
                    os.fchown(phase, 0, USER_GID); os.fchmod(phase, 0o750)
                finally:
                    os.close(phase_parent)
            finally:
                os.close(run)
        finally:
            os.close(store)
    finally:
        os.close(parent)
    metadata = {'schema': 'alpbahOS.root-stage-audit/v1', 'uid': os.geteuid(), 'request': value,
                'request_sha256': request_sha256, 'producer_sha256': script_sha256,
                'started_at_ns': time.time_ns(), 'boot_id': BOOT.read_text().strip(), 'commands': {}}
    outputs = {}
    try:
        for role, argv in COMMANDS.items():
            start = time.time_ns()
            try:
                result = subprocess.run(argv, capture_output=True, timeout=300,
                    env={'PATH': '/usr/bin:/bin', 'LC_ALL': 'C', 'LANG': 'C', 'TZ': 'UTC'})
                code, stdout, stderr = result.returncode, result.stdout, result.stderr
            except subprocess.TimeoutExpired as error:
                code, stdout, stderr = 124, error.stdout or b'', (error.stderr or b'') + b'\nAudit command timed out\n'
            end = time.time_ns()
            write_root(phase, role + '.stdout', stdout); write_root(phase, role + '.stderr', stderr)
            metadata['commands'][role] = {'argv': argv, 'exit': code, 'started_at_ns': start, 'ended_at_ns': end,
                'stdout': role + '.stdout', 'stderr': role + '.stderr',
                'stdout_sha256': digest(stdout), 'stderr_sha256': digest(stderr)}
            outputs[role] = {'exit': code, 'stdout': stdout.decode(errors='replace'), 'stderr': stderr.decode(errors='replace')}
        metadata['ended_at_ns'] = time.time_ns(); metadata['boot_id_after'] = BOOT.read_text().strip()
        try:
            metadata['coverage'] = inspect_outputs(outputs)
            if metadata['boot_id_after'] != value['boot_id'] or metadata['boot_id'] != value['boot_id']:
                raise RuntimeError('Host boot changed during privileged audit')
            if value['phase'] == 'after' and digest(read_file(outcome_path, USER_UID)) != value['outcome_sha256']:
                raise RuntimeError('Root post audit outcome bytes changed during capture')
            metadata['result'] = 'CAPTURED'
        except (RuntimeError, ValueError) as error:
            metadata['result'] = 'FAIL'; metadata['error'] = repr(error)
        write_root(phase, 'audit.json', (json.dumps(metadata, indent=2, sort_keys=True) + '\n').encode())
        os.fsync(phase)
    finally:
        os.close(phase)
    return STORE / value['run_id'] / value['phase'] / value['audit_id'] / 'audit.json', metadata


def verify(request_raw, producer_sha256, boundary_ns):
    value = checked_request(request_raw)
    root = STORE / value['run_id'] / value['phase'] / value['audit_id']
    raw = read_file(root / 'audit.json', 0)
    metadata = json.loads(raw)
    if (metadata.get('schema') != 'alpbahOS.root-stage-audit/v1' or type(metadata.get('uid')) is not int or metadata['uid'] != 0
            or metadata.get('result') != 'CAPTURED'
            or metadata.get('request') != value or metadata.get('request_sha256') != digest(request_raw)
            or metadata.get('producer_sha256') != producer_sha256
            or metadata.get('boot_id') != value['boot_id'] or metadata.get('boot_id_after') != value['boot_id']):
        raise RuntimeError('Root stage audit producer/request/boot identity mismatch')
    start, end = metadata.get('started_at_ns'), metadata.get('ended_at_ns')
    if (type(start) is not int or type(end) is not int or type(boundary_ns) is not int
            or not value['requested_at_ns'] <= start <= end <= time.time_ns()
            or (value['phase'] == 'before' and end > boundary_ns)
            or (value['phase'] == 'after' and start < boundary_ns)):
        raise RuntimeError('Root stage audit does not bracket current stage boundary')
    commands = metadata.get('commands', {})
    if set(commands) != set(COMMANDS):
        raise RuntimeError('Root stage audit command coverage incomplete')
    outputs, hashes = {}, {'audit.json': digest(raw)}
    previous_end = start
    for role, argv in COMMANDS.items():
        record = commands[role]
        command_start, command_end = record.get('started_at_ns'), record.get('ended_at_ns')
        if (record.get('argv') != argv or type(record.get('exit')) is not int
                or type(command_start) is not int or type(command_end) is not int
                or not previous_end <= command_start <= command_end <= end):
            raise RuntimeError('Root stage audit command/timing mismatch')
        previous_end = command_end
        outputs[role] = {'exit': record['exit']}
        for stream in ('stdout', 'stderr'):
            name = role + '.' + stream
            if record.get(stream) != name:
                raise RuntimeError('Root stage audit output filename mismatch')
            body = read_file(root / name, 0)
            if digest(body) != record.get(stream + '_sha256'):
                raise RuntimeError('Root stage audit raw bytes changed; STOP')
            hashes[name] = digest(body); outputs[role][stream] = body.decode(errors='replace')
    coverage = inspect_outputs(outputs)
    return {'scope': 'privileged host inspection only; guest/stage acceptance separate',
            'request_sha256': digest(request_raw), 'producer_sha256': producer_sha256,
            'artifact_sha256': hashes, 'started_at_ns': start, 'ended_at_ns': end, **coverage}


def verify_pair(before_raw, after_raw, producer_sha256, stage_start_ns, stage_end_ns):
    before, after = checked_request(before_raw), checked_request(after_raw)
    if (before['phase'] != 'before' or after['phase'] != 'after'
            or any(before[key] != after[key] for key in ('stage', 'run_id', 'boot_id', 'inputs_sha256', 'sources_sha256'))
            or type(stage_start_ns) is not int or type(stage_end_ns) is not int or stage_start_ns > stage_end_ns):
        raise RuntimeError('Privileged audit pair uses different stages/runs/inputs/boundaries')
    return {'scope': 'privileged host endpoints only; runtime/guest/stage acceptance separate',
            'before': verify(before_raw, producer_sha256, stage_start_ns),
            'after': verify(after_raw, producer_sha256, stage_end_ns)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action', required=True)
    capture_parser = sub.add_parser('capture')
    capture_parser.add_argument('--request', required=True, type=Path)
    capture_parser.add_argument('--request-sha256', required=True)
    capture_parser.add_argument('--script-sha256', required=True)
    request_parser = sub.add_parser('request')
    request_parser.add_argument('--stage', required=True, choices=STAGES)
    request_parser.add_argument('--phase', required=True, choices=('before', 'after'))
    request_parser.add_argument('--run-id', required=True)
    request_parser.add_argument('--inputs-sha256', required=True)
    request_parser.add_argument('--sources-sha256', required=True)
    request_parser.add_argument('--outcome-sha256')
    args = parser.parse_args()
    if args.action == 'request':
        path, checksum = request(args.stage, args.phase, args.run_id, args.inputs_sha256, args.sources_sha256, args.outcome_sha256)
        print(json.dumps({'request': str(path), 'request_sha256': checksum,
            'root_command_argv': ['sudo', 'python3', '-I', str(Path(__file__).resolve()), 'capture',
                '--request', str(path), '--request-sha256', checksum,
                '--script-sha256', digest(Path(__file__).read_bytes())]}, sort_keys=True))
        return 0
    path, result = capture(args.request, args.request_sha256, args.script_sha256)
    print(json.dumps({'metadata': str(path), **result}, sort_keys=True))
    return 0 if result['result'] == 'CAPTURED' else 1


if __name__ == '__main__':
    raise SystemExit(main())
