#!/usr/bin/env python3
"""Host kernel lifecycle/authorization session for a future complete runner.

CLI is read-only preflight. Internal session restores only fully recomputed
Base, owns the controller lock, captures fresh host-before and measures the
actual guest before single-use delivery. A consumer must produce independently
verified guest evidence; absent it, the terminal outcome is FAIL. This module
cannot emit kernel acceptance or a checkpoint. Production interruption hold
must be resolved by the calling controller before it opens this session.
"""
import fcntl
import hashlib
import importlib.util
import json
import os
import re
import secrets
import shlex
import stat
import subprocess
import sys
import time
from contextlib import contextmanager
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / 'scripts/infra'))
import buildctl
import checkpoint_store
import host_monitor
import host_stage_audit as audit
import stage_runs

PINS = {
    'infra-base-parent.py': '5deaac7c59e59fff9717988d775d5df11de7178948e8a1095a197f2b41867a23',
    'infra-parent-audit.py': '7dd4e8513ad42b1eb8752539dda63214ebac04a153b3156be64d62549f3567e7',
    'infra-base-stage.py': '477e3675bbe660127b56bc9fc56564315365f3eada452acbb9593e631ca3c22e',
    'infra-kernel-build.py': '3ea2d440fa4c54e8cf0ff1fca3489c6125aa7b3f17c726b51de40011b740ff80',
    'infra-kernel-config.py': 'e32b8ca5e30067870b6780408b19d1d32898d5b17e72f111c464d56aa17d70e4',
    'infra-kernel-payload.py': 'd8d3101eccdbb70c2686e3015b6733db64430ebd075600ef6f8fbfb037a383f0',
    'infra-kernel-authorize.py': 'ce6f2b817b2454179983694b81f336b2c99701ce76e72c8de2fd14cb8592b6a9',
    'infra-kernel-authorize.sh': 'fb41a3b88f78eee5f5e89299a4abe8096ff61c310a14ee5d35b64c9b662181a6',
    'infra-kernel-build.sh': 'f332252504871456365b806523e8fdb5a9875600a15525cc4fa9fc69cb203779',
}
SELF_SHA = buildctl.sha(Path(__file__))
BOOT_PATTERN = re.compile(r'[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}')


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def encoded(value):
    return (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()


def rules():
    # Verify every dependency before executing a helper that imports another.
    for name, expected in PINS.items():
        path = REPO / 'scripts' / name
        value = path.lstat()
        if (path.resolve() != path or not stat.S_ISREG(value.st_mode)
                or value.st_uid != os.getuid() or value.st_nlink != 1 or value.st_mode & 0o022
                or buildctl.sha(path) != expected):
            raise RuntimeError('Kernel host dependency alias/owner/source drift: ' + name)
    modules = []
    for name in ('infra-base-parent.py', 'infra-base-stage.py', 'infra-kernel-build.py'):
        spec = importlib.util.spec_from_file_location('kernel_session_' + name.replace('-', '_'), REPO / 'scripts' / name)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        modules.append(module)
    return modules


def preflight():
    if os.geteuid() != audit.USER_UID:
        raise RuntimeError('Kernel host session requires the unprivileged host user')
    parent, base, kernel = rules()
    raw, proof = parent.accepted_base()  # No restore, launch, root capture or writes.
    buildctl.phase1_acceptance_guard()
    sources = buildctl.manifest()
    if (sources.get('abi_selection', {}).get('mode') != 'multilib-m32'
            or sources.get('source_date_epoch') != 1756684800):
        raise RuntimeError('Kernel source epoch/ABI changed')
    item = kernel.package_stage.source_pin(sources, kernel.SOURCE, REPO)
    if item['sha256'] != kernel.SOURCE_SHA or item['url'] != kernel.payload.SOURCE_URL:
        raise RuntimeError('Kernel source pin changed')
    buildctl.verify_cache(); buildctl.verify_signatures()
    if buildctl.sha(buildctl.CACHE / kernel.SOURCE) != kernel.SOURCE_SHA:
        raise RuntimeError('Kernel cached source bytes changed')
    return raw, proof, parent, base, kernel


@contextmanager
def controller_lock():
    if os.geteuid() != audit.USER_UID:
        raise RuntimeError('Kernel controller lock requires unprivileged host user')
    stage_runs.private(buildctl.STATE)
    path = buildctl.STATE / 'controller.lock'
    fd = os.open(path, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    try:
        value = os.fstat(fd)
        if (not stat.S_ISREG(value.st_mode) or value.st_uid != os.getuid()
                or value.st_nlink != 1 or value.st_mode & 0o022):
            raise RuntimeError('Kernel controller lock owner/type/alias invalid')
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if buildctl.pid() is not None:
            raise RuntimeError('Builder already live; preserve its controller')
        yield
    finally:
        os.close(fd)


def fresh_children(parent, proof):
    evidence = {k: v for k, v in proof.items() if k not in ('checkpoint_sha256', 'transaction_sha256')}
    if parent.checkpoint(evidence) != {k: proof[k] for k in ('checkpoint_sha256', 'transaction_sha256')}:
        raise RuntimeError('Kernel restored Base checkpoint metadata differs')
    chains = checkpoint_store.inspect_disks(buildctl.VM, parent.stopped, buildctl.space_guard)
    for disk in checkpoint_store.DISKS:
        original = evidence['closed_disk_chains'][disk]
        expected = [{'path': str(buildctl.VM / 'checkpoint-base' / (disk + '.qcow2')),
                     'sha256': original[0]['sha256']}, *original[1:]]
        if chains[disk][1:] != expected:
            raise RuntimeError('Kernel fresh child does not use exact accepted Base ancestry')
    return chains


def before_launch(value, run_sha, base_raw, proof, parent, fresh):
    stage_runs.execution_guard(value, run_sha)  # Current boot + fresh root-before, never archived endpoint.
    if (value['controller_sha256'] != buildctl.sha(Path(__file__))
            or value['helper_sha256'] != {name: PINS[name] for name in rules()[2].HELPERS}
            or value['base_acceptance_sha256'] != digest(base_raw)
            or stage_runs.read(buildctl.ARTIFACTS / 'base-acceptance.json')[0] != base_raw
            or buildctl.inputs_digest() != value['inputs_sha256']
            or buildctl.sha(REPO / 'manifests/infra-sources.json') != value['sources_sha256']
            or fresh_children(parent, proof) != fresh):
        raise RuntimeError('Kernel prepared parent/helper/input/child bytes changed before launch')


def transfer(kernel, artifact_root):
    rules()
    buildctl.sync()
    transport = shlex.join(buildctl.ssh_args()[:-1])
    for name in kernel.HELPERS:
        subprocess.run(['rsync', '-rt', '-e', transport, str(REPO / 'scripts' / name),
                        'root@127.0.0.1:/opt/alp-infra/scripts/'], check=True, timeout=120)
    subprocess.run(['rsync', '-rt', '-e', transport, str(buildctl.CACHE / kernel.SOURCE),
                    'root@127.0.0.1:/srv/lfs/sources/'], check=True, timeout=300)
    rules()
    stage_runs.write(artifact_root / 'source-transfer.json', {
        'helper_sha256': {name: PINS[name] for name in kernel.HELPERS},
        'source_sha256': kernel.SOURCE_SHA, 'source': kernel.SOURCE,
        'inputs_sha256': buildctl.inputs_digest()})


def observation_command(kernel):
    # Fixed read-only guest probe, no request-supplied paths or programs.
    code = '\n'.join((
        'import os,stat,json,hashlib', 'from pathlib import Path',
        "root=Path('/opt/alp-infra/scripts')", 'hashes={}',
        'def sha(path):', '    before=path.lstat()',
        '    if path.resolve()!=path or not stat.S_ISREG(before.st_mode) or before.st_uid!=0 or before.st_nlink!=1 or before.st_mode&0o022: raise RuntimeError("Guest observed file alias/owner/permissions")',
        '    h=hashlib.sha256()', '    with path.open("rb") as stream:',
        '        for block in iter(lambda:stream.read(1048576),b""): h.update(block)',
        '    after=path.lstat()',
        '    if (before.st_ino,before.st_size,before.st_mtime_ns,before.st_ctime_ns)!=(after.st_ino,after.st_size,after.st_mtime_ns,after.st_ctime_ns): raise RuntimeError("Guest observed bytes changed")',
        '    return h.hexdigest()',
        "boot=Path('/proc/sys/kernel/random/boot_id').read_text().strip()",
        'for name in ' + repr(list(kernel.HELPERS)) + ': hashes[name]=sha(root/name)',
        "inputs_path=Path('/srv/infra/inputs.json'); inputs_sha=sha(inputs_path)",
        'inputs=json.loads(inputs_path.read_bytes())',
        'source_sha=sha(Path(' + repr('/srv/lfs/sources/' + kernel.SOURCE) + '))',
        "if boot!=Path('/proc/sys/kernel/random/boot_id').read_text().strip(): raise RuntimeError('Guest boot changed')",
        "print(json.dumps({'guest_boot_id':boot,'helper_sha256':hashes,'inputs':inputs,'inputs_raw_sha256':inputs_sha,'source_sha256':source_sha},sort_keys=True))",
    ))
    return ('set -euo pipefail; source /opt/alp-infra/scripts/infra/guest-guard.sh; guest_guard; '
            'exec /usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LC_ALL=C LANG=C TZ=UTC '
            '/usr/bin/python3 -I -c ' + shlex.quote(code))


def measured_guest(value, kernel, artifact_root):
    argv = buildctl.ssh_args() + [observation_command(kernel)]
    start = time.time_ns()
    result = subprocess.run(argv, capture_output=True, timeout=120)
    end = time.time_ns()
    stage_runs.write(artifact_root / 'guest-observation.json', {
        'argv': argv, 'exit': result.returncode, 'started_at_ns': start, 'ended_at_ns': end,
        'stdout': result.stdout.decode(errors='replace'), 'stderr': result.stderr.decode(errors='replace')})
    if result.returncode or result.stderr or len(result.stdout) > 65536:
        raise RuntimeError('Kernel current guest observation failed or oversized')
    measured = json.loads(result.stdout)
    if (not isinstance(measured, dict) or set(measured) != {'guest_boot_id', 'helper_sha256', 'inputs', 'inputs_raw_sha256', 'source_sha256'}
            or not BOOT_PATTERN.fullmatch(str(measured.get('guest_boot_id', '')))
            or measured['guest_boot_id'] == value['boot_id']
            or measured['helper_sha256'] != value['helper_sha256']
            or measured['inputs'] != {k: value[k] for k in ('inputs_sha256', 'sources_sha256')}
            or measured['source_sha256'] != kernel.SOURCE_SHA
            or not re.fullmatch('[0-9a-f]{64}', str(measured['inputs_raw_sha256']))):
        raise RuntimeError('Kernel measured guest boot/helper/source/input differs')
    return measured


def authorization(value, base_raw, proof, measured, kernel):
    stage_runs.identity(value['run_id']); stage_runs.identity(proof['run_id'])
    if (digest(base_raw) != value['base_acceptance_sha256']
            or json.loads(base_raw) != proof or value['run_id'] == proof['run_id']
            or value['boot_id'] != audit.BOOT.read_text().strip()):
        raise RuntimeError('Kernel authorization requires exact prepared Base and current distinct job/boot')
    parent = {'schema': 'alpbahOS.kernel-parent/v1', 'result': 'VERIFIED_PARENT',
        'stage': 'kernel', 'mode': 'multilib-m32', 'run_id': value['run_id'],
        'parent_run_id': proof['run_id'], 'host_boot_id': value['boot_id'],
        'guest_boot_id': measured['guest_boot_id'], 'base_acceptance_sha256': digest(base_raw),
        **{k: proof[k] for k in ('inputs_sha256', 'sources_sha256', 'checkpoint_sha256', 'transaction_sha256')},
        'host_controller_sha256': value['controller_sha256'],
        'fresh_disk_chains': value['fresh_disk_chains'], 'guest_observation_sha256': digest(encoded(measured))}
    parent_raw = encoded(parent)
    auth = {'schema': 'alpbahOS.kernel-build-authorization/v1', 'result': 'AUTHORIZED',
        'stage': 'kernel', 'mode': 'multilib-m32', 'oc_confirmed': True,
        'run_id': value['run_id'], 'host_boot_id': value['boot_id'], 'guest_boot_id': measured['guest_boot_id'],
        'base_acceptance_sha256': digest(base_raw), 'parent_sha256': digest(parent_raw),
        **{k: value[k] for k in ('inputs_sha256', 'sources_sha256', 'helper_sha256', 'controller_sha256')},
        'source_sha256': kernel.SOURCE_SHA, 'authorized_at_ns': time.time_ns()}
    current = kernel.binding(auth, proof, parent, measured['inputs'], measured['guest_boot_id'],
                             value['helper_sha256'], digest(base_raw), digest(parent_raw))
    payload = encoded({'base_raw': base_raw.decode(), 'parent_raw': parent_raw.decode(), 'authorization': auth})
    if len(payload) > 2 * 1024 * 1024:
        raise RuntimeError('Kernel authorization exceeds guest transport bound')
    return payload, parent_raw, auth, current


def deliver(value, run_sha, raw, parent_raw, auth, current, kernel, artifact_root):
    stage_runs.execution_guard(value, run_sha)
    rules()
    argv = buildctl.ssh_args() + ['bash /opt/alp-infra/scripts/infra-kernel-authorize.sh']
    stage_runs.write_raw(artifact_root / 'kernel-parent.json', parent_raw)
    stage_runs.write(artifact_root / 'authorization.json', auth)
    stage_runs.write_raw(artifact_root / 'delivery-payload.json', raw)
    start = time.time_ns()
    result = subprocess.run(argv, input=raw, capture_output=True, timeout=300)
    end = time.time_ns()
    stage_runs.write(artifact_root / 'delivery-command.json', {
        'argv': argv, 'started_at_ns': start, 'ended_at_ns': end, 'exit': result.returncode,
        'stdout': result.stdout.decode(errors='replace'), 'stderr': result.stderr.decode(errors='replace')})
    if result.returncode or result.stderr or len(result.stdout) > 65536:
        raise RuntimeError('Kernel guest authorization failed; preserve partial attempt')
    response = json.loads(result.stdout)
    kernel.completed_handoff(encoded(response), current, encoded(auth))
    if response.get('payload_sha256') != digest(raw):
        raise RuntimeError('Kernel guest completed receipt payload differs')
    # Independently read committed receipt, not merely its stdout claim.
    receipt = kernel_read_receipt(value['run_id'])
    if json.loads(receipt) != response:
        raise RuntimeError('Kernel guest stdout differs from committed completion')
    kernel.completed_handoff(receipt, current, encoded(auth))
    stage_runs.write_raw(artifact_root / 'delivery-receipt.json', receipt)
    stage_runs.execution_guard(value, run_sha); rules()
    return response, digest(receipt)


def kernel_read_receipt(run_id):
    stage_runs.identity(run_id)
    # Fixed allowlisted root-owned record; common guest guard acquires FD9.
    path = '/srv/infra/kernel-handoffs/' + run_id + '.completed.json'
    code = '\n'.join((
        'from pathlib import Path;import os,stat', 'p=Path(' + repr(path) + ')', 's=p.lstat()',
        'if p.resolve()!=p or not stat.S_ISREG(s.st_mode) or s.st_uid!=0 or s.st_nlink!=1 or s.st_mode&0o022 or s.st_size>65536: raise RuntimeError("Committed receipt identity invalid")',
        'raw=p.read_bytes(); after=p.lstat()',
        'if (s.st_ino,s.st_size,s.st_mtime_ns,s.st_ctime_ns)!=(after.st_ino,after.st_size,after.st_mtime_ns,after.st_ctime_ns): raise RuntimeError("Committed receipt changed during read")',
        'import sys;sys.stdout.buffer.write(raw)',
    ))
    command = ('set -euo pipefail; source /opt/alp-infra/scripts/infra/guest-guard.sh; guest_guard; '
               'exec /usr/bin/python3 -I -c ' + shlex.quote(code))
    result = subprocess.run(buildctl.ssh_args() + [command], capture_output=True, timeout=30)
    if result.returncode or result.stderr or len(result.stdout) > 65536:
        raise RuntimeError('Kernel committed guest receipt unavailable')
    return result.stdout


@contextmanager
def session():
    """Future runner owns full build/install verification inside this session."""
    if os.geteuid() != audit.USER_UID:
        raise RuntimeError('Kernel session cannot run as host root')
    with controller_lock():
        base_raw, proof, parent, base, kernel = preflight()
        run_id = secrets.token_hex(16)
        if run_id == proof['run_id']:
            raise RuntimeError('Kernel job nonce must differ from Base')
        buildctl.restore('base')  # Current overlays are preserved by the existing controller.
        fresh = fresh_children(parent, proof)
        run_root = stage_runs.directory(stage_runs.RUNS, run_id)
        artifact_root = stage_runs.directory(stage_runs.ARTIFACTS, run_id)
        before_path, before_sha = audit.request('kernel', 'before', run_id, proof['inputs_sha256'], proof['sources_sha256'])
        value = {'schema': 'alpbahOS.stage-run/v1', 'stage': 'kernel', 'mode': 'multilib-m32',
            'run_id': run_id, 'boot_id': audit.BOOT.read_text().strip(), 'created_at_ns': time.time_ns(),
            **{k: proof[k] for k in ('inputs_sha256', 'sources_sha256')},
            'controller_sha256': SELF_SHA, 'base_acceptance_sha256': digest(base_raw),
            'helper_sha256': {name: PINS[name] for name in kernel.HELPERS}, 'fresh_disk_chains': fresh,
            'phase1_sha256': buildctl.sha(buildctl.ARTIFACTS / 'phase1-acceptance.json'),
            'before_request': str(before_path), 'before_request_sha256': before_sha,
            'producer_sha256': digest(stage_runs.PRODUCER.read_bytes())}
        stage_runs.write(run_root / 'run.json', value)
        stage_runs.write_raw(run_root / 'base-parent.json', base_raw)
        run_sha = digest((run_root / 'run.json').read_bytes())
        baseline = host_monitor.sample(); host_monitor.validate_sample(baseline)
        if baseline['boot_id'] != value['boot_id']:
            raise RuntimeError('Kernel host baseline boot changed')
        stage_runs.write(artifact_root / 'host-baseline.json', baseline)
        base.root_capture(before_path, before_sha)
        request_raw = audit.read_file(before_path, audit.USER_UID, 65536)
        stage_runs.begin(value, run_sha, request_raw)
        context = {'value': value, 'run_sha256': run_sha, 'artifact_root': artifact_root,
                   'guest_artifact_evidence': None}
        errors = []
        try:
            stage_runs.repository_snapshot(value, 'before')
            base.wait_for_builder_memory()
            before_launch(value, run_sha, base_raw, proof, parent, fresh)
            buildctl.launch(offline=True, vcpus=16)
            transfer(kernel, artifact_root)
            stage_runs.execution_guard(value, run_sha)
            measured = measured_guest(value, kernel, artifact_root)
            payload, parent_raw, auth, current = authorization(value, base_raw, proof, measured, kernel)
            response, receipt_sha = deliver(value, run_sha, payload, parent_raw, auth, current, kernel, artifact_root)
            context.update({'binding': {**current, 'handoff_receipt_sha256': receipt_sha}, 'response': response,
                            'guest_boot_id': measured['guest_boot_id']})
            yield context
            evidence = context['guest_artifact_evidence']
            if (not isinstance(evidence, dict) or evidence.get('schema') != 'alpbahOS.kernel-guest-evidence/v1'
                    or evidence.get('result') != 'VERIFIED_GUEST_BYTES'
                    or any(evidence.get(k) != value[k] for k in ('run_id', 'inputs_sha256', 'sources_sha256'))
                    or evidence.get('guest_boot_id') != measured['guest_boot_id']):
                raise RuntimeError('Kernel build/install consumer evidence absent; handoff is not stage acceptance')
            stage_runs.execution_guard(value, run_sha); rules()
        except BaseException as error:
            errors.append(error)
        try:
            if buildctl.pid() is not None:
                buildctl.stop()
            parent.stopped()
            stage_runs.repository_snapshot(value, 'after')
            stage_runs.write(artifact_root / 'disks-closed.json', {
                'run_id': run_id, 'time_ns': time.time_ns(),
                'chains': checkpoint_store.inspect_disks(buildctl.VM, parent.stopped, buildctl.space_guard)})
        except BaseException as close_error:
            errors.append(close_error)
        outcome = stage_runs.finish(value, run_sha, errors, context['guest_artifact_evidence'], parent.stopped)
        if errors:
            raise RuntimeError('Kernel session failed; preserve job, guest artifacts and current overlays') from errors[0]
        context['post_request'] = stage_runs.after_request(value, run_sha)
        # Complete kernel acceptance will verify collected bytes, fresh root-after,
        # Alp ownership, installed payload and boot evidence. No PASS here.
        context['outcome'] = outcome


if __name__ == '__main__':
    try:
        if len(sys.argv) != 1:
            raise RuntimeError('No host kernel session bypass/launch flags accepted')
        raw, proof, *_ = preflight()
        print(json.dumps({'result': 'VERIFIED_KERNEL_BASE_PARENT', 'base_run_id': proof['run_id'],
                          'base_acceptance_sha256': digest(raw),
                          'scope': 'read-only preflight only; current root-before/session/complete kernel acceptance separate'}, sort_keys=True))
    except (RuntimeError, OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        raise SystemExit('STOP: ' + str(error))
