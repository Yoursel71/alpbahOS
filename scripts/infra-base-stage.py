#!/usr/bin/env python3
"""Single-use host controller for the accepted LFS 12.4 multilib base stage.

This host-only entrypoint is intentionally outside buildctl's build-input set.
Its own source hash and unchanged repository snapshots are pinned in every run.
All package builds and Alp installs execute in the isolated KVM guest.
"""
import fcntl
import hashlib
import json
import os
import re
import secrets
import shlex
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / 'scripts/infra'))
import base_plan
import buildctl
import checkpoint_store
import handoff_binding
import host_monitor
import host_stage_audit as audit
import package_install
import stage_runs
import toolchain_handoff

MODE = 'multilib-m32'
TOOLCHAIN_PACKAGES = ('filesystem-layout', 'binutils-pass1', 'gcc-pass1', 'linux-headers',
                      'glibc-cross-m64', 'glibc-cross-m32', 'libstdcxx-cross')
CHECKPOINT = buildctl.VM / 'checkpoint-toolchain'
TOOLCHAIN_ACCEPTANCE = buildctl.ARTIFACTS / 'toolchain-acceptance.json'
GUEST_HELPER = REPO / 'scripts/infra-base-authorize.py'
GUEST_RUNNER = REPO / 'scripts/infra-base-guest-run.py'
BOOT_PATTERN = re.compile(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def encoded(value):
    return (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()


def toolchain_parent_ids(proof, transaction, parent):
    """Resolve accepted run identities from the mutually bound receipts."""
    run_id = stage_runs.identity(proof.get('run_id'))
    audit_id = stage_runs.identity(proof.get('after_audit_id'))
    parent_run_id = stage_runs.identity(parent.get('parent_run_id'))
    if (transaction.get('acceptance', {}).get('run_id') != run_id
            or parent.get('run_id') != run_id or parent.get('parent_run_id') != parent_run_id
            or parent.get('stage') != 'toolchain' or parent.get('mode') != MODE):
        raise RuntimeError('Toolchain/stability parent identities do not match their receipts')
    return run_id, audit_id, parent_run_id


def stop_guest():
    if buildctl.pid() is not None:
        buildctl.stop()


def assert_guest_stopped():
    if buildctl.pid() is not None:
        raise RuntimeError('Builder is live; refusing disk inspection/checkpoint')


def accepted_toolchain():
    buildctl.space_guard()
    proof = json.loads(TOOLCHAIN_ACCEPTANCE.read_bytes())
    checkpoint_raw = (CHECKPOINT / 'checkpoint.json').read_bytes()
    transaction_raw = (CHECKPOINT / 'transaction.json').read_bytes()
    record, transaction = json.loads(checkpoint_raw), json.loads(transaction_raw)
    run_id = stage_runs.identity(proof.get('run_id'))
    parent_path = stage_runs.RUNS / run_id / 'parent.json'
    parent_raw = parent_path.read_bytes()
    parent = json.loads(parent_raw)
    run_id, audit_id, parent_run_id = toolchain_parent_ids(proof, transaction, parent)
    if (proof.get('schema') != 'alpbahOS.toolchain-acceptance/v1' or proof.get('result') != 'PASS'
            or proof.get('stage') != 'toolchain' or proof.get('mode') != MODE
            or proof.get('run_id') != run_id or proof.get('after_audit_id') != audit_id
            or proof.get('inputs_sha256') != buildctl.inputs_digest()
            or proof.get('sources_sha256') != buildctl.sha(REPO / 'manifests/infra-sources.json')
            or proof.get('checkpoint_sha256') != digest(checkpoint_raw)
            or proof.get('transaction_sha256') != digest(transaction_raw)
            or record.get('acceptance') != transaction.get('acceptance')
            or transaction.get('status') != 'COMPLETE' or transaction.get('name') != 'toolchain'
            or transaction.get('acceptance', {}).get('schema') != 'alpbahOS.toolchain-acceptance/v1'
            or transaction.get('acceptance', {}).get('result') != 'PASS'
            or transaction.get('acceptance', {}).get('run_id') != run_id
            or transaction.get('inputs_sha256') != proof.get('inputs_sha256')
            or transaction.get('sources_sha256') != proof.get('sources_sha256')):
        raise RuntimeError('Current toolchain artifact/checkpoint/transaction do not form the accepted parent')
    for disk in ('builder', 'lfs'):
        saved = CHECKPOINT / (disk + '.qcow2')
        row = record.get(disk, {})
        if (row.get('path') != str(saved) or row.get('sha256') != sha(saved)
                or transaction.get('original_sha256', {}).get(disk) != sha(saved)):
            raise RuntimeError('Accepted toolchain saved disk changed: ' + disk)
        checked = subprocess.run(['qemu-img', 'check', saved], capture_output=True, text=True)
        if checked.returncode or 'No errors were found' not in checked.stdout:
            raise RuntimeError('Accepted toolchain qcow2 failed check: ' + disk)
        active = buildctl.VM / (disk + '-active.qcow2')
        chain = json.loads(subprocess.run(['qemu-img', 'info', '--output=json', '--backing-chain',
                                           active],
                                          check=True, capture_output=True, text=True).stdout)
        expected_chain = record.get('backing_chains', {}).get(disk, [])
        actual_paths = [Path(row['filename']) for row in chain[1:]]
        if ([Path(row['path']) for row in expected_chain] != actual_paths
                or len(chain) != len(expected_chain) + 1 or Path(chain[1]['filename']) != saved):
            raise RuntimeError('Current restored overlay no longer starts from accepted toolchain: ' + disk)
        for row in expected_chain:
            if sha(Path(row['path'])) != row['sha256']:
                raise RuntimeError('Accepted toolchain ancestor changed: ' + row['path'])
        active_check = subprocess.run(['qemu-img', 'check', active], capture_output=True, text=True)
        if active_check.returncode or 'No errors were found' not in active_check.stdout:
            raise RuntimeError('Restored active qcow2 failed check: ' + disk)
    # Revalidate the previous stability parent via immutable toolchain-run bytes.
    if (digest(parent_raw) != proof.get('parent_sha256')
            or digest(parent_raw) != proof.get('parent_capsule_sha256')):
        raise RuntimeError('Accepted toolchain stability-parent bytes changed')
    if (parent.get('schema') != toolchain_handoff.PARENT_SCHEMA
            or parent.get('result') != 'VERIFIED_PARENT' or parent.get('stage') != 'toolchain'
            or parent.get('run_id') != run_id or parent.get('parent_run_id') != parent_run_id
            or parent.get('mode') != MODE
            or parent.get('inputs_sha256') != proof.get('inputs_sha256')
            or parent.get('sources_sha256') != proof.get('sources_sha256')):
        raise RuntimeError('Accepted toolchain parent capsule identity invalid')
    return proof, parent_raw


def root_capture(request_path, request_sha):
    result = subprocess.run(stage_runs.root_command(request_path, request_sha),
                            capture_output=True, text=True, timeout=600,
                            env={**os.environ, 'LC_ALL': 'C', 'LANG': 'C'})
    if result.returncode or result.stderr.strip():
        raise RuntimeError('Privileged host audit failed: ' + result.stderr[-1000:])
    value = json.loads(result.stdout)
    if value.get('result') != 'CAPTURED':
        raise RuntimeError('Privileged host audit did not capture complete evidence')
    return value


def guest_read(command, limit=262144):
    result = subprocess.run(buildctl.ssh_args() + [command], capture_output=True, timeout=30)
    if result.returncode or result.stderr or len(result.stdout) > limit:
        raise RuntimeError('Bounded guest read failed: ' + command)
    return result.stdout


def guest_write_exclusive(path, raw):
    command = "set -euo pipefail; test ! -e '" + path + "' && test ! -L '" + path + "' && cat > '" + path + "'"
    result = subprocess.run(buildctl.ssh_args() + ['bash -c ' + shlex.quote(command)],
                            input=raw, capture_output=True, timeout=30)
    if result.returncode or result.stdout or result.stderr:
        raise RuntimeError('Exclusive guest evidence write failed: ' + path)


def copy_inputs(plan, artifact_root, guest_runner_sha256):
    buildctl.verify_cache()
    transport = shlex.join(buildctl.ssh_args()[:-1])
    remote = 'root@127.0.0.1:'
    subprocess.run(buildctl.ssh_args() + [
        'mkdir -p /opt/alp-infra/recipes/base /opt/alp-infra/configs /srv/lfs/sources'],
        check=True, timeout=30)
    subprocess.run(['rsync', '-rt', '-e', transport,
                    str(REPO / 'manifests/lfs-base-12.4-systemd.json'),
                    remote + '/opt/alp-infra/manifests/'], check=True, timeout=120)
    subprocess.run(['rsync', '-rt', '-e', transport,
                    str(REPO / 'manifests/infra-stages.json'),
                    remote + '/opt/alp-infra/manifests/'], check=True, timeout=120)
    subprocess.run(['rsync', '-rt', '-e', transport, str(REPO / 'configs') + '/',
                    remote + '/opt/alp-infra/configs/'], check=True, timeout=120)
    subprocess.run(['rsync', '-rt', '-e', transport, str(REPO / 'recipes/base') + '/',
                    remote + '/opt/alp-infra/recipes/base/'], check=True, timeout=120)
    subprocess.run(['rsync', '-rt', '-e', transport, str(GUEST_HELPER),
                    remote + '/opt/alp-infra/infra-base-authorize.py'], check=True, timeout=120)
    if sha(GUEST_RUNNER) != guest_runner_sha256:
        raise RuntimeError('Guest base runner changed after stage binding')
    subprocess.run(['rsync', '-rt', '-e', transport, str(GUEST_RUNNER),
                    remote + '/opt/alp-infra/infra-base-guest-run.py'], check=True, timeout=120)
    wanted = sorted({source['filename'] for row in plan
                     for source in [row['source'], *row['auxiliary_sources']]})
    list_path = artifact_root / 'source-list.txt'
    if list_path.exists() or list_path.is_symlink():
        raise RuntimeError('Existing source transfer list preserved')
    with list_path.open('x') as stream:
        stream.write(''.join(name + '\n' for name in wanted))
        stream.flush(); os.fsync(stream.fileno())
    for name in wanted:
        path = buildctl.CACHE / name
        if (not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._+-]*', name)
                or path.is_symlink() or path.resolve() != path or not path.is_file()):
            raise RuntimeError('Pinned base source is missing or aliased: ' + name)
        expected = next(s['sha256'] for row in plan
                        for s in [row['source'], *row['auxiliary_sources']]
                        if s['filename'] == name)
        if sha(path) != expected:
            raise RuntimeError('Pinned base source bytes changed: ' + name)
    subprocess.run(['rsync', '-rt', '--files-from=' + str(list_path), '-e', transport,
                    str(buildctl.CACHE) + '/', remote + '/srv/lfs/sources/'], check=True, timeout=1800)
    if sha(GUEST_RUNNER) != guest_runner_sha256:
        raise RuntimeError('Guest base runner changed during input transfer')
    return {'count': len(wanted), 'files': wanted,
            'source_list_sha256': sha(list_path),
            'guest_runner_sha256': guest_runner_sha256,
            'total_bytes': sum((buildctl.CACHE / name).stat().st_size for name in wanted)}


def package_auth(plan, run_id, guest_boot, proof, parent_raw, guest_runner_sha=None):
    guest_runner_sha = guest_runner_sha or sha(GUEST_RUNNER)
    parent = json.loads(parent_raw)
    old_auth = json.loads(guest_read('cat /srv/infra/phase2-authorization.json'))
    old_handoff_raw = guest_read('cat /srv/infra/stability-acceptance.json')
    inputs = json.loads(guest_read('cat /srv/infra/inputs.json'))
    if (inputs.get('inputs_sha256') != buildctl.inputs_digest()
            or inputs.get('sources_sha256') != buildctl.sha(REPO / 'manifests/infra-sources.json')
            or old_auth.get('stage') != 'toolchain' or old_auth.get('run_id') != proof['run_id']
            or old_auth.get('handoff_sha256') != digest(old_handoff_raw)
            or old_auth.get('guest_boot_id') != json.loads(old_handoff_raw).get('guest_boot_id')):
        raise RuntimeError('Restored toolchain guest authorization has stale inputs or unpaired evidence')
    handoff_raw = toolchain_handoff.bind_guest(parent_raw, digest(parent_raw), proof['run_id'], guest_boot)
    authorization = {'schema': 'alpbahOS.phase2-authorization/v1', 'stage': 'toolchain',
        'mode': MODE, 'oc_confirmed': True, 'run_id': proof['run_id'],
        'inputs_sha256': proof['inputs_sha256'], 'sources_sha256': proof['sources_sha256'],
        'boot_id': parent['host_boot_id'], 'guest_boot_id': guest_boot,
        'handoff_sha256': digest(handoff_raw), 'authorized_at_ns': time.time_ns()}
    handoff_binding.validate(handoff_raw, authorization, inputs, guest_boot)
    toolchain_raw = TOOLCHAIN_ACCEPTANCE.read_bytes()
    receipt = json.loads(toolchain_raw)
    receipt['proof_sha256'] = digest(toolchain_raw)
    receipt_raw = encoded(receipt)
    controller_sha = sha(Path(__file__))
    base = {'schema': 'alpbahOS.base-authorization/v1', 'result': 'AUTHORIZED',
        'stage': 'base', 'mode': MODE, 'oc_confirmed': True, 'run_id': run_id,
        'inputs_sha256': proof['inputs_sha256'], 'sources_sha256': proof['sources_sha256'],
        'phase2_authorization_sha256': digest(encoded(authorization)),
        'stability_acceptance_sha256': digest(handoff_raw),
        'toolchain_acceptance_sha256': digest(receipt_raw),
        'controller_sha256': controller_sha,
        'guest_runner_sha256': guest_runner_sha,
        'guest_boot_id': guest_boot, 'authorized_at_ns': time.time_ns()}
    payload = {'toolchain_raw': toolchain_raw.decode(), 'toolchain_receipt': receipt,
        'parent_raw': parent_raw.decode(), 'handoff_raw': handoff_raw.decode(),
        'authorization': authorization, 'base_authorization': base,
        'controller_sha256': controller_sha, 'guest_runner_sha256': guest_runner_sha}
    if len(encoded(payload)) > 262144:
        raise RuntimeError('Base guest authorization payload exceeds fixed bound')
    return payload, authorization, base, receipt


def validate_guest_export(root, plan, run_id, inputs_sha, sources_sha,
                          toolchain_receipt_sha, base_authorization_sha):
    if any(p.is_symlink() for p in root.rglob('*')):
        raise RuntimeError('Guest export contains a symlink')
    summary_path, db_path = root / 'summary.json', root / 'db-final.json'
    summary_raw = summary_path.read_bytes(); summary = json.loads(summary_raw)
    plan_names = [row['name'] for row in plan]
    rows = summary.get('packages')
    if (summary.get('schema') != 'alpbahOS.base-guest/v1' or summary.get('result') != 'PASS'
            or summary.get('run_id') != run_id or summary.get('inputs_sha256') != inputs_sha
            or summary.get('sources_sha256') != sources_sha or summary.get('mode') != MODE
            or summary.get('package_count') != 79 or not isinstance(rows, list)
            or [row.get('package') for row in rows] != plan_names
            or len(summary.get('observations', [])) != 79
            or summary.get('plan_sha256') != package_install.fingerprint(plan)
            or summary.get('inventory_sha256') != buildctl.sha(REPO / 'manifests/lfs-base-12.4-systemd.json')
            or summary.get('toolchain_acceptance_sha256') != toolchain_receipt_sha
            or summary.get('base_authorization_sha256') != base_authorization_sha
            or summary.get('root') != '/srv/lfs'):
        raise RuntimeError('Guest base summary does not prove exact 79-package run binding')
    db_raw = db_path.read_bytes()
    if digest(db_raw) != summary.get('final_db_sha256'):
        raise RuntimeError('Final raw Alp database hash differs from guest summary')
    database = json.loads(db_raw)
    installed = database.get('packages')
    expected_names = {r['name'] for r in plan} | set(TOOLCHAIN_PACKAGES)
    if database.get('schema_version') != 1 or not isinstance(installed, dict) or set(installed) != expected_names:
        raise RuntimeError('Final Alp database package identities differ from exact base/toolchain set')
    observations = {row.get('package'): row for row in summary['observations']}
    if set(observations) != set(plan_names):
        raise RuntimeError('Installed payload observation coverage is incomplete')
    for package in plan:
        name = package['name']; directory = root / name
        built_path, manifest_path = directory / 'built.json', directory / ('base-' + name + '.json')
        archive_path = directory / ('base-' + name + '.tar.gz')
        built_record = json.loads(built_path.read_bytes())
        built = built_record.get('built')
        expected_binding = {'schema': 'alpbahOS.base-guest-binding/v1', 'run_id': run_id,
            'guest_boot_id': summary['guest_boot_id'], 'mode': MODE,
            'inputs_sha256': inputs_sha, 'sources_sha256': sources_sha,
            'plan_sha256': summary['plan_sha256'], 'inventory_sha256': summary['inventory_sha256'],
            'toolchain_acceptance_sha256': summary['toolchain_acceptance_sha256'],
            'base_authorization_sha256': summary['base_authorization_sha256'], 'root': '/srv/lfs'}
        if built_record.get('binding') != expected_binding or built_record.get('result') != 'BUILT':
            raise RuntimeError('Built package binding differs: ' + name)
        built = dict(built)
        built['archive'] = archive_path; built['manifest'] = manifest_path
        if built.get('source') != package['source']:
            raise RuntimeError('Built package source pin differs from canonical inventory: ' + name)
        value = package_install.validate_bundle(package['recipe_data'], built)
        if (rows[plan_names.index(name)].get('archive_sha256') != built.get('archive_sha256')
                or rows[plan_names.index(name)].get('manifest_sha256') != built.get('manifest_sha256')):
            raise RuntimeError('Guest package summary hashes differ from package build record: ' + name)
        record = observations[name]
        observation_path = directory / 'observed.json'
        observation_raw = observation_path.read_bytes()
        observation = json.loads(observation_raw)
        if (record.get('observed') != name + '/observed.json'
                or record.get('observed_sha256') != digest(observation_raw)
                or observation.get('schema') != 'alpbahOS.installed-observation/v1'
                or observation.get('run_id') != run_id or observation.get('package') != name
                or observation.get('root') != '/srv/lfs'
                or observation.get('entries') != value.get('entries')):
            raise RuntimeError('Installed payload observation differs from validated archive: ' + name)
        db_record = installed[name]
        if db_record.get('status') != 'installed' or db_record.get('version') != package['version']:
            raise RuntimeError('Alp database package state/version differs: ' + name)
        owned = set(db_record.get('files', [])) | set(db_record.get('symlinks', []))
        for entry in value['entries']:
            if entry['type'] != 'directory' and entry['path'] not in owned:
                raise RuntimeError('Alp database lacks package payload ownership: ' + name + entry['path'])
    return {'schema': 'alpbahOS.base-guest-evidence/v1', 'result': 'VERIFIED_GUEST_BYTES',
        'run_id': run_id, 'inputs_sha256': inputs_sha, 'sources_sha256': sources_sha,
        'guest_boot_id': summary['guest_boot_id'], 'package_count': 79,
        'final_db_sha256': digest(db_raw), 'summary_sha256': digest(summary_raw)}


def capture_guest(run_id, target):
    target.mkdir(mode=0o700)
    transport = shlex.join(buildctl.ssh_args()[:-1])
    subprocess.run(['rsync', '-rt', '-e', transport,
        f'root@127.0.0.1:/srv/lfs/results/base/{run_id}/', str(target) + '/'],
        check=True, timeout=3600)


def execute():
    if os.geteuid() == 0:
        raise RuntimeError('Host controller must run unprivileged')
    buildctl.initialize_dirs()
    with (buildctl.STATE / 'controller.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if buildctl.pid() is not None:
            raise RuntimeError('Builder already running; preserve it and inspect first')
        initial_inputs = buildctl.inputs_digest()
        plan = base_plan.load(REPO)
        if len(plan) != 79 or any(row['recipe'] == 'pending' for row in plan):
            raise RuntimeError('LFS base inventory/recipes incomplete')
        proof, parent_raw = accepted_toolchain()
        buildctl.verify_cache()
        buildctl.verify_signatures()
        mode = json.loads((REPO / 'manifests/infra-sources.json').read_text())['abi_selection']['mode']
        if mode != MODE:
            raise RuntimeError('Accepted toolchain ABI differs from selected multilib mode')

        # Restore from the accepted parent before binding any current guest boot.
        buildctl.restore('toolchain')
        run_id = secrets.token_hex(16)
        run_root = stage_runs.directory(stage_runs.RUNS, run_id)
        artifact_root = stage_runs.directory(stage_runs.ARTIFACTS, run_id)
        controller_sha = sha(Path(__file__))
        guest_runner_sha = sha(GUEST_RUNNER)
        inputs_sha = initial_inputs
        sources_sha = buildctl.sha(REPO / 'manifests/infra-sources.json')
        phase1_sha = buildctl.sha(buildctl.ARTIFACTS / 'phase1-acceptance.json')
        before_path, before_sha = audit.request('base', 'before', run_id, inputs_sha, sources_sha)
        request_raw = before_path.read_bytes()
        value = {'schema': 'alpbahOS.stage-run/v1', 'stage': 'base', 'mode': MODE,
            'run_id': run_id, 'inputs_sha256': inputs_sha, 'sources_sha256': sources_sha,
            'phase1_sha256': phase1_sha, 'boot_id': audit.BOOT.read_text().strip(),
            'created_at_ns': time.time_ns(), 'before_request': str(before_path),
            'before_request_sha256': before_sha, 'producer_sha256': digest(stage_runs.PRODUCER.read_bytes()),
            'controller_sha256': controller_sha, 'toolchain_checkpoint_sha256': proof['checkpoint_sha256'],
            'guest_runner_sha256': guest_runner_sha,
            'toolchain_transaction_sha256': proof['transaction_sha256'],
            'toolchain_run_id': proof['run_id']}
        stage_runs.write(run_root / 'run.json', value)
        run_raw = (run_root / 'run.json').read_bytes(); run_sha = digest(run_raw)
        stage_runs.write(artifact_root / 'controller.json', {'path': str(Path(__file__)),
            'sha256': controller_sha, 'git_head': subprocess.check_output(
                ['git', '-C', str(REPO), 'rev-parse', 'HEAD'], text=True).strip(),
            'guest_runner_path': str(GUEST_RUNNER), 'guest_runner_sha256': guest_runner_sha})
        baseline = host_monitor.sample()
        host_monitor.validate_sample(baseline)
        if baseline['boot_id'] != value['boot_id']:
            raise RuntimeError('Host boot changed before base-stage start')
        stage_runs.write(artifact_root / 'host-baseline.json', baseline)
        root_capture(before_path, before_sha)
        stage_runs.begin(value, run_sha, request_raw)
        started = True
        errors = []
        guest_proof = None
        try:
            stage_runs.execution_guard(value, run_sha)
            stage_runs.repository_snapshot(value, 'before')
            buildctl.launch(offline=True, vcpus=16)
            buildctl.sync()
            if buildctl.inputs_digest() != inputs_sha:
                raise RuntimeError('Build inputs changed during guest sync')
            boot_query_start = time.time_ns()
            boot_raw = guest_read('cat /proc/sys/kernel/random/boot_id', 256)
            boot_query_end = time.time_ns()
            guest_boot = boot_raw.decode().strip()
            if not BOOT_PATTERN.fullmatch(guest_boot):
                raise RuntimeError('Guest boot identity malformed')
            stage_runs.write(artifact_root / 'boot-query.json', {
                'argv': buildctl.ssh_args() + ['cat /proc/sys/kernel/random/boot_id'],
                'started_at_ns': boot_query_start, 'ended_at_ns': boot_query_end,
                'exit': 0, 'stdout': guest_boot + '\n', 'stderr': ''})
            payload, authorization, base_auth, receipt = package_auth(
                plan, run_id, guest_boot, proof, parent_raw, guest_runner_sha)
            stage_runs.write(artifact_root / 'authorization.json', {
                **authorization, 'base_run_id': run_id,
                'base_authorization_sha256': digest(encoded(base_auth)),
                'controller_sha256': controller_sha})
            transfer = copy_inputs(plan, artifact_root, guest_runner_sha)
            if transfer.get('guest_runner_sha256') != guest_runner_sha:
                raise RuntimeError('Guest runner transfer pin differs')
            stage_runs.write(artifact_root / 'source-transfer.json', transfer)
            install = subprocess.run(buildctl.ssh_args() + [
                'set -euo pipefail; source /opt/alp-infra/scripts/infra/guest-guard.sh; '
                'guest_guard; python3 /opt/alp-infra/infra-base-authorize.py'],
                input=encoded(payload), capture_output=True, timeout=120)
            if install.returncode or install.stderr:
                raise RuntimeError('Guest base authorization install failed: ' + install.stderr.decode(errors='replace')[-1500:])
            installed = json.loads(install.stdout)
            if (installed.get('result') != 'INSTALLED' or installed.get('run_id') != run_id
                    or installed.get('guest_boot_id') != guest_boot
                    or installed.get('guest_runner_sha256') != guest_runner_sha
                    or installed.get('toolchain_acceptance_sha256') != digest(encoded(receipt))
                    or installed.get('base_authorization_sha256') != digest(encoded(base_auth))):
                raise RuntimeError('Guest base authorization receipt differs')
            stage_runs.write(artifact_root / 'authorization-install.json', installed)
            binding = {k: value[k] for k in ('run_id', 'stage', 'inputs_sha256', 'sources_sha256', 'boot_id')}
            log_path, telemetry_path = artifact_root / 'base.log', artifact_root / 'base.host.jsonl'
            with log_path.open('xb') as log, telemetry_path.open('x') as telemetry:
                command = host_monitor.run_monitored(buildctl.ssh_args() + [
                    'set -euo pipefail; source /opt/alp-infra/scripts/infra/guest-guard.sh; '
                    'guest_guard; python3 /opt/alp-infra/infra-base-guest-run.py '
                    + guest_runner_sha],
                    log, telemetry, buildctl.space_guard, binding=binding)
            stage_runs.write(artifact_root / 'base-command.json', command)
            buildctl.stop()
            stage_runs.repository_snapshot(value, 'after')
            guest_dir = artifact_root / 'guest-base'
            capture_guest(run_id, guest_dir)
            install_receipt = json.loads((artifact_root / 'authorization-install.json').read_bytes())
            auth_record = json.loads((artifact_root / 'authorization.json').read_bytes())
            guest_proof = validate_guest_export(guest_dir, plan, run_id, inputs_sha, sources_sha,
                install_receipt['toolchain_acceptance_sha256'], auth_record['base_authorization_sha256'])
            stage_runs.write(artifact_root / 'guest-artifact-proof.json', guest_proof)
            chains = checkpoint_store.inspect_disks(buildctl.VM, assert_guest_stopped, buildctl.space_guard)
            stage_runs.write(artifact_root / 'disks-closed.json', {
                'run_id': run_id, 'time_ns': time.time_ns(), 'chains': chains})
        except BaseException as error:
            errors.append(error)
            try:
                stop_guest()
                if buildctl.pid() is None and not (artifact_root / 'guest-base').exists():
                    guest_dir = artifact_root / 'guest-base-partial'
                    capture_guest(run_id, guest_dir)
            except BaseException as capture_error:
                errors.append(capture_error)
            try:
                stage_runs.repository_snapshot(value, 'after')
            except BaseException as repo_error:
                errors.append(repo_error)
        try:
            assert_guest_stopped()
        except RuntimeError:
            errors.append(RuntimeError('Builder writer remains live after base stage'))
        outcome = stage_runs.finish(value, run_sha, errors, guest_proof, assert_guest_stopped)
        if errors or outcome.get('result') != 'PENDING_PRIVILEGED_POST':
            raise RuntimeError('Base run failed or is incomplete; evidence preserved; never replay it')
        post = stage_runs.after_request(value, run_sha)
        root_capture(Path(post['request']), post['request_sha256'])
        install_receipt = json.loads((artifact_root / 'authorization-install.json').read_bytes())
        auth_record = json.loads((artifact_root / 'authorization.json').read_bytes())
        acceptance = accept(run_id, post['audit_id'], plan, proof,
                            install_receipt, auth_record['base_authorization_sha256'])
        stage_runs.write(run_root / 'acceptance.json', {'proof': acceptance,
            'accepted_at_ns': time.time_ns()})
        buildctl.space_guard()
        checkpoint = checkpoint_store.create(buildctl.VM, 'base', inputs_sha, sources_sha,
            acceptance, assert_guest_stopped, buildctl.space_guard)
        checkpoint_value = verify_base_checkpoint(checkpoint, acceptance)
        result = {**acceptance, 'checkpoint_sha256': checkpoint_value['checkpoint_sha256'],
                  'transaction_sha256': checkpoint_value['transaction_sha256']}
        acceptance_path = buildctl.ARTIFACTS / 'base-acceptance.json'
        stage_runs.write(acceptance_path, result)
        print(json.dumps({'result': 'PASS', 'run_id': run_id, 'after_audit_id': post['audit_id'],
            'package_count': 79, 'acceptance': str(acceptance_path),
            'checkpoint': str(checkpoint), 'checkpoint_sha256': result['checkpoint_sha256']}, sort_keys=True))


def accept(run_id, after_id, plan, toolchain_proof, install_receipt, base_authorization_sha):
    stage_runs.identity(run_id); stage_runs.identity(after_id)
    run_root, artifacts = stage_runs.RUNS / run_id, stage_runs.ARTIFACTS / run_id
    run_raw, value = stage_runs.read(run_root / 'run.json')
    started_raw, started = stage_runs.read(run_root / 'started.json')
    outcome_raw, outcome = stage_runs.read(run_root / 'outcome.json')
    hashes = stage_runs.file_hashes(artifacts)
    if (value.get('stage') != 'base' or value.get('run_id') != run_id
            or value.get('controller_sha256') != sha(Path(__file__))
            or value.get('guest_runner_sha256') != sha(GUEST_RUNNER)
            or value.get('toolchain_checkpoint_sha256') != toolchain_proof['checkpoint_sha256']
            or digest(run_raw) != outcome.get('run_sha256')
            or outcome.get('result') != 'PENDING_PRIVILEGED_POST' or outcome.get('errors') != []
            or outcome.get('artifact_sha256') != hashes
            or outcome.get('started_sha256') != digest(started_raw)
            or started.get('run_sha256') != digest(run_raw)):
        raise RuntimeError('Base run/evidence/controller bytes invalid')
    _, after = stage_runs.read(run_root / ('after-' + after_id + '.json'))
    if after.get('outcome_sha256') != digest(outcome_raw):
        raise RuntimeError('Base post-audit request belongs to another run')
    before_raw = audit.read_file(Path(value['before_request']), audit.USER_UID, 65536)
    after_raw = audit.read_file(Path(after['request']), audit.USER_UID, 65536)
    host = audit.verify_pair(before_raw, after_raw, value['producer_sha256'],
                             started['started_at_ns'], outcome['ended_at_ns'])
    if host['before'] != started.get('before_host_evidence'):
        raise RuntimeError('Base privileged before audit changed')
    baseline = json.loads(audit.read_file(artifacts / 'host-baseline.json', audit.USER_UID))
    host_monitor.validate_sample(baseline)
    if baseline.get('boot_id') != value['boot_id'] or baseline['completed_at_ns'] > started['started_at_ns']:
        raise RuntimeError('Base host baseline did not precede execution')
    command = json.loads(audit.read_file(artifacts / 'base-command.json', audit.USER_UID))
    binding = {k: value[k] for k in ('run_id', 'stage', 'inputs_sha256', 'sources_sha256', 'boot_id')}
    if command.get('exit') != 0 or command.get('binding') != binding:
        raise RuntimeError('Base guest command was not a successful bound execution')
    telemetry = host_monitor.verify_recording(
        audit.read_file(artifacts / 'base.host.jsonl', audit.USER_UID), command, binding,
        started['started_at_ns'], outcome['ended_at_ns'])
    repos = [json.loads(audit.read_file(artifacts / ('repositories-' + p + '.json'), audit.USER_UID))
             for p in ('before', 'after')]
    for phase, record in zip(('before', 'after'), repos):
        if (record.get('run_id') != run_id or record.get('phase') != phase
                or not started['started_at_ns'] <= record.get('time_ns', 0) <= outcome['ended_at_ns']
                or set(record.get('repositories', {})) != {str(p) for p in stage_runs.REPOSITORIES}):
            raise RuntimeError('Base repository snapshot scope/timing invalid')
        for observed in record['repositories'].values():
            for field in ('head', 'branch', 'status'):
                raw = observed.get(field)
                if not isinstance(raw, str) or digest(raw.encode()) != observed.get(field + '_sha256'):
                    raise RuntimeError('Base repository snapshot hash mismatch')
    if repos[0].get('repositories') != repos[1].get('repositories'):
        raise RuntimeError('Repository HEAD/branch/status changed during base run')
    boot_query = json.loads(audit.read_file(artifacts / 'boot-query.json', audit.USER_UID))
    guest = json.loads(audit.read_file(artifacts / 'guest-artifact-proof.json', audit.USER_UID))
    authorization = json.loads(audit.read_file(artifacts / 'authorization.json', audit.USER_UID))
    controller = json.loads(audit.read_file(artifacts / 'controller.json', audit.USER_UID))
    if (guest.get('result') != 'VERIFIED_GUEST_BYTES' or guest.get('run_id') != run_id
            or guest.get('package_count') != 79
            or guest.get('inputs_sha256') != value['inputs_sha256']
            or guest.get('sources_sha256') != value['sources_sha256']
            or guest.get('guest_boot_id') != install_receipt.get('guest_boot_id')
            or boot_query.get('exit') != 0 or boot_query.get('stderr') != ''
            or boot_query.get('stdout', '').strip() != guest.get('guest_boot_id')
            or not started['started_at_ns'] <= boot_query.get('started_at_ns', 0)
                 <= boot_query.get('ended_at_ns', 0) <= command.get('started_at_ns', 0)
            or authorization.get('base_run_id') != run_id
            or authorization.get('base_authorization_sha256') != base_authorization_sha
            or authorization.get('guest_runner_sha256') != value.get('guest_runner_sha256')
            or authorization.get('guest_boot_id') != guest.get('guest_boot_id')
            or controller.get('guest_runner_sha256') != value.get('guest_runner_sha256')
            or install_receipt.get('guest_runner_sha256') != value.get('guest_runner_sha256')
            or install_receipt.get('result') != 'INSTALLED'
            or install_receipt.get('run_id') != run_id
            or install_receipt.get('base_authorization_sha256') != base_authorization_sha):
        raise RuntimeError('Base guest bytes not verified')
    closed = json.loads(audit.read_file(artifacts / 'disks-closed.json', audit.USER_UID))
    if closed.get('run_id') != run_id or not command['ended_at_ns'] <= closed.get('time_ns', 0) <= outcome['ended_at_ns']:
        raise RuntimeError('Base disk closure evidence time invalid')
    chains = checkpoint_store.inspect_disks(buildctl.VM, assert_guest_stopped, buildctl.space_guard)
    if chains != closed.get('chains'):
        raise RuntimeError('Base closed qcow2 chains changed before checkpoint')
    if stage_runs.file_hashes(artifacts) != hashes:
        raise RuntimeError('Base evidence bytes changed during acceptance')
    return {'schema': 'alpbahOS.base-acceptance/v1', 'result': 'PASS', 'stage': 'base',
        'run_id': run_id, 'after_audit_id': after_id, 'mode': MODE,
        'inputs_sha256': value['inputs_sha256'], 'sources_sha256': value['sources_sha256'],
        'run_sha256': digest(run_raw), 'outcome_sha256': digest(outcome_raw),
        'controller_sha256': value['controller_sha256'], 'artifact_sha256': hashes,
        'host': host, 'telemetry': telemetry, 'guest': guest, 'closed_disk_chains': chains,
        'scope': 'accepted LFS Chapter 8 package base only; kernel/BLFS/desktop/ISO remain separate'}


def verify_base_checkpoint(directory, acceptance):
    cp_raw = (directory / 'checkpoint.json').read_bytes()
    tx_raw = (directory / 'transaction.json').read_bytes()
    cp, tx = json.loads(cp_raw), json.loads(tx_raw)
    if (tx.get('status') != 'COMPLETE' or tx.get('name') != 'base'
            or tx.get('acceptance') != acceptance or cp.get('acceptance') != acceptance
            or tx.get('inputs_sha256') != acceptance['inputs_sha256']
            or tx.get('sources_sha256') != acceptance['sources_sha256']):
        raise RuntimeError('Base checkpoint transaction is not fully committed to acceptance')
    for disk in ('builder', 'lfs'):
        path = directory / (disk + '.qcow2')
        if path.stat().st_nlink != 1 or sha(path) != tx.get('original_sha256', {}).get(disk):
            raise RuntimeError('Base checkpoint saved disk differs from committed stage: ' + disk)
        result = subprocess.run(['qemu-img', 'check', path], capture_output=True, text=True)
        if result.returncode or 'No errors were found' not in result.stdout:
            raise RuntimeError('Base checkpoint qcow2 check failed: ' + disk)
        active = buildctl.VM / (disk + '-active.qcow2')
        chain = json.loads(subprocess.run(['qemu-img', 'info', '--output=json', '--backing-chain',
                                           active], check=True, capture_output=True, text=True).stdout)
        expected = cp.get('backing_chains', {}).get(disk, [])
        if (len(chain) != len(expected) + 1
                or Path(chain[1]['filename']) != path
                or [Path(row['path']) for row in expected]
                    != [Path(row['filename']) for row in chain[1:]]):
            raise RuntimeError('Active qcow2 chain no longer matches the new base checkpoint: ' + disk)
        for row in expected:
            if sha(Path(row['path'])) != row['sha256']:
                raise RuntimeError('Base checkpoint ancestor changed: ' + row['path'])
        active_check = subprocess.run(['qemu-img', 'check', active], capture_output=True, text=True)
        if active_check.returncode or 'No errors were found' not in active_check.stdout:
            raise RuntimeError('Post-checkpoint active qcow2 check failed: ' + disk)
    return {'checkpoint_sha256': digest(cp_raw), 'transaction_sha256': digest(tx_raw)}


if __name__ == '__main__':
    try:
        execute()
    except (RuntimeError, OSError, subprocess.SubprocessError, ValueError, KeyError) as error:
        print('STOP: ' + str(error), file=sys.stderr)
        raise SystemExit(1)
