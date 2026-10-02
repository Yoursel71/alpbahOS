"""Single-use host jobs, privileged before binding and post audit requests.

Caller owns the controller lock. This module never launches a VM, invokes
sudo or issues stage acceptance. Pending outcomes retain failed evidence.
"""
import json
import hashlib
import os
import re
import secrets
import stat
import subprocess
import time
from pathlib import Path
import host_stage_audit as audit

RUNS = Path('/mnt/alpbahOS-data/alpbahos-infra-rebuild/state/stage-runs')
ARTIFACTS = Path('/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs')
PRODUCER = Path(__file__).with_name('host_stage_audit.py')
REPOSITORIES = (Path('/home/yrslf/alpbahOS'), Path('/home/yrslf/alpbahOS-claude'),
                Path(__file__).resolve().parents[2])


def identity(run_id):
    if not isinstance(run_id, str) or not re.fullmatch('[0-9a-f]{32}', run_id):
        raise RuntimeError('Invalid stage run identity')
    return run_id


def private(path):
    fd = audit.directory_fd(path)
    try:
        value = os.fstat(fd)
        if value.st_uid != os.getuid() or value.st_mode & 0o077:
            raise RuntimeError('Stage directory must be private user-owned')
    finally:
        os.close(fd)


def directory(parent, name):
    private(parent)
    fd = audit.directory_fd(parent)
    try:
        os.mkdir(name, 0o700, dir_fd=fd)
        os.fsync(fd)
    finally:
        os.close(fd)
    path = parent / name
    private(path)
    return path


def ensure_parent(path):
    private(path.parent)
    try:
        directory(path.parent, path.name)
    except FileExistsError:
        private(path)


def write(path, value):
    return write_raw(path, (json.dumps(value, indent=2, sort_keys=True) + '\n').encode())


def write_raw(path, raw):
    private(path.parent)
    if not isinstance(raw, bytes):
        raise RuntimeError('Stage raw evidence must be exact bytes')
    fd = audit.directory_fd(path.parent)
    try:
        output = os.open(path.name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=fd)
        with os.fdopen(output, 'wb') as stream:
            stream.write(raw); stream.flush(); os.fsync(stream.fileno())
        os.fsync(fd)
    finally:
        os.close(fd)
    return audit.digest(raw)


def read(path):
    private(path.parent)
    raw = audit.read_file(path, os.getuid())
    return raw, json.loads(raw)


def root_command(path, checksum):
    return ['sudo', 'python3', '-I', str(PRODUCER.resolve()), 'capture',
            '--request', str(path), '--request-sha256', checksum,
            '--script-sha256', audit.digest(PRODUCER.read_bytes())]


def prepare(stage, mode, inputs_sha256, sources_sha256, phase1_sha256):
    if stage != 'stability':
        raise RuntimeError('Only selected unprivileged stability preparation implemented')
    return _prepare(stage, mode, inputs_sha256, sources_sha256, phase1_sha256, secrets.token_hex(16))


def _prepare(stage, mode, inputs_sha256, sources_sha256, phase1_sha256, run_id, parent=None):
    if os.geteuid() != audit.USER_UID or stage not in ('stability', 'toolchain') or mode != 'multilib-m32':
        raise RuntimeError('Only selected unprivileged stability/toolchain preparation implemented')
    identity(run_id)
    if (stage == 'toolchain') != (parent is not None):
        raise RuntimeError('Toolchain preparation requires fully verified parent')
    if any(not isinstance(v, str) or not re.fullmatch('[0-9a-f]{64}', v)
           for v in (inputs_sha256, sources_sha256, phase1_sha256)):
        raise RuntimeError('Stage preparation hashes invalid')
    ensure_parent(RUNS); ensure_parent(ARTIFACTS)
    root = directory(RUNS, run_id)
    directory(ARTIFACTS, run_id)
    if parent is not None:
        checksum = write_raw(root / 'parent.json', parent['raw'])
        parent_binding = {'run_id': identity(parent['run_id']), 'after_audit_id': identity(parent['after_audit_id']),
                          'sha256': checksum}
    path, checksum = audit.request(stage, 'before', run_id, inputs_sha256, sources_sha256)
    value = {'schema': 'alpbahOS.stage-run/v1', 'stage': stage, 'mode': mode, 'run_id': run_id,
             'inputs_sha256': inputs_sha256, 'sources_sha256': sources_sha256,
             'phase1_sha256': phase1_sha256, 'boot_id': audit.BOOT.read_text().strip(),
             'created_at_ns': time.time_ns(), 'before_request': str(path), 'before_request_sha256': checksum,
             'producer_sha256': audit.digest(PRODUCER.read_bytes())}
    if parent is not None:
        value['parent'] = parent_binding
    write(root / 'run.json', value)
    return {'run_id': run_id, 'stage': stage, 'scope': 'request only; no OC/start or stage acceptance',
            'request': str(path), 'root_command_argv': root_command(path, checksum)}


