#!/usr/bin/env python3
"""Run an audited product stage in the isolated KVM Builder guest.

The first integrated product stage is the pinned Linux kernel package. The
controller is intentionally kept outside buildctl's frozen input digest so
that it can consume the already accepted Base checkpoint unchanged.
"""
import fcntl
import hashlib
import importlib.util
import json
import os
import re
import shlex
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
BASE_REPO = Path('/home/yrslf/alpbahOS-infra-rebuild')
PRODUCT = REPO / 'scripts/product-stages'
RECIPE = PRODUCT / 'kernel.recipe.json'
GUEST_RUNNER = PRODUCT / 'kernel-guest-run.py'
CONFIG = REPO / 'configs/kernel/infra-required.config'
KERNEL_SOURCE = 'linux-6.16.1.tar.xz'
STAGE = 'kernel'
RUNNER_ID = re.compile(r'[0-9a-f]{32}')
HASH = re.compile(r'[0-9a-f]{64}')
BOOT_ID = re.compile(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
LFS_DISK_BYTES = 96 * 1024**3

sys.path.insert(0, str(REPO / 'scripts/infra'))
import buildctl
import checkpoint_store
import host_monitor
import host_stage_audit as audit
import package_install
import stage_runs


def sha(path):
    value = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def encoded(value):
    return (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()


def load_base_controller():
    """Load the original Base verifier with its original repo snapshots."""
    names = ('base_plan', 'buildctl', 'checkpoint_store', 'handoff_binding',
             'host_monitor', 'host_stage_audit', 'package_install', 'package_stage',
             'stage_runs', 'stage_acceptance', 'toolchain_handoff',
             'toolchain_evidence', 'toolchain_acceptance', 'stability_evidence')
    saved = {name: sys.modules.pop(name) for name in names if name in sys.modules}
    path = str(BASE_REPO / 'scripts/infra')
    sys.path.insert(0, path)
    try:
        spec = importlib.util.spec_from_file_location(
            'alpbahos_base_acceptance', BASE_REPO / 'scripts/infra-base-stage.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    finally:
        sys.path.remove(path)
        for name in names:
            sys.modules.pop(name, None)
        sys.modules.update(saved)


def accepted_base(base):
    """Recompute Base acceptance against its exact captured main checkout."""
    acceptance_path = buildctl.ARTIFACTS / 'base-acceptance.json'
    if acceptance_path.is_symlink() or not acceptance_path.is_file():
        raise RuntimeError('Accepted Base checkpoint/receipt not found')
    saved = json.loads(acceptance_path.read_bytes())
    proof, parent_raw = base.accepted_toolchain()
    run_id = stage_runs.identity(saved.get('run_id'))
    after_id = stage_runs.identity(saved.get('after_audit_id'))
    plan = base.base_plan.load(BASE_REPO)
    artifact_root = base.stage_runs.ARTIFACTS / run_id
    install_receipt = json.loads((artifact_root / 'authorization-install.json').read_bytes())
    authorization = json.loads((artifact_root / 'authorization.json').read_bytes())
    recomputed = base.accept(run_id, after_id, plan, proof, install_receipt,
                             authorization.get('base_authorization_sha256'))
    if any(saved.get(key) != value for key, value in recomputed.items()):
        raise RuntimeError('Base acceptance receipt differs from recomputed host/guest evidence')
    checkpoint = base.verify_base_checkpoint(buildctl.VM / 'checkpoint-base', recomputed)
    if (saved.get('checkpoint_sha256') != checkpoint['checkpoint_sha256']
            or saved.get('transaction_sha256') != checkpoint['transaction_sha256']):
        raise RuntimeError('Base checkpoint hashes do not match accepted proof')
    return proof, parent_raw, recomputed


def root_capture(request_path, request_sha):
    command = stage_runs.root_command(request_path, request_sha)
    result = subprocess.run(command, capture_output=True, text=True, timeout=600,
                            env={**os.environ, 'LC_ALL': 'C', 'LANG': 'C'})
    if result.returncode or result.stderr.strip():
        raise RuntimeError('Privileged host audit failed: ' + result.stderr[-1200:])
    value = json.loads(result.stdout)
    if value.get('result') != 'CAPTURED':
        raise RuntimeError('Host audit did not capture complete evidence')
    return value


def assert_stopped():
    if buildctl.pid() is not None:
        raise RuntimeError('Builder is live; refusing disk inspection/checkpoint')


def grow_lfs_disk():
    """Grow only the fresh Base child overlay; never mutate its accepted parent."""
    assert_stopped()
    buildctl.space_guard()
    active = buildctl.VM / 'lfs-active.qcow2'
    if (active.resolve() != active or not active.is_file() or active.is_symlink()
            or active.stat().st_uid != os.getuid() or active.stat().st_nlink != 1
            or buildctl.VM not in active.parents):
        raise RuntimeError('LFS active overlay is not a private canonical file')
    result = subprocess.run(['qemu-img', 'info', '--output=json', active],
                            check=True, capture_output=True, text=True)
    info = json.loads(result.stdout)
    if info.get('format') != 'qcow2' or info.get('virtual-size') != 40 * 1024**3:
        raise RuntimeError('Fresh Base LFS child is not the expected 40 GiB qcow2')
    chain = json.loads(subprocess.run(['qemu-img', 'info', '--output=json', '--backing-chain', active],
                                      check=True, capture_output=True, text=True).stdout)
    base_disk = buildctl.VM / 'checkpoint-base' / 'lfs.qcow2'
    if (len(chain) < 2 or Path(chain[0].get('filename', '')) != active
            or Path(chain[1].get('filename', '')) != base_disk):
        raise RuntimeError('LFS overlay is not a direct child of the accepted Base checkpoint')
    subprocess.run(['qemu-img', 'resize', active, str(LFS_DISK_BYTES)],
                   check=True, capture_output=True, text=True)
    buildctl.space_guard()
    grown = json.loads(subprocess.run(['qemu-img', 'info', '--output=json', active],
                                      check=True, capture_output=True, text=True).stdout)
    if grown.get('virtual-size') != LFS_DISK_BYTES:
        raise RuntimeError('LFS qcow2 did not reach the declared 96 GiB capacity')
    return {'path': str(active), 'bytes': LFS_DISK_BYTES,
            'backing_checkpoint': str(base_disk), 'result': 'PASS'}


def grow_lfs_filesystem():
    """Expand the guest's ext4 filesystem and verify usable capacity over SSH."""
    guest_read('resize2fs /dev/vdb', 4096)
    raw = guest_read('df -B1 --output=size,avail /srv/lfs', 1024).decode().splitlines()
    try:
        size, available = map(int, raw[-1].split()[-2:])
    except (IndexError, ValueError) as error:
        raise RuntimeError('Guest LFS filesystem capacity report is malformed') from error
    if size < 90 * 1024**3 or available < 70 * 1024**3:
        raise RuntimeError(f'Guest LFS filesystem did not grow enough: size={size} free={available}')
    return {'filesystem_bytes': size, 'available_bytes': available, 'result': 'PASS'}


def wait_for_memory(required=12 * 1024**3, interval=30):
    while True:
        available = next((int(line.split()[1]) * 1024 for line in Path('/proc/meminfo').read_text().splitlines()
                          if line.startswith('MemAvailable:')), None)
        if available is None:
            raise RuntimeError('Host MemAvailable missing')
        if available >= required:
            return available
        print(f'Waiting at Builder launch: MemAvailable={available}; reserve={required}', flush=True)
        time.sleep(interval)


def guest_read(command, limit=262144):
    result = subprocess.run(buildctl.ssh_args() + [command], capture_output=True,
                            timeout=30)
    if result.returncode or result.stderr or len(result.stdout) > limit:
        raise RuntimeError('Bounded Builder read failed: ' + command)
    return result.stdout


def transfer_inputs(run_id, artifact_root, source):
    buildctl.verify_cache()
    for path in (RECIPE, GUEST_RUNNER, CONFIG):
        if path.is_symlink() or not path.is_file() or path.resolve() != path:
            raise RuntimeError('Kernel stage input missing/aliased: ' + str(path))
    source_path = buildctl.CACHE / source['filename']
    if source_path.is_symlink() or sha(source_path) != source['sha256']:
        raise RuntimeError('Pinned Linux source archive mismatch')
    transport = shlex.join(buildctl.ssh_args()[:-1])
    remote = 'root@127.0.0.1:'
    subprocess.run(buildctl.ssh_args() + [
        'set -euo pipefail; install -d -m 0755 /opt/alp-infra/scripts/product-stages /opt/alp-infra/configs/kernel /srv/lfs/sources; '
        'test ! -e /opt/alp-infra/scripts/product-stages/kernel.recipe.json; '
        'test ! -e /opt/alp-infra/scripts/product-stages/kernel-guest-run.py; '
        'test ! -e /opt/alp-infra/scripts/product-stages/verify-kernel-config.py; '
        'test ! -e /srv/lfs/sources/linux-6.16.1.tar.xz || '
        'test "$(sha256sum /srv/lfs/sources/linux-6.16.1.tar.xz | cut -d" " -f1)" = ' + source['sha256']],
        check=True, timeout=30)
    for path, target in ((RECIPE, '/opt/alp-infra/scripts/product-stages/'),
                         (GUEST_RUNNER, '/opt/alp-infra/scripts/product-stages/'),
                         (PRODUCT / 'verify-kernel-config.py', '/opt/alp-infra/scripts/product-stages/'),
                         (CONFIG, '/opt/alp-infra/configs/kernel/')):
        subprocess.run(['rsync', '-rt', '-e', transport, str(path), remote + target],
                       check=True, timeout=120)
    target = '/srv/lfs/sources/' + source['filename']
    present = subprocess.run(buildctl.ssh_args() + [
        'test -f ' + shlex.quote(target) + ' && test ! -L ' + shlex.quote(target)],
        capture_output=True)
    if present.returncode:
        subprocess.run(['rsync', '-rt', '-e', transport, str(source_path), remote + target],
                       check=True, timeout=1800)
    hashes = {'recipe': sha(RECIPE), 'guest_runner': sha(GUEST_RUNNER),
              'config': sha(CONFIG), 'config_source': source['sha256']}
    check = ' && '.join('test "$(sha256sum ' + shlex.quote(remote_path) +
                        ' | cut -d" " -f1)" = ' + checksum
                        for remote_path, checksum in (
                            ('/opt/alp-infra/scripts/product-stages/kernel.recipe.json', hashes['recipe']),
                            ('/opt/alp-infra/scripts/product-stages/kernel-guest-run.py', hashes['guest_runner']),
                            ('/opt/alp-infra/scripts/product-stages/verify-kernel-config.py', sha(PRODUCT / 'verify-kernel-config.py')),
                            ('/opt/alp-infra/configs/kernel/infra-required.config', hashes['config']),
                            (target, source['sha256'])))
    guest_read('set -euo pipefail; ' + check)
    transfer = {'schema': 'alpbahOS.kernel-transfer/v1', 'run_id': run_id,
                'source': source['filename'], 'source_sha256': source['sha256'],
                'files': {'recipe': hashes['recipe'], 'runner': hashes['guest_runner'],
                          'config': hashes['config'],
                          'config_verifier': sha(PRODUCT / 'verify-kernel-config.py')},
                'verified_on_guest': True, 'bytes': source_path.stat().st_size}
    stage_runs.write(artifact_root / 'kernel-transfer.json', transfer)
    return transfer


def kernel_service_command(run_id, recipe_sha):
    unit = 'alpbahos-kernel-' + run_id
    result = '/srv/lfs/results/kernel/' + run_id
    service = '\n'.join(('set -euo pipefail',
        'source /opt/alp-infra/scripts/infra/guest-guard.sh', 'guest_guard',
        'exec /usr/bin/python3 /opt/alp-infra/scripts/product-stages/kernel-guest-run.py '
        + run_id + ' ' + recipe_sha, ''))
    lines = ['set -euo pipefail', 'unit=' + shlex.quote(unit),
        'result=' + shlex.quote(result), 'summary="$result/kernel-summary.json"',
        'test -d /srv/lfs/results && test ! -L /srv/lfs/results',
        'test ! -e /srv/lfs/results/kernel && mkdir -m 0755 /srv/lfs/results/kernel',
        'flock -u 9', 'exec 9<&-',
        'systemd-run --unit="$unit" --no-block --property=Type=exec '
        '--property=RuntimeMaxSec=infinity --property=TimeoutStartSec=infinity '
        '--property=StandardOutput=journal --property=StandardError=journal /bin/bash -c '
        + shlex.quote(service), 'while :; do',
        '  state=$(systemctl show --property=ActiveState --value "$unit.service")',
        '  case "$state" in active|activating|deactivating) sleep 5 ;; inactive|failed) break ;; '
        '*) printf "Unexpected guest unit state: %s\\n" "$state" >&2; exit 1 ;; esac',
        'done', 'result_state=$(systemctl show --property=Result --value "$unit.service")',
        'exit_code=$(systemctl show --property=ExecMainCode --value "$unit.service")',
        'exit_status=$(systemctl show --property=ExecMainStatus --value "$unit.service")',
        'journalctl --unit="$unit.service" --no-pager --output=cat || true',
        'if [[ "$state" == inactive && "$result_state" == success && "$exit_code" == exited '
        '&& "$exit_status" == 0 && -f "$summary" && ! -L "$summary" ]]; then exit 0; fi',
        'systemctl --no-pager --full status "$unit.service" >&2 || true',
        'printf "Guest kernel service failed: state=%s result=%s code=%s status=%s\\n" '
        '"$state" "$result_state" "$exit_code" "$exit_status" >&2', 'exit 1']
    return 'bash -c ' + shlex.quote('\n'.join(lines) + '\n')


def capture_guest(run_id, target):
    target.mkdir(mode=0o700)
    transport = shlex.join(buildctl.ssh_args()[:-1])
    subprocess.run(['rsync', '-rt', '-e', transport,
        f'root@127.0.0.1:/srv/lfs/results/kernel/{run_id}/', str(target) + '/'],
        check=True, timeout=1800)


def validate_guest_export(root, value, source, recipe_sha, guest_runner_sha):
    if any(path.is_symlink() for path in root.rglob('*')):
        raise RuntimeError('Kernel export contains a symlink')
    summary_path = root / 'kernel-summary.json'
    summary_raw = summary_path.read_bytes()
    summary = json.loads(summary_raw)
    expected = {'schema': 'alpbahOS.kernel-guest/v1', 'result': 'PASS', 'stage': STAGE,
        'run_id': value['run_id'], 'inputs_sha256': value['inputs_sha256'],
        'sources_sha256': value['sources_sha256'], 'source': source,
        'source_archive_sha256': source['sha256'], 'recipe_sha256': recipe_sha,
        'runner_sha256': guest_runner_sha, 'kernel_release': '6.16.1-alpbahOS',
        'test': 'headers_check', 'config_options_required': 26}
    if any(summary.get(key) != expected_value for key, expected_value in expected.items()):
        raise RuntimeError('Kernel guest summary binding/result differs')
    for name, expected_hash in (('built.json', summary.get('built_record_sha256')),
                                ('db-final.json', summary.get('alp_database_sha256')),
                                ('linux-kernel.installed.json', summary.get('install_receipt_sha256')),
                                (f'{value["run_id"]}.log', summary.get('build_log_sha256')),
                                ('linux-kernel.install.log', summary.get('install_log_sha256'))):
        path = root / name
        if (not isinstance(expected_hash, str) or not HASH.fullmatch(expected_hash)
                or path.is_symlink() or not path.is_file() or sha(path) != expected_hash):
            raise RuntimeError('Kernel guest evidence hash mismatch: ' + name)
    record = json.loads((root / 'built.json').read_bytes())
    built = record.get('built')
    if (record.get('schema') != 'alpbahOS.kernel-built/v1'
            or record.get('run_id') != value['run_id'] or record.get('recipe_sha256') != recipe_sha
            or not isinstance(built, dict) or built.get('source') != source
            or Path(built.get('archive', '')).name != f'{run_id}.tar.gz'
            or Path(built.get('manifest', '')).name != f'{run_id}.json'):
        raise RuntimeError('Kernel built record/source binding invalid')
    built['archive'] = root / 'linux-kernel.tar.gz'
    built['manifest'] = root / 'linux-kernel.json'
    recipe = json.loads(RECIPE.read_bytes())
    bundle = package_install.validate_bundle(recipe, built)
    if (built.get('archive_sha256') != summary.get('archive_sha256')
            or built.get('manifest_sha256') != summary.get('manifest_sha256')
            or len(bundle['entries']) != summary.get('manifest_entry_count')):
        raise RuntimeError('Kernel archive/manifest hashes or entry count differ')
    db_raw = (root / 'db-final.json').read_bytes()
    database = json.loads(db_raw)
    installed = database.get('packages', {}).get('linux-kernel', {})
    entries = {entry['path'] for entry in bundle['entries'] if entry['type'] != 'directory'}
    owners = set(installed.get('files', [])) | set(installed.get('symlinks', []))
    if (database.get('schema_version') != 1 or installed.get('status') != 'installed'
            or installed.get('version') != recipe['version'] or not entries.issubset(owners)
            or package_install.fingerprint(installed) != summary.get('alp_record_sha256')):
        raise RuntimeError('Kernel Alp DB ownership evidence invalid')
    receipt = json.loads((root / 'linux-kernel.installed.json').read_bytes())
    if (receipt.get('result') != 'PASS' or receipt.get('package') != 'linux-kernel'
            or receipt.get('version') != recipe['version']
            or receipt.get('archive_sha256') != built['archive_sha256']
            or receipt.get('manifest_sha256') != built['manifest_sha256']
            or receipt.get('db_sha256') != summary.get('alp_database_sha256')):
        raise RuntimeError('Kernel Alp install receipt invalid')
    return {'schema': 'alpbahOS.kernel-guest-proof/v1', 'result': 'VERIFIED_GUEST_BYTES',
        'run_id': value['run_id'], 'guest_boot_id': summary['guest_boot_id'],
        'inputs_sha256': value['inputs_sha256'], 'sources_sha256': value['sources_sha256'],
        'summary_sha256': digest(summary_raw), 'archive_sha256': built['archive_sha256'],
        'manifest_sha256': built['manifest_sha256'], 'config_sha256': summary['config_sha256'],
        'alp_database_sha256': summary['alp_database_sha256'],
        'owned_payload_paths': len(entries), 'kernel_release': summary['kernel_release']}


def stop_guest():
    if buildctl.pid() is not None:
        buildctl.stop()


def execute():
    if os.geteuid() == 0:
        raise RuntimeError('Product stage controller must run as unprivileged host user')
    buildctl.initialize_dirs()
    with (buildctl.STATE / 'controller.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if buildctl.pid() is not None:
            raise RuntimeError('Builder already running; preserve active writer')
        base = load_base_controller()
        toolchain_proof, parent_raw, base_proof = accepted_base(base)
        inputs_sha = buildctl.inputs_digest()
        sources_sha = buildctl.sha(REPO / 'manifests/infra-sources.json')
        source_manifest = json.loads((REPO / 'manifests/infra-sources.json').read_bytes())
        source_rows = [row for row in source_manifest['sources'] if row['filename'] == KERNEL_SOURCE]
        if len(source_rows) != 1:
            raise RuntimeError('Pinned Linux kernel source missing/ambiguous')
        source = source_rows[0]
        if source_manifest.get('abi_selection', {}).get('mode') != 'multilib-m32':
            raise RuntimeError('Kernel ABI differs from accepted user selection')
        buildctl.verify_cache(); buildctl.verify_signatures()
        buildctl.restore('base')
        lfs_disk_capacity = grow_lfs_disk()

        run_id = os.urandom(16).hex()
        run_root = stage_runs.directory(stage_runs.RUNS, run_id)
        artifact_root = stage_runs.directory(stage_runs.ARTIFACTS, run_id)
        controller_sha = sha(Path(__file__))
        recipe_sha = sha(RECIPE)
        guest_runner_sha = sha(GUEST_RUNNER)
        producer_sha = digest(audit.PRODUCER.read_bytes())
        phase1_sha = buildctl.sha(buildctl.ARTIFACTS / 'phase1-acceptance.json')
        before_path, before_sha = audit.request(STAGE, 'before', run_id, inputs_sha, sources_sha)
        value = {'schema': 'alpbahOS.stage-run/v1', 'stage': STAGE,
            'mode': 'multilib-m32', 'run_id': run_id, 'inputs_sha256': inputs_sha,
            'sources_sha256': sources_sha, 'phase1_sha256': phase1_sha,
            'boot_id': audit.BOOT.read_text().strip(), 'created_at_ns': time.time_ns(),
            'before_request': str(before_path), 'before_request_sha256': before_sha,
            'producer_sha256': producer_sha, 'controller_sha256': controller_sha,
            'base_acceptance_sha256': sha(buildctl.ARTIFACTS / 'base-acceptance.json'),
            'base_run_id': base_proof['run_id'], 'base_checkpoint_sha256': base_proof['checkpoint_sha256'],
            'toolchain_run_id': toolchain_proof['run_id'], 'recipe_sha256': recipe_sha,
            'guest_runner_sha256': guest_runner_sha}
        stage_runs.write(run_root / 'run.json', value)
        run_raw = (run_root / 'run.json').read_bytes(); run_sha = digest(run_raw)
        stage_runs.write(artifact_root / 'controller.json', {'path': str(Path(__file__)),
            'sha256': controller_sha, 'git_head': subprocess.check_output(
                ['git', '-C', str(REPO), 'rev-parse', 'HEAD'], text=True).strip(),
            'recipe_sha256': recipe_sha, 'guest_runner_sha256': guest_runner_sha})
        baseline = host_monitor.sample(); host_monitor.validate_sample(baseline)
        if baseline['boot_id'] != value['boot_id']:
            raise RuntimeError('Host boot changed before kernel stage')
        stage_runs.write(artifact_root / 'host-baseline.json', baseline)
        root_capture(before_path, before_sha)
        stage_runs.begin(value, run_sha, before_path.read_bytes())
        errors, guest_proof = [], None
        guest_dir = artifact_root / 'guest-kernel'
        try:
            stage_runs.execution_guard(value, run_sha)
            stage_runs.repository_snapshot(value, 'before')
            wait_for_memory()
            buildctl.launch(offline=True, vcpus=8)
            buildctl.sync()
            if buildctl.inputs_digest() != inputs_sha:
                raise RuntimeError('Frozen build inputs changed during Builder sync')
            boot_raw = guest_read('cat /proc/sys/kernel/random/boot_id', 256)
            guest_boot = boot_raw.decode().strip()
            if not BOOT_ID.fullmatch(guest_boot):
                raise RuntimeError('Kernel Builder boot identity malformed')
            lfs_filesystem_capacity = grow_lfs_filesystem()
            stage_runs.write(artifact_root / 'lfs-capacity.json', {
                'disk': lfs_disk_capacity, 'filesystem': lfs_filesystem_capacity})
            stage_runs.write(artifact_root / 'guest-boot.json', {'boot_id': guest_boot,
                'queried_at_ns': time.time_ns(), 'result': 'PASS'})
            transfer_inputs(run_id, artifact_root, source)
            payload, authorization, base_auth, receipt = base.package_auth(
                base.base_plan.load(BASE_REPO), run_id, guest_boot, toolchain_proof,
                parent_raw, guest_runner_sha256=base.sha(base.GUEST_RUNNER))
            auth = subprocess.run(buildctl.ssh_args() + [
                'set -euo pipefail; source /opt/alp-infra/scripts/infra/guest-guard.sh; '
                'guest_guard; python3 /opt/alp-infra/infra-base-authorize.py'],
                input=encoded(payload), capture_output=True, timeout=120)
            if auth.returncode or auth.stderr:
                raise RuntimeError('Fresh base authorization install failed: '
                                   + auth.stderr.decode(errors='replace')[-1200:])
            auth_receipt = json.loads(auth.stdout)
            if (auth_receipt.get('result') != 'INSTALLED' or auth_receipt.get('run_id') != run_id
                    or auth_receipt.get('guest_boot_id') != guest_boot
                    or auth_receipt.get('base_authorization_sha256') != digest(encoded(base_auth))):
                raise RuntimeError('Fresh kernel guest authorization receipt differs')
            stage_runs.write(artifact_root / 'authorization.json', {
                'authorization': authorization, 'base_authorization': base_auth,
                'receipt': auth_receipt, 'toolchain_receipt_sha256': digest(encoded(receipt))})
            binding = {'run_id': run_id, 'stage': STAGE, 'inputs_sha256': inputs_sha,
                       'sources_sha256': sources_sha, 'boot_id': value['boot_id']}
            log_path, telemetry_path = artifact_root / 'kernel.log', artifact_root / 'kernel.host.jsonl'
            with log_path.open('xb') as log, telemetry_path.open('x') as telemetry:
                command = host_monitor.run_monitored(buildctl.ssh_args() + [
                    'set -euo pipefail; source /opt/alp-infra/scripts/infra/guest-guard.sh; '
                    'guest_guard; ' + kernel_service_command(run_id, recipe_sha)],
                    log, telemetry, buildctl.space_guard, binding=binding)
            stage_runs.write(artifact_root / 'kernel-command.json', command)
            capture_guest(run_id, guest_dir)
            buildctl.stop()
            stage_runs.repository_snapshot(value, 'after')
            guest_proof = validate_guest_export(guest_dir, value, source, recipe_sha, guest_runner_sha)
            stage_runs.write(artifact_root / 'guest-artifact-proof.json', guest_proof)
            chains = checkpoint_store.inspect_disks(buildctl.VM, assert_stopped, buildctl.space_guard)
            stage_runs.write(artifact_root / 'disks-closed.json', {'run_id': run_id,
                'time_ns': time.time_ns(), 'chains': chains})
        except BaseException as error:
            errors.append(error)
            try:
                if buildctl.pid() is not None and not guest_dir.exists():
                    capture_guest(run_id, artifact_root / 'guest-kernel-partial')
            except BaseException as capture_error:
                errors.append(capture_error)
            try:
                stop_guest()
                if (buildctl.pid() is None and not guest_dir.exists()
                        and not (artifact_root / 'guest-kernel-partial').exists()):
                    capture_guest(run_id, artifact_root / 'guest-kernel-partial')
            except BaseException as capture_error:
                errors.append(capture_error)
            try:
                stage_runs.repository_snapshot(value, 'after')
            except BaseException as repository_error:
                errors.append(repository_error)
        outcome = stage_runs.finish(value, run_sha, errors, guest_proof, assert_stopped)
        if errors or outcome.get('result') != 'PENDING_PRIVILEGED_POST':
            raise RuntimeError('Kernel execution failed/incomplete; evidence preserved, do not replay')
        post = stage_runs.after_request(value, run_sha)
        root_capture(Path(post['request']), post['request_sha256'])
        acceptance = accept_kernel(run_id, post['audit_id'], value, guest_proof, outcome,
                                   baseline, binding, artifact_root, source)
        stage_runs.write(run_root / 'acceptance.json', {'proof': acceptance,
            'accepted_at_ns': time.time_ns()})
        checkpoint = checkpoint_store.create(buildctl.VM, STAGE, inputs_sha, sources_sha,
            acceptance, assert_stopped, buildctl.space_guard)
        checkpoint_value = verify_kernel_checkpoint(checkpoint, acceptance)
        result = {**acceptance, **checkpoint_value}
        output = buildctl.ARTIFACTS / 'kernel-acceptance.json'
        stage_runs.write(output, result)
        print(json.dumps({'result': 'PASS', 'run_id': run_id, 'acceptance': str(output),
            'checkpoint': str(checkpoint), 'checkpoint_sha256': result['checkpoint_sha256']}, sort_keys=True))


def accept_kernel(run_id, after_id, value, guest, outcome, baseline, binding, artifact_root, source):
    run_root = stage_runs.RUNS / run_id
    run_raw, current = stage_runs.read(run_root / 'run.json')
    started_raw, started = stage_runs.read(run_root / 'started.json')
    outcome_raw, recorded = stage_runs.read(run_root / 'outcome.json')
    hashes = stage_runs.file_hashes(artifact_root)
    if (current != value or digest(run_raw) != recorded.get('run_sha256')
            or recorded.get('result') != 'PENDING_PRIVILEGED_POST' or recorded.get('errors') != []
            or recorded.get('artifact_sha256') != hashes or recorded.get('guest_artifact_evidence') != guest
            or recorded.get('started_sha256') != digest(started_raw)
            or started.get('run_sha256') != digest(run_raw)):
        raise RuntimeError('Kernel stage run/outcome/evidence binding invalid')
    _, after = stage_runs.read(run_root / ('after-' + after_id + '.json'))
    if after.get('outcome_sha256') != digest(outcome_raw):
        raise RuntimeError('Kernel privileged after-audit request belongs to another run')
    before_raw = audit.read_file(Path(value['before_request']), audit.USER_UID, 65536)
    after_raw = audit.read_file(Path(after['request']), audit.USER_UID, 65536)
    host = audit.verify_pair(before_raw, after_raw, value['producer_sha256'],
                             started['started_at_ns'], recorded['ended_at_ns'])
    if host['before'] != started.get('before_host_evidence'):
        raise RuntimeError('Kernel before-host audit evidence changed')
    host_monitor.validate_sample(baseline)
    if baseline.get('boot_id') != value['boot_id'] or baseline['completed_at_ns'] > started['started_at_ns']:
        raise RuntimeError('Kernel host baseline does not precede stage')
    command = json.loads(audit.read_file(artifact_root / 'kernel-command.json', audit.USER_UID))
    telemetry = host_monitor.verify_recording(audit.read_file(
        artifact_root / 'kernel.host.jsonl', audit.USER_UID), command, binding,
        started['started_at_ns'], recorded['ended_at_ns'])
    repos = [json.loads(audit.read_file(artifact_root / ('repositories-' + phase + '.json'), audit.USER_UID))
             for phase in ('before', 'after')]
    for phase, row in zip(('before', 'after'), repos):
        if (row.get('run_id') != run_id or row.get('phase') != phase
                or not started['started_at_ns'] <= row.get('time_ns', 0) <= recorded['ended_at_ns']
                or set(row.get('repositories', {})) != {str(path) for path in stage_runs.REPOSITORIES}):
            raise RuntimeError('Kernel repository snapshot coverage/timing invalid')
        for observation in row['repositories'].values():
            for field in ('head', 'branch', 'status'):
                raw = observation.get(field)
                if not isinstance(raw, str) or digest(raw.encode()) != observation.get(field + '_sha256'):
                    raise RuntimeError('Kernel repository observation hash mismatch')
    if repos[0]['repositories'] != repos[1]['repositories']:
        raise RuntimeError('Repository worktree changed during kernel stage')
    if (command.get('exit') != 0 or command.get('binding') != binding
            or guest.get('result') != 'VERIFIED_GUEST_BYTES' or guest.get('run_id') != run_id
            or guest.get('inputs_sha256') != value['inputs_sha256']
            or guest.get('sources_sha256') != value['sources_sha256']
            or guest.get('kernel_release') != '6.16.1-alpbahOS'):
        raise RuntimeError('Kernel command or guest acceptance proof invalid')
    transfer = json.loads(audit.read_file(artifact_root / 'kernel-transfer.json', audit.USER_UID))
    if (transfer.get('run_id') != run_id or transfer.get('source_sha256') != source['sha256']
            or transfer.get('verified_on_guest') is not True):
        raise RuntimeError('Kernel source transfer evidence invalid')
    closed = json.loads(audit.read_file(artifact_root / 'disks-closed.json', audit.USER_UID))
    if (closed.get('run_id') != run_id or not command['ended_at_ns'] <= closed.get('time_ns', 0)
            <= recorded['ended_at_ns']):
        raise RuntimeError('Kernel closed-disk evidence timing invalid')
    chains = checkpoint_store.inspect_disks(buildctl.VM, assert_stopped, buildctl.space_guard)
    if chains != closed.get('chains') or stage_runs.file_hashes(artifact_root) != hashes:
        raise RuntimeError('Kernel disk chain or evidence bytes changed before acceptance')
    return {'schema': 'alpbahOS.kernel-acceptance/v1', 'result': 'PASS', 'stage': STAGE,
        'run_id': run_id, 'after_audit_id': after_id, 'mode': 'multilib-m32',
        'inputs_sha256': value['inputs_sha256'], 'sources_sha256': value['sources_sha256'],
        'run_sha256': digest(run_raw), 'outcome_sha256': digest(outcome_raw),
        'controller_sha256': value['controller_sha256'], 'recipe_sha256': value['recipe_sha256'],
        'artifact_sha256': hashes, 'host': host, 'telemetry': telemetry, 'guest': guest,
        'closed_disk_chains': chains,
        'scope': 'pinned Linux kernel package, required virtio/EFI/IA32 config, Alp ownership, current host audit and closed checkpoint'}


def verify_kernel_checkpoint(directory, acceptance):
    cp_raw = (directory / 'checkpoint.json').read_bytes()
    tx_raw = (directory / 'transaction.json').read_bytes()
    cp, tx = json.loads(cp_raw), json.loads(tx_raw)
    if (tx.get('status') != 'COMPLETE' or tx.get('name') != STAGE
            or tx.get('acceptance') != acceptance or cp.get('acceptance') != acceptance
            or tx.get('inputs_sha256') != acceptance['inputs_sha256']
            or tx.get('sources_sha256') != acceptance['sources_sha256']):
        raise RuntimeError('Kernel checkpoint transaction is not committed to acceptance')
    for disk in ('builder', 'lfs'):
        path = directory / (disk + '.qcow2')
        if sha(path) != tx.get('original_sha256', {}).get(disk):
            raise RuntimeError('Kernel checkpoint disk changed: ' + disk)
        checked = subprocess.run(['qemu-img', 'check', path], capture_output=True, text=True)
        if checked.returncode or 'No errors were found' not in checked.stdout:
            raise RuntimeError('Kernel checkpoint qcow2 check failed: ' + disk)
        active = buildctl.VM / (disk + '-active.qcow2')
        chain = json.loads(subprocess.run(['qemu-img', 'info', '--output=json', '--backing-chain',
            active], check=True, capture_output=True, text=True).stdout)
        if (len(chain) < 2 or Path(chain[1]['filename']) != path
                or [Path(row['path']) for row in cp.get('backing_chains', {}).get(disk, [])]
                   != [Path(row['filename']) for row in chain[1:]]):
            raise RuntimeError('Kernel active qcow2 chain differs from checkpoint')
    return {'checkpoint_sha256': digest(cp_raw), 'transaction_sha256': digest(tx_raw)}


def main():
    if len(sys.argv) != 1:
        raise RuntimeError('No command-line overrides accepted')
    execute()


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, subprocess.SubprocessError, ValueError, KeyError) as error:
        print('STOP: ' + str(error), file=sys.stderr)
        raise SystemExit(1)