def prepare_toolchain(mode, inputs_sha256, sources_sha256, phase1_sha256, value, run_sha256,
                      after_audit_id, sources, recipes, vm, expected_argv, stopped, space_guard):
    """No injectable PASS/callback: preflight runs the complete parent verifier."""
    if os.geteuid() != audit.USER_UID or mode != 'multilib-m32':
        raise RuntimeError('Toolchain request requires selected unprivileged preparation')
    expected = {'mode': mode, 'inputs_sha256': inputs_sha256, 'sources_sha256': sources_sha256,
                'phase1_sha256': phase1_sha256, 'boot_id': audit.BOOT.read_text().strip()}
    if any(value.get(k) != v for k, v in expected.items()):
        raise RuntimeError('Toolchain parent differs from current input/phase1/boot')
    import toolchain_handoff
    run_id = secrets.token_hex(16)
    raw = toolchain_handoff.prepare(value, run_sha256, after_audit_id, sources, recipes, vm,
                                    expected_argv, stopped, space_guard, run_id)
    return _prepare('toolchain', mode, inputs_sha256, sources_sha256, phase1_sha256, run_id,
                    {'raw': raw, 'run_id': value['run_id'], 'after_audit_id': after_audit_id})


def parent_guard(value):
    import toolchain_handoff
    parent = value.get('parent')
    if not isinstance(parent, dict) or set(parent) != {'run_id', 'after_audit_id', 'sha256'}:
        raise RuntimeError('Toolchain parent binding missing')
    identity(parent['run_id']); identity(parent['after_audit_id'])
    raw, captured = read(RUNS / identity(value['run_id']) / 'parent.json')
    expected = {'schema': toolchain_handoff.PARENT_SCHEMA, 'result': 'VERIFIED_PARENT', 'stage': 'toolchain',
                'mode': value['mode'], 'run_id': value['run_id'], 'parent_run_id': parent['run_id'],
                'host_boot_id': value['boot_id'], 'inputs_sha256': value['inputs_sha256'],
                'sources_sha256': value['sources_sha256']}
    if (not isinstance(captured, dict) or audit.digest(raw) != parent['sha256']
            or any(captured.get(k) != v for k, v in expected.items())):
        raise RuntimeError('Toolchain raw parent pin/current job changed')
    return raw


def load(run_id, mode, inputs_sha256, sources_sha256, phase1_sha256, *, stage='stability'):
    if stage not in ('stability', 'toolchain'):
        raise RuntimeError('Stage loader not implemented for this product stage')
    identity(run_id)
    private(RUNS); private(ARTIFACTS)
    raw, value = read(RUNS / run_id / 'run.json')
    expected = {'schema': 'alpbahOS.stage-run/v1', 'stage': stage, 'run_id': run_id,
                'mode': mode, 'inputs_sha256': inputs_sha256, 'sources_sha256': sources_sha256,
                'phase1_sha256': phase1_sha256, 'boot_id': audit.BOOT.read_text().strip(),
                'producer_sha256': audit.digest(PRODUCER.read_bytes())}
    if any(value.get(key) != wanted for key, wanted in expected.items()):
        raise RuntimeError('Stage run current inputs/phase1/boot/producer changed')
    request_path = Path(value['before_request'])
    if request_path.parent != audit.REQUESTS:
        raise RuntimeError('Stage before request path outside fixed store')
    request_raw = audit.read_file(request_path, audit.USER_UID, 65536)
    request = audit.checked_request(request_raw)
    if (audit.digest(request_raw) != value['before_request_sha256']
            or request_path.name != run_id + '-before-' + request['audit_id'] + '.json'
            or request['phase'] != 'before'
            or any(request[key] != value[key] for key in ('stage', 'run_id', 'inputs_sha256', 'sources_sha256', 'boot_id'))):
        raise RuntimeError('Stage before request identity/bytes changed')
    private(ARTIFACTS / run_id)
    if stage == 'toolchain':
        parent_guard(value)
    return value, audit.digest(raw), request_raw


def begin(value, run_sha256, request_raw):
    root = RUNS / identity(value['run_id'])
    # Check single-use state before doing any privileged evidence reads.
    if any((root / name).exists() or (root / name).is_symlink()
           for name in ('started.json', 'outcome.json')):
        raise RuntimeError('Stage run already started; preserve evidence, never retry it')
    boundary = time.time_ns()
    verified = audit.verify(request_raw, value['producer_sha256'], boundary)
    started = {'run_sha256': run_sha256, 'started_at_ns': boundary,
               'before_host_evidence': verified}
    write(root / 'started.json', started)
    return started


def file_hashes(root):
    """Hash every collected regular byte, rejecting aliases and special files."""
    private(root)
    hashes = {}
    for path in sorted(root.rglob('*')):
        if path.is_symlink() or path.resolve() != path:
            raise RuntimeError('Stage evidence alias forbidden')
        value = path.stat()
        if value.st_uid != os.getuid() or value.st_mode & 0o022:
            raise RuntimeError('Stage evidence ownership/write permission invalid')
        if path.is_dir():
            continue
        if not stat.S_ISREG(value.st_mode) or value.st_nlink != 1:
            raise RuntimeError('Stage evidence type/hardlink invalid')
        parent = audit.directory_fd(path.parent)
        try:
            fd = os.open(path.name, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=parent)
            with os.fdopen(fd, 'rb') as stream:
                before = os.fstat(stream.fileno())
                if (not stat.S_ISREG(before.st_mode) or before.st_uid != os.getuid()
                        or before.st_nlink != 1 or before.st_mode & 0o022):
                    raise RuntimeError('Stage evidence opened identity invalid')
                digest = hashlib.sha256()
                for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                    digest.update(chunk)
                after = os.fstat(stream.fileno())
                if (before.st_size, before.st_mtime_ns, before.st_ctime_ns) != (after.st_size, after.st_mtime_ns, after.st_ctime_ns):
                    raise RuntimeError('Stage evidence bytes changed during hashing')
                hashes[str(path.relative_to(root))] = digest.hexdigest()
        finally:
            os.close(parent)
    return hashes


def execution_guard(value, run_sha256):
    root = RUNS / identity(value['run_id'])
    raw, current = read(root / 'run.json')
    if audit.digest(raw) != run_sha256 or current != value:
        raise RuntimeError('Stage execution context differs from immutable run')
    if value['boot_id'] != audit.BOOT.read_text().strip() or value['producer_sha256'] != audit.digest(PRODUCER.read_bytes()):
        raise RuntimeError('Stage execution boot/producer changed')
    _, started = read(root / 'started.json')
    if started['run_sha256'] != run_sha256 or (root / 'outcome.json').exists():
        raise RuntimeError('Stage execution is not a fresh started run')
    request_raw = audit.read_file(Path(value['before_request']), audit.USER_UID, 65536)
    if audit.digest(request_raw) != value['before_request_sha256']:
        raise RuntimeError('Stage execution before request changed')
    evidence = audit.verify(request_raw, value['producer_sha256'], started['started_at_ns'])
    if evidence != started['before_host_evidence']:
        raise RuntimeError('Stage execution before audit changed')
    if value['stage'] == 'toolchain':
        parent_guard(value)


def repository_snapshot(value, phase):
    if phase not in ('before', 'after'):
        raise RuntimeError('Invalid repository observation phase')
    record = {'run_id': identity(value['run_id']), 'phase': phase,
              'time_ns': time.time_ns(), 'repositories': {}}
    for repository in REPOSITORIES:
        observed = {}
        for field, args in (('head', ['rev-parse', 'HEAD']), ('branch', ['branch', '--show-current']),
                            ('status', ['status', '--porcelain=v1', '-z', '--untracked-files=all'])):
            command = ['git', '-C', str(repository), *args]
            result = subprocess.run(command, capture_output=True, timeout=30,
                env={**os.environ, 'LC_ALL': 'C', 'GIT_OPTIONAL_LOCKS': '0'})
            if result.returncode or result.stderr.strip():
                raise RuntimeError('Repository observation failed: ' + str(repository) + '/' + field)
            observed[field] = result.stdout.decode(errors='replace')
            observed[field + '_sha256'] = audit.digest(result.stdout)
        record['repositories'][str(repository)] = observed
    write(ARTIFACTS / value['run_id'] / ('repositories-' + phase + '.json'), record)
    return record


def finish(value, run_sha256, errors, verified, stopped):
    """After writers close: retain an immutable terminal record, never PASS."""
    root = RUNS / identity(value['run_id'])
    raw, started = read(root / 'started.json')
    if started['run_sha256'] != run_sha256:
        raise RuntimeError('Stage started record differs from run inputs')
    faults = [repr(error) for error in errors]
    if not verified and not faults:
        faults.append('Guest artifact validation absent')
    try:
        stopped()
        hashes = file_hashes(ARTIFACTS / value['run_id'])
    except (RuntimeError, OSError) as error:
        faults.append(repr(error)); hashes = None
    record = {'schema': 'alpbahOS.stage-outcome/v1', 'run_sha256': run_sha256,
              'started_sha256': audit.digest(raw), 'started_at_ns': started['started_at_ns'],
              'ended_at_ns': time.time_ns(), 'errors': faults, 'artifact_sha256': hashes,
              'guest_artifact_evidence': verified,
              'result': 'FAIL' if faults else 'PENDING_PRIVILEGED_POST',
              'scope': 'execution/evidence only; no stage acceptance'}
    write(root / 'outcome.json', record)
    return record


def after_request(value, run_sha256):
    root = RUNS / identity(value['run_id'])
    run_raw, current = read(root / 'run.json')
    if current != value or audit.digest(run_raw) != run_sha256:
        raise RuntimeError('Post request context differs from immutable run')
    started_raw, started = read(root / 'started.json')
    raw, outcome = read(root / 'outcome.json')
    if (outcome.get('schema') != 'alpbahOS.stage-outcome/v1'
            or outcome.get('run_sha256') != run_sha256 or outcome.get('result') != 'PENDING_PRIVILEGED_POST'
            or outcome.get('started_sha256') != audit.digest(started_raw)
            or started.get('run_sha256') != run_sha256
            or outcome.get('started_at_ns') != started.get('started_at_ns')
            or type(outcome.get('ended_at_ns')) is not int
            or not started['started_at_ns'] <= outcome['ended_at_ns'] <= time.time_ns()
            or outcome.get('errors') != [] or not outcome.get('guest_artifact_evidence')
            or outcome.get('artifact_sha256') != file_hashes(ARTIFACTS / value['run_id'])):
        raise RuntimeError('Stage failed/incomplete or collected bytes changed; no after request')
    path, checksum = audit.request(value['stage'], 'after', value['run_id'],
                                    value['inputs_sha256'], value['sources_sha256'], audit.digest(raw))
    # A repeat request retains its own file; it never overwrites previous attempts.
    write(root / ('after-' + path.stem.split('-')[-1] + '.json'),
          {'outcome_sha256': audit.digest(raw), 'request': str(path), 'request_sha256': checksum})
    return {'run_id': value['run_id'], 'audit_id': path.stem.split('-')[-1],
            'request': str(path), 'root_command_argv': root_command(path, checksum),
            'scope': 'post inspection request only; stage acceptance pending'}
