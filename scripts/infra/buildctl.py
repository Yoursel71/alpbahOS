#!/usr/bin/env python3
"""Unprivileged Fedora controller for an isolated QEMU/KVM LFS Builder.

No host sudo, mount, loop device, chroot or passthrough/share. Paths are fixed,
private and resolved; SSH is forwarded on loopback only. Destructive actions
are limited to the disposable guest's serial-identified disk.
"""
import argparse
import fcntl
import hashlib
import json
import os
import re
import shutil
import signal
import shlex
import socket
import subprocess
import sys
import time
import urllib.request
from pathlib import Path
from contextlib import contextmanager
from host_monitor import run_monitored, sample, validate_sample
from stability_evidence import verify_stability_artifacts
from package_stage import local_source_guard
import checkpoint_store
import stage_runs
import stage_acceptance
import toolchain_handoff
import handoff_binding
import toolchain_evidence
import toolchain_acceptance
import base_plan

REPO = Path(__file__).resolve().parents[2]
DATA_MOUNT = Path('/mnt/alpbahOS-data')
SSD_MOUNT = Path('/mnt/alpbahOS-ssd')
DATA = DATA_MOUNT / 'alpbahos-infra-rebuild'
VM = SSD_MOUNT / 'alpbahos-infra-rebuild'
CACHE = DATA / 'cache'
LOGS = DATA / 'logs'
ARTIFACTS = DATA / 'artifacts'
STATE = DATA / 'state'
PORT = 22440
STAGES = ('stability', 'toolchain', 'base', 'kernel', 'blfs-core', 'plasma', 'profiles', 'iso')
CHECKPOINTS = ('prepared', 'builder-ready', 'smoke', *STAGES)


def fail(message):
    raise RuntimeError(message)


def sha(path, algorithm='sha256'):
    h = hashlib.new(algorithm)
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def manifest():
    m = json.loads((REPO / 'manifests/infra-sources.json').read_text())
    objects = [m['builder'], *m['sources'], *m.get('builder_tools', []), *m.get('trust_keys', [])]
    objects += [s['signature'] for s in m['sources'] if s.get('signature')]
    for item in objects:
        if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._+\-]*', item['filename']):
            fail('Unsafe manifest filename')
        if item.get('sha256') is not None and not re.fullmatch('[0-9a-f]{64}', item['sha256']):
            fail('Invalid manifest SHA256')
    filenames = [item['filename'] for item in m['sources']]
    for item in m.get('local_sources', []):
        if item['filename'] in filenames:
            fail('Duplicate external/local source filename')
        filenames.append(item['filename'])
        local_source_guard(item, REPO)
    return m


def inputs_digest():
    paths = [REPO / 'scripts/capture-package-manifest.py', REPO / 'scripts/compare-package-manifest.py']
    build_suffixes = ('.py', '.sh', '.json', '.config', '.conf', '.patch', '.mk')
    for root in ('scripts/infra', 'manifests', 'recipes', 'configs', 'packaging', 'live'):
        paths.extend(p for p in (REPO / root).rglob('*') if p.is_file() and p.suffix in build_suffixes)
    records = {str(p.relative_to(REPO)): sha(p) for p in sorted(set(paths))}
    return hashlib.sha256(json.dumps(records, sort_keys=True).encode()).hexdigest()


def run(argv, **kwargs):
    return subprocess.run([str(a) for a in argv], check=True, **kwargs)


def safe_parent(path, mount):
    if not mount.is_mount() or mount.resolve() != mount:
        fail(f'Expected actual mountpoint: {mount}')
    if path != mount and mount not in path.parents:
        fail(f'Path not allowlisted: {path}')
    for parent in (path, *path.parents):
        if parent == mount:
            break
        if parent.is_symlink():
            fail(f'Symlink path forbidden: {parent}')
        if parent.exists() and parent.stat().st_uid != os.getuid():
            fail(f'Foreign-owned path forbidden: {parent}')
    # Reject nested bind mounts that would move state to another filesystem.
    actual = run(['findmnt', '-n', '-o', 'TARGET', '-T', path if path.exists() else path.parent],
                 capture_output=True, text=True).stdout.strip()
    if actual != str(mount):
        fail(f'Unexpected backing mount for {path}: {actual}')


def space_guard():
    for mount in (Path('/'), DATA_MOUNT, SSD_MOUNT):
        usage = shutil.disk_usage(mount)
        if usage.free / usage.total < .15:
            fail(f'Free space below 15%: {mount}')
    used, counted = 0, set()
    for root in (DATA, VM):
        if root.exists():
            for path in root.rglob('*'):
                if path.is_symlink():
                    if DATA / 'research' in path.parents:
                        # A read-only upstream Git checkout may contain symlinks;
                        # no build input or mutable target is resolved through it.
                        continue
                    fail(f'Unexpected symlink in runtime: {path}')
                if path.is_file():
                    identity = path.stat()
                    key = (identity.st_dev, identity.st_ino)
                    if key not in counted:
                        counted.add(key)
                        used += identity.st_blocks * 512
    if used > 300_000_000_000:
        fail('Project 300 GB allocated-byte budget exceeded')
    return used


def initialize_dirs():
    if os.geteuid() == 0:
        fail('Host root execution forbidden')
    for path, mount in ((DATA, DATA_MOUNT), (VM, SSD_MOUNT)):
        safe_parent(path, mount)
        path.mkdir(mode=0o700, exist_ok=True)
        if path.stat().st_mode & 0o077:
            fail(f'Private runtime directory mode required: {path}')
    for path in (CACHE, LOGS, ARTIFACTS, STATE):
        safe_parent(path, DATA_MOUNT)
        path.mkdir(mode=0o700, exist_ok=True)
    space_guard()


def fetch(url, dest, expected, algorithm='sha256', local=None):
    if dest.exists():
        if sha(dest, algorithm) != expected:
            fail(f'Cached SHA mismatch: {dest.name}; preserve and investigate')
        return
    temporary = dest.with_suffix(dest.suffix + '.partial')
    if temporary.exists():
        fail(f'Partial download exists: {temporary}; preserve for review')
    space_guard()
    if local is not None and local.is_file() and not local.is_symlink():
        with local.open('rb') as source, temporary.open('xb') as output:
            shutil.copyfileobj(source, output)
    else:
        if not url.startswith('https://'):
            # LFS lists HTTP/FTP endpoints; only reuse verified local bytes for those.
            fail(f'Uncached non-HTTPS source forbidden: {dest.name}')
        with urllib.request.urlopen(url, timeout=90) as source, temporary.open('xb') as output:
            if not source.url.startswith('https://'):
                fail('Non-HTTPS redirect forbidden')
            while block := source.read(1024 * 1024):
                output.write(block)
                space = shutil.disk_usage(dest.parent)
                if space.free / space.total < .15:
                    fail('Download stopped at 15% free-space gate')
    if sha(temporary, algorithm) != expected:
        fail(f'Source checksum mismatch: {dest.name}; do not retry or patch recipe')
    temporary.rename(dest)


def prepare():
    m = manifest()
    for item in m['sources']:
        fetch(item['url'], CACHE / item['filename'], item['sha256'],
              local=Path('/mnt/alpbahOS-ssd/alpbahos-builds/active/lfs-source-cache') / item['filename'])
        if item.get('signature'):
            sig = item['signature']
            fetch(sig['url'], CACHE / sig['filename'], sig['sha256'])
    for tool in m.get('builder_tools', []):
        fetch(tool['url'], CACHE / tool['filename'], tool['sha256'])
    for key in m.get('trust_keys', []):
        if key['url'].startswith('https://'):
            fetch(key['url'], CACHE / key['filename'], key['sha256'])
        elif not (CACHE / key['filename']).exists():
            fail('Frozen WKD export missing; preserve the public key cache bundle')
    image = m['builder']
    fetch(image['url'], CACHE / image['filename'], image['sha512'], 'sha512')
    image['sha256'] = sha(CACHE / image['filename'])
    (REPO / 'manifests/infra-sources.json').write_text(json.dumps(m, indent=2, sort_keys=True) + '\n')
    alp = run(['git', '-C', REPO, 'show',
               m['alp']['git_commit'] + ':' + m['alp']['path']], capture_output=True).stdout
    if hashlib.sha256(alp).hexdigest() != m['alp']['sha256']:
        fail('Pinned Alp Git object mismatch; never fall back to moving working copy')
    (STATE / 'alp.py').write_bytes(alp)
    key = STATE / 'builder_ed25519'
    if not key.exists():
        run(['ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-C', 'alp-infra-builder', '-f', key])
    public = key.with_suffix('.pub').read_text().strip()
    seed_dir = STATE / 'seed'
    seed_dir.mkdir(mode=0o700, exist_ok=True)
    (seed_dir / 'meta-data').write_text('instance-id: alp-infra-v1\nlocal-hostname: alp-builder-local\n')
    # Public key only; passwords disabled and no host credentials enter the VM.
    (seed_dir / 'user-data').write_text('#cloud-config\ndisable_root: false\nssh_pwauth: false\n'
        'users:\n  - name: root\n    lock_passwd: true\n    ssh_authorized_keys:\n      - ' + public + '\n')
    seed = VM / 'seed.iso'
    if not seed.exists():
        run(['genisoimage', '-quiet', '-output', seed, '-volid', 'cidata',
             '-joliet', '-rock', seed_dir / 'user-data', seed_dir / 'meta-data'])
    base = VM / 'builder-base.qcow2'
    if not base.exists():
        run(['qemu-img', 'convert', '-O', 'qcow2', CACHE / image['filename'], base])
        run(['qemu-img', 'resize', base, '12G'])
    for name, size in (('builder-active.qcow2', None), ('lfs-active.qcow2', '40G')):
        path = VM / name
        if not path.exists():
            args = ['qemu-img', 'create', '-f', 'qcow2']
            args += ['-F', 'qcow2', '-b', str(base), str(path)] if size is None else [str(path), size]
            run(args)
    verify_cache()
    print('Prepared private VM disks and verified sources; no build was run.')


def verify_cache():
    m = manifest()
    for item in m['sources']:
        if sha(CACHE / item['filename']) != item['sha256']:
            fail(f'SHA256 mismatch: {item["filename"]}')
        if item.get('signature') and sha(CACHE / item['signature']['filename']) != item['signature']['sha256']:
            fail(f'Signature SHA256 mismatch: {item["filename"]}')
    if not m['builder']['sha256'] or sha(CACHE / m['builder']['filename']) != m['builder']['sha256']:
        fail('Builder image SHA256 missing/mismatched')
    for tool in m.get('builder_tools', []):
        if sha(CACHE / tool['filename']) != tool['sha256']:
            fail('Builder tool hash mismatch: ' + tool['filename'])
    for key in m.get('trust_keys', []):
        if sha(CACHE / key['filename']) != key['sha256']:
            fail('Public keyring hash mismatch')
    print(f'cache SHA256 OK: {len(m["sources"])} downloaded + {len(m.get("local_sources", []))} pinned repository sources + builder')


def verify_signatures():
    run(['python3', REPO / 'scripts/infra/verify-signatures.py'])


def pid():
    file = STATE / 'qemu.pid'
    if not file.exists():
        return None
    value = int(file.read_text().strip())
    try:
        args = Path(f'/proc/{value}/cmdline').read_bytes().split(b'\0')
    except FileNotFoundError:
        return None
    if str(VM / 'builder-active.qcow2').encode() not in b' '.join(args):
        fail('PID file does not identify our QEMU; refusing to signal unrelated process')
    return value


def launch(offline=False, vcpus=8):
    if pid():
        fail('Builder is already running')
    checkpoint_store.unfinished(VM)
    verify_cache()
    if not os.access('/dev/kvm', os.R_OK | os.W_OK):
        fail('KVM access unavailable; do not fall back to slow emulation')
    with socket.socket() as check:
        check.bind(('127.0.0.1', PORT))
    available = int(next(line.split()[1] for line in Path('/proc/meminfo').read_text().splitlines()
                         if line.startswith('MemAvailable:'))) * 1024
    memory = min(12 * 1024, (available - 4 * 1024**3) // (1024**2))
    if memory < 8192:
        fail('Need 8 GiB guest RAM plus 4 GiB host reserve')
    network = f'user,id=net0,hostfwd=tcp:127.0.0.1:{PORT}-:22'
    if offline:
        network += ',restrict=on'
    args = ['qemu-system-x86_64', '-name', 'alp-infra-builder', '-accel', 'kvm',
            '-cpu', 'host', '-smp', str(vcpus), '-m', str(memory), '-display', 'none',
            '-nodefaults', '-no-reboot', '-device', 'VGA', '-device', 'virtio-rng-pci',
            '-drive', f'file={VM}/builder-active.qcow2,if=none,id=osdisk,format=qcow2,cache=none',
            '-device', 'virtio-blk-pci,drive=osdisk,bootindex=1,serial=ALP_BUILDER_V1',
            '-drive', f'file={VM}/lfs-active.qcow2,if=none,id=lfsdisk,format=qcow2,cache=none',
            '-device', 'virtio-blk-pci,drive=lfsdisk,serial=ALP_LFS_V1',
            '-drive', f'file={VM}/seed.iso,media=cdrom,readonly=on',
            '-netdev', network, '-device', 'virtio-net-pci,netdev=net0',
            '-serial', f'file:{LOGS}/serial.log', '-monitor', 'none',
            '-qmp', f'unix:{STATE}/qmp.sock,server=on,wait=off',
            '-pidfile', str(STATE / 'qemu.pid'), '-daemonize']
    run(args)
    for attempt in range(60):
        if not pid():
            fail('QEMU exited during boot; see serial.log')
        result = subprocess.run(ssh_args() + ['true'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if result.returncode == 0:
            (STATE / 'network.json').write_text(json.dumps({'offline': offline, 'memory_mib': memory, 'vcpus': vcpus}) + '\n')
            print(f'KVM SSH ready: guest RAM={memory} MiB vCPU={vcpus} offline={offline}')
            return
        time.sleep(2)
    fail('Guest SSH did not become ready; see serial.log')


def ssh_args():
    return ['ssh', '-T', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=3',
            '-o', 'StrictHostKeyChecking=accept-new', '-o', f'UserKnownHostsFile={STATE}/known_hosts',
            '-i', str(STATE / 'builder_ed25519'), '-p', str(PORT), 'root@127.0.0.1']


def sync():
    if not pid():
        fail('Builder must be running')
    run(ssh_args() + ['mkdir -p /opt/alp-infra/scripts/infra /opt/alp-infra/manifests /opt/alp-infra/runtime /opt/alp-infra/recipes/smoke /opt/alp-infra/recipes/bootstrap /opt/alp-infra/recipes/toolchain'])
    transport = ' '.join(ssh_args()[:-1])
    captured_inputs = inputs_digest()
    # Never copy the main dirty tree or an SSH private key to the guest.
    for source, dest in ((str(REPO / 'scripts/infra') + '/', '/opt/alp-infra/scripts/infra/'),
                         (REPO / 'scripts/capture-package-manifest.py', '/opt/alp-infra/scripts/'),
                         (REPO / 'scripts/compare-package-manifest.py', '/opt/alp-infra/scripts/'),
                         (REPO / 'manifests/infra-sources.json', '/opt/alp-infra/manifests/'),
                         (REPO / 'recipes/smoke/zlib.json', '/opt/alp-infra/recipes/smoke/'),
                         (REPO / 'recipes/bootstrap/binutils-sbu.json', '/opt/alp-infra/recipes/bootstrap/'),
                         (str(REPO / 'recipes/toolchain') + '/', '/opt/alp-infra/recipes/toolchain/'),
                         (REPO / 'manifests/infra-test-policy.json', '/opt/alp-infra/manifests/'),
                         (STATE / 'alp.py', '/opt/alp-infra/runtime/')):
        run(['rsync', '-rt', '-e', transport, str(source), f'root@127.0.0.1:{dest}'])
    if inputs_digest() != captured_inputs:
        fail('Inputs changed while syncing; do not execute partially updated guest')
    receipt = {'inputs_sha256': captured_inputs, 'sources_sha256': sha(REPO / 'manifests/infra-sources.json')}
    run(ssh_args() + ['cat > /srv/infra/inputs.json'], input=(json.dumps(receipt) + '\n').encode())


def verify_smoke_report(summary, evidence):
    m = manifest()
    expected = {'inputs_sha256': inputs_digest(), 'source_date_epoch': m['source_date_epoch'],
                'alp_sha256': m['alp']['sha256']}
    if summary.get('result') != 'PASS' or summary.get('db_repeatable') is not True or evidence.get('equal') is not True:
        fail('Phase 1 DB/package reproducibility acceptance missing or failed')
    if (summary.get('alp_reproducible_build_mode') is not True
            or evidence.get('alp_reproducible_build_mode') is not True):
        fail('Phase 1 Alp explicit reproducible-build mode evidence missing')
    for field, value in expected.items():
        if summary.get(field) != value or evidence.get(field) != value:
            fail('Phase 1 acceptance uses different inputs: ' + field)
    for key in ('archive_sha256', 'manifest_sha256', 'db_sha256'):
        values = summary.get(key, [])
        if len(values) != 2 or values[0] != values[1] or not re.fullmatch('[0-9a-f]{64}', values[0]):
            fail('Phase 1 unequal/invalid hashes: ' + key)
    if [row.get('db_sha256') for row in evidence.get('records', [])] != summary['db_sha256']:
        fail('Phase 1 DB evidence/report disagree')
    if summary.get('install_remove_restore') != 'PASS':
        fail('Phase 1 package lifecycle failed')


def record_phase1_acceptance():
    root = ARTIFACTS / 'zlib-smoke'
    summary_path, evidence_path = root / 'summary.json', root / 'db-repro-evidence.json'
    verify_smoke_report(json.loads(summary_path.read_text()), json.loads(evidence_path.read_text()))
    receipt = {'inputs_sha256': inputs_digest(), 'summary_sha256': sha(summary_path),
               'db_evidence_sha256': sha(evidence_path), 'captured_at_ns': time.time_ns()}
    (ARTIFACTS / 'phase1-acceptance.json').write_text(json.dumps(receipt, indent=2) + '\n')


def phase1_acceptance_guard():
    path = ARTIFACTS / 'phase1-acceptance.json'
    if not path.is_file() or path.is_symlink():
        fail('Phase 1 acceptance absent; resolve Alp DB reproducibility before Phase 2')
    receipt = json.loads(path.read_text())
    root = ARTIFACTS / 'zlib-smoke'
    summary_path, evidence_path = root / 'summary.json', root / 'db-repro-evidence.json'
    if (receipt.get('inputs_sha256') != inputs_digest() or receipt.get('summary_sha256') != sha(summary_path)
            or receipt.get('db_evidence_sha256') != sha(evidence_path)):
        fail('Phase 1 acceptance inputs/artifact bytes changed')
    verify_smoke_report(json.loads(summary_path.read_text()), json.loads(evidence_path.read_text()))


def guest(action):
    if not pid():
        fail('Builder must be running')
    if action == 'smoke':
        ensure_builder_python()
        remote = 'bash /opt/alp-infra/scripts/infra/guest-package.sh zlib-smoke'
        previous = ARTIFACTS / 'phase1-acceptance.json'
        if previous.exists():
            previous.rename(ARTIFACTS / f'phase1-acceptance-before-{time.time_ns()}.json')
    elif action != 'provision':
        fail('Guest action not allowlisted')
    log = LOGS / f'{action}-{time.time_ns()}.log'
    with log.open('wb') as output:
        if action == 'provision':
            # A fresh cloud image may not have rsync. Transfer the reviewed
            # local provisioning script over SSH stdin before synchronizing.
            run(ssh_args() + ['bash -s'],
                input=(REPO / 'scripts/infra/guest-provision.sh').read_bytes(),
                stdout=output, stderr=subprocess.STDOUT)
            sync()
        else:
            sync()
            try:
                run(ssh_args() + [remote], stdout=output, stderr=subprocess.STDOUT)
            finally:
                transport = ' '.join(ssh_args()[:-1])
                # Preserve failed DB/hash evidence too. A stale PASS cannot
                # authorize Phase 2: acceptance binds current byte hashes.
                collected = subprocess.run(['rsync', '-rt', '-e', transport,
                    'root@127.0.0.1:/srv/lfs/results/zlib-smoke/', str(ARTIFACTS / 'zlib-smoke') + '/'])
                if collected.returncode:
                    print('Artifact collection failed; guest disks/log preserved', file=sys.stderr)
            if collected.returncode:
                fail('Smoke evidence collection failed; no new Phase 1 acceptance')
    if action == 'provision':
        transport = ' '.join(ssh_args()[:-1])
        run(['rsync', '-rt', '-e', transport, 'root@127.0.0.1:/srv/infra/builder-packages.tsv', str(ARTIFACTS)])
        run(ssh_args() + ['mkdir -p /srv/lfs/sources'])
        for item in manifest()['sources']:
            run(['rsync', '-rt', '-e', transport, CACHE / item['filename'], 'root@127.0.0.1:/srv/lfs/sources/'])
    else:
        record_phase1_acceptance()
    print(f'{action} finished; log={log} sha256={sha(log)}')


def ensure_builder_python():
    """Install the pinned Builder-only Python runtime before package smoke tests."""
    check = 'test -x /opt/alp-builder-python/bin/python3 && sha256sum -c /srv/infra/builder-python.sha256'
    result = subprocess.run(ssh_args() + [check], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True)
    if result.returncode:
        builder_python()
        result = subprocess.run(ssh_args() + [check], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True)
    if result.returncode:
        fail('Pinned Builder Python runtime is not installed and verified: ' + result.stdout[-2000:])


def builder_python():
    sync()
    tool = manifest()['builder_tools'][0]
    if tool['id'] != 'builder-cpython-3.13.7':
        fail('Unexpected builder runtime')
    if sha(CACHE / tool['filename']) != tool['sha256']:
        fail('Builder runtime hash mismatch')
    transport = ' '.join(ssh_args()[:-1])
    run(['rsync', '-rt', '-e', transport, CACHE / tool['filename'], 'root@127.0.0.1:/srv/infra/'])
    log = LOGS / f'builder-python-{time.time_ns()}.log'
    with log.open('wb') as output:
        run(ssh_args() + ['bash /opt/alp-infra/scripts/infra/guest-builder-python.sh'],
            stdout=output, stderr=subprocess.STDOUT)
    print(f'Builder Python installed; log={log} sha256={sha(log)}')


def restore(name):
    if pid():
        fail('Restore requires a powered-off Builder')
    if name not in CHECKPOINTS:
        fail('Restore name not allowlisted')
    checkpoint_store.unfinished(VM)
    saved_dir = VM / f'checkpoint-{name}'
    safe_parent(saved_dir, SSD_MOUNT)
    record = json.loads((saved_dir / 'checkpoint.json').read_text())
    for disk in ('builder', 'lfs'):
        path = saved_dir / f'{disk}.qcow2'
        if record[disk]['path'] != str(path) or sha(path) != record[disk]['sha256']:
            fail('Checkpoint disk path/hash mismatch')
    if name not in ('prepared', 'builder-ready') and record['inputs_sha256'] != inputs_digest():
        fail('Checkpoint inputs changed; rebuild from prepared, never reuse completed outputs')
    failed = VM / f'preserved-overlays-{time.time_ns()}'
    failed.mkdir(mode=0o700)
    for disk in ('builder', 'lfs'):
        active = VM / f'{disk}-active.qcow2'
        active.rename(failed / active.name)
        run(['qemu-img', 'create', '-f', 'qcow2', '-F', 'qcow2', '-b', saved_dir / f'{disk}.qcow2', active])
    print(f'Restored checkpoint {name}; previous overlays preserved at {failed}')


def stop():
    current = pid()
    if current is None:
        print('Builder stopped')
        return
    try:
        subprocess.run(ssh_args() + ['systemctl poweroff'], stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, timeout=15)
    except subprocess.TimeoutExpired:
        print('Poweroff SSH timed out; checking actual QEMU process', file=sys.stderr)
    for attempt in range(60):
        if pid() is None:
            print('Builder powered off; qcow2 writers closed')
            return
        time.sleep(1)
    fail('Guest did not power off cleanly; preserve disks, do not snapshot live')


def checkpoint(name, run_id=None, after_audit_id=None):
    if pid():
        fail('Checkpoint requires a powered-off Builder')
    if name not in CHECKPOINTS:
        fail('Checkpoint name not allowlisted')
    if name in STAGES and (name not in ('stability', 'toolchain') or not run_id or not after_audit_id):
        fail('Product stage checkpoint needs verified guest artifacts, current privileged post-stage host audit and acceptance producer; not integrated yet')
    acceptance = None
    if name == 'stability':
        proof = stability_proof(run_id, after_audit_id)
        _, receipt = stage_runs.read(stage_runs.RUNS / run_id / 'acceptance.json')
        if receipt.get('evidence') != proof:
            fail('Stability receipt differs from revalidated current raw evidence')
        acceptance = proof
    if name == 'toolchain':
        proof = toolchain_proof(run_id, after_audit_id)
        _, receipt = stage_runs.read(stage_runs.RUNS / run_id / 'acceptance.json')
        if receipt.get('evidence') != proof:
            fail('Toolchain receipt differs from revalidated current raw evidence')
        acceptance = proof
    if name == 'smoke':
        phase1_acceptance_guard()
        acceptance = {'phase1_acceptance_sha256': sha(ARTIFACTS / 'phase1-acceptance.json')}
    def stopped():
        if pid():
            fail('Checkpoint transaction observed a live Builder; STOP')
    checkpoint_dir = checkpoint_store.create(VM, name, inputs_digest(),
        sha(REPO / 'manifests/infra-sources.json'), acceptance, stopped, space_guard)
    print(f'checkpoint={checkpoint_dir} input_sha256={inputs_digest()}')
    return checkpoint_dir


def monitor():
    record = sample()
    record['pid'] = pid()
    print(json.dumps(record, sort_keys=True), flush=True)
    if record['errors']:
        fail('Host telemetry coverage/fault failed; inspect preceding JSON')


def verify_base_inventory():
    plan = base_plan.load(REPO)
    with_recipes = sum(row['recipe'] != 'pending' for row in plan)
    print(json.dumps({'schema': 'alpbahOS.lfs-base-inventory-verification/v1',
                      'result': ('INVENTORY_VERIFIED_RECIPE_COVERAGE_INCOMPLETE'
                                 if with_recipes < len(plan) else 'INVENTORY_AND_RECIPE_COVERAGE_VERIFIED'),
                      'package_count': len(plan), 'packages_with_recipes': with_recipes,
                      'packages_pending_recipes': len(plan) - with_recipes,
                      'sources_sha256': sha(REPO / 'manifests/infra-sources.json'),
                      'scope': 'ordered identities, source pins and declared recipe binding only; no build or ownership acceptance'},
                     sort_keys=True))


def stability_run(context):
    """Collect failed evidence and close guest writers before any acceptance."""
    value, run_sha256 = context
    stage_runs.execution_guard(value, run_sha256)
    root = stage_runs.ARTIFACTS / value['run_id']
    stage_runs.private(root)
    if (root / 'stability.log').exists() or (root / 'guest').exists():
        fail('Existing stability run artifacts preserved; no repeat execution')
    guest_root = stage_runs.directory(root, 'guest')
    log = root / 'stability.log'
    telemetry_path = log.with_suffix('.host.jsonl')
    errors = []
    verified = None
    binding = {key: value[key] for key in ('run_id', 'stage', 'inputs_sha256', 'sources_sha256', 'boot_id')}
    try:
        with log.open('xb') as output, telemetry_path.open('x') as telemetry:
            command = run_monitored(stability_command(),
                          output, telemetry, space_guard, binding=binding)
            stage_runs.write(root / 'command.json', command)
    except BaseException as error:
        errors.append(error)
    finally:
        transport = ' '.join(ssh_args()[:-1])
        # Even on failure, retain build/test/DB logs before guest shutdown.
        try:
            run(['rsync', '-rt', '-e', transport, 'root@127.0.0.1:/srv/lfs/results/stability/',
                 str(guest_root) + '/'], timeout=30)
        except BaseException as error:
            errors.append(error)
        if not errors:
            try:
                recipes = {key: json.loads((REPO / path).read_text()) for key, path in (
                    ('sbu', 'recipes/bootstrap/binutils-sbu.json'), ('zlib', 'recipes/smoke/zlib.json'))}
                recipes['zlib']['phase'] = 'stability'
                summary = json.loads((guest_root / 'summary.json').read_text())
                if summary.get('run_id') != value['run_id']:
                    fail('Guest stability result belongs to another run')
                verified = verify_stability_artifacts(guest_root, manifest(), inputs_digest(),
                    sha(REPO / 'manifests/infra-sources.json'), recipes)
            except BaseException as error:
                errors.append(error)
        try:
            stop()
            stage_runs.repository_snapshot(value, 'after')
        except BaseException as error:
            errors.append(error)
        def stopped():
            if pid():
                fail('Stability outcome requires closed VM writers')
        if not errors:
            try:
                chains = checkpoint_store.inspect_disks(VM, stopped, space_guard)
                stage_runs.write(root / 'disks-closed.json', {'run_id': value['run_id'], 'time_ns': time.time_ns(), 'chains': chains})
            except BaseException as error:
                errors.append(error)
        record = stage_runs.finish(value, run_sha256, errors, verified, stopped)
    if record['result'] == 'FAIL':
        fail('Stability failed; disks/evidence preserved, no checkpoint: ' + repr(errors))
    return record


def stage_request(name, mode, parent_run_id=None, parent_audit_id=None):
    if name not in ('stability', 'toolchain') or mode != manifest().get('abi_selection', {}).get('mode'):
        fail('Only the selected stability/toolchain stage request is implemented')
    if pid():
        fail('Stage audit preparation requires a stopped Builder')
    phase1_acceptance_guard()
    if name == 'toolchain':
        if parent_run_id is None or parent_audit_id is None:
            fail('Toolchain request needs accepted stability parent run/audit identities')
        parent, checksum, recipes = stability_context(parent_run_id)
        value = stage_runs.prepare_toolchain(mode, inputs_digest(), sha(REPO / 'manifests/infra-sources.json'),
            sha(ARTIFACTS / 'phase1-acceptance.json'), parent, checksum, parent_audit_id,
            manifest(), recipes, VM, stability_command(), stopped_stability_writer, space_guard)
    else:
        if parent_run_id is not None or parent_audit_id is not None:
            fail('Stability preparation cannot use toolchain parent flags')
        value = stage_runs.prepare(name, mode, inputs_digest(), sha(REPO / 'manifests/infra-sources.json'),
                                   sha(ARTIFACTS / 'phase1-acceptance.json'))
    print(json.dumps(value, sort_keys=True))


def current_stage_run(run_id, mode, *, stage='stability'):
    phase1_acceptance_guard()
    return stage_runs.load(run_id, mode, inputs_digest(), sha(REPO / 'manifests/infra-sources.json'),
                           sha(ARTIFACTS / 'phase1-acceptance.json'), stage=stage)


def stability_command():
    return ssh_args() + ['timeout --signal=TERM --kill-after=15s 30m bash /opt/alp-infra/scripts/infra/guest-stability.sh']


def stability_context(run_id):
    mode = manifest()['abi_selection']['mode']
    value, checksum, _ = current_stage_run(run_id, mode)
    recipes = {key: json.loads((REPO / path).read_text()) for key, path in (
        ('sbu', 'recipes/bootstrap/binutils-sbu.json'), ('zlib', 'recipes/smoke/zlib.json'))}
    recipes['zlib']['phase'] = 'stability'
    return value, checksum, recipes


def stopped_stability_writer():
    if pid(): fail('Stability acceptance requires closed VM writers')


def stability_proof(run_id, after_audit_id, *, checkpointed=False):
    value, checksum, recipes = stability_context(run_id)
    return stage_acceptance.verify(value, checksum, after_audit_id, manifest(), recipes,
                                    VM, stability_command(), stopped_stability_writer, space_guard,
                                    checkpointed=checkpointed)


def toolchain_proof(run_id, after_audit_id):
    mode = manifest()['abi_selection']['mode']
    value, checksum, _ = current_stage_run(run_id, mode, stage='toolchain')
    return toolchain_acceptance.verify(value, checksum, after_audit_id, manifest(), {},
        VM, toolchain_command(), stopped_stability_writer, space_guard)


def toolchain_parent(run_id, after_audit_id, toolchain_run_id):
    """Pre-launch library gate; no stage execution/OC authorization is issued."""
    value, checksum, recipes = stability_context(run_id)
    return toolchain_handoff.prepare(value, checksum, after_audit_id, manifest(), recipes,
                                    VM, stability_command(), stopped_stability_writer, space_guard, toolchain_run_id)


def toolchain_command():
    return ssh_args() + ['bash /opt/alp-infra/scripts/infra/guest-toolchain.sh']


def collect_toolchain_guest(run_id, destination):
    """Copy the whole fixed guest result tree without exclusions/following links."""
    stage_runs.identity(run_id)
    if destination.resolve() != destination or destination.is_symlink() or not destination.is_dir():
        fail('Toolchain evidence destination must be a new resolved directory')
    transport = shlex.join(ssh_args()[:-1])
    source = f'root@127.0.0.1:/srv/lfs/results/toolchain/{run_id}/'
    argv = ['rsync', '-rt', '-e', transport, source, str(destination) + '/']
    started, started_mono = time.time_ns(), time.monotonic_ns()
    result = subprocess.run(argv, capture_output=True, text=True)
    ended, ended_mono = time.time_ns(), time.monotonic_ns()
    stage_runs.write(destination.parent / 'guest-transfer.json', {
        'argv': argv, 'exit': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr,
        'started_at_ns': started, 'ended_at_ns': ended,
        'started_monotonic_ns': started_mono, 'ended_monotonic_ns': ended_mono})
    if result.returncode:
        raise subprocess.CalledProcessError(result.returncode, argv, result.stdout, result.stderr)
    return destination


def toolchain_guest_boot_id(context):
    """Return the measured boot identity pinned in the authorized handoff."""
    authorization = context.get('authorization')
    guest_boot_id = authorization.get('guest_boot_id') if isinstance(authorization, dict) else None
    if not isinstance(guest_boot_id, str) or not re.fullmatch(
            r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', guest_boot_id):
        fail('Toolchain guest boot identity missing from measured handoff authorization')
    return guest_boot_id


def expected_toolchain_guest_evidence(value, authorization):
    """Bind verified guest bytes to the measured boot identity in authorization."""
    return {'schema': 'alpbahOS.toolchain-guest-evidence/v1', 'result': 'VERIFIED_GUEST_BYTES',
            'inputs_sha256': value['inputs_sha256'], 'sources_sha256': value['sources_sha256'],
            'run_id': value['run_id'], 'guest_boot_id': authorization['guest_boot_id'],
            'handoff_sha256': authorization['handoff_sha256']}


def execute_toolchain_guest(context):
    """Run the fixed Builder command; collect and revalidate all guest bytes."""
    value, run_sha256 = context['value'], context['run_sha256']
    stage_runs.execution_guard(value, run_sha256)
    root = stage_runs.ARTIFACTS / value['run_id']
    stage_runs.private(root)
    names = ('toolchain.log', 'toolchain.host.jsonl', 'toolchain-command.json',
             'toolchain-command-failure.json', 'guest-transfer.json', 'guest-artifact-proof.json',
             'guest-toolchain')
    if any((root / name).exists() or (root / name).is_symlink() for name in names):
        fail('Existing toolchain evidence preserved; this run cannot replay')
    log, telemetry_path = root / 'toolchain.log', root / 'toolchain.host.jsonl'
    binding = {key: value[key] for key in ('run_id', 'stage', 'inputs_sha256', 'sources_sha256', 'boot_id')}
    with log.open('xb') as output, telemetry_path.open('x') as telemetry:
        try:
            command = run_monitored(toolchain_command(), output, telemetry, space_guard, binding=binding)
        except BaseException as error:
            stage_runs.write(root / 'toolchain-command-failure.json', {
                'schema': 'alpbahOS.toolchain-command-failure/v1', 'binding': binding,
                'argv': toolchain_command(), 'error': repr(error), 'time_ns': time.time_ns()})
            # Only an observed normal remote exit permits copying its partial
            # job for diagnosis. On a monitor fault, stop the VM first.
            if isinstance(error, subprocess.CalledProcessError):
                collect_toolchain_guest(value['run_id'], stage_runs.directory(root, 'guest-toolchain'))
            raise
    stage_runs.write(root / 'toolchain-command.json', command)
    stage_runs.execution_guard(value, run_sha256)
    guest = collect_toolchain_guest(value['run_id'], stage_runs.directory(root, 'guest-toolchain'))
    if inputs_digest() != value['inputs_sha256']:
        fail('Canonical inputs changed after guest toolchain execution; preserve evidence')
    capsule_raw = stage_runs.audit.read_file(root / 'handoff.json', os.getuid())
    auth_raw = stage_runs.audit.read_file(root / 'authorization.json', os.getuid())
    authorization = json.loads(auth_raw)
    proof = toolchain_evidence.verify(guest, REPO,
        {'inputs_sha256': value['inputs_sha256'], 'sources_sha256': value['sources_sha256']},
        capsule_raw, authorization, toolchain_guest_boot_id(context))
    expected = expected_toolchain_guest_evidence(value, authorization)
    if any(proof.get(key) != expected_value for key, expected_value in expected.items()):
        fail('Canonical toolchain verifier returned evidence for another run')
    stage_runs.write(root / 'guest-artifact-proof.json', proof)
    context['guest_artifact_evidence'] = proof
    return proof


@contextmanager
def toolchain_handoff_session(mode, oc_confirmed, run_id):
    """Root-before, single-use guest run, byte verification and root-after request."""
    if oc_confirmed is not True or mode != 'multilib-m32':
        fail('Toolchain session needs explicit OC-complete/start and selected ABI')
    value, run_sha256, before_raw = current_stage_run(run_id, mode, stage='toolchain')
    if pid(): fail('Toolchain session requires stopped Builder before preflight')
    pinned_parent = stage_runs.parent_guard(value)
    recomputed = toolchain_parent(value['parent']['run_id'], value['parent']['after_audit_id'], run_id)
    if recomputed != pinned_parent:
        fail('Toolchain accepted parent/disk bytes changed before launch; STOP')
    verify_cache(); verify_signatures()
    root = stage_runs.ARTIFACTS / run_id
    baseline = sample()
    if baseline['errors']: fail('Toolchain host baseline failed')
    validate_sample(baseline)
    if baseline['boot_id'] != value['boot_id']: fail('Toolchain baseline host boot changed')
    stage_runs.write(root / 'host-baseline.json', baseline)
    stage_runs.begin(value, run_sha256, before_raw)  # Actual root evidence, before launch/sync/transfer.
    context = {'value': value, 'run_sha256': run_sha256, 'artifact_root': root}
    errors = []
    try:
        stage_runs.execution_guard(value, run_sha256)
        stage_runs.repository_snapshot(value, 'before')
        stage_runs.write_raw(root / 'parent.json', pinned_parent)
        launch(offline=True, vcpus=16)
        sync()
        if inputs_digest() != value['inputs_sha256']:
            fail('Toolchain inputs changed across launch/sync; no handoff')
        stage_runs.execution_guard(value, run_sha256)
        started = time.time_ns()
        query = run(ssh_args() + ['cat /proc/sys/kernel/random/boot_id'], capture_output=True, text=True, timeout=15)
        stage_runs.write(root / 'boot-query.json', {'started_at_ns': started, 'ended_at_ns': time.time_ns(),
            'argv': query.args, 'exit': query.returncode, 'stdout': query.stdout, 'stderr': query.stderr})
        if query.returncode or query.stderr or len(query.stdout) > 128:
            fail('Toolchain actual guest boot query failed/ambiguous')
        guest_boot = query.stdout.strip()
        capsule_raw = toolchain_handoff.bind_guest(pinned_parent, value['parent']['sha256'], run_id, guest_boot)
        authorization = {k: value[k] for k in ('mode', 'run_id', 'inputs_sha256', 'sources_sha256', 'boot_id')}
        authorization.update(stage='toolchain', oc_confirmed=True, guest_boot_id=guest_boot,
            handoff_sha256=stage_runs.audit.digest(capsule_raw), authorized_at_ns=time.time_ns())
        handoff_binding.validate(capsule_raw, authorization, value, guest_boot)
        auth_raw = (json.dumps(authorization, sort_keys=True, indent=2) + '\n').encode()
        stage_runs.write_raw(root / 'authorization.json', auth_raw)
        stage_runs.write_raw(root / 'handoff.json', capsule_raw)
        payload = (json.dumps({'capsule': capsule_raw.decode(), 'authorization': authorization}, sort_keys=True) + '\n').encode()
        reply = run(ssh_args() + ['bash /opt/alp-infra/scripts/infra/guest-handoff.sh'],
                    input=payload, capture_output=True, timeout=30)
        stage_runs.write_raw(root / 'handoff-response.raw', reply.stdout)
        if reply.returncode or reply.stderr or len(reply.stdout) > 65536:
            fail('Toolchain guest handoff transport failed/ambiguous')
        response = json.loads(reply.stdout)
        expected = {'schema': 'alpbahOS.guest-handoff-response/v1', 'result': 'HANDOFF_BOUND',
            'run_id': run_id, 'parent_run_id': value['parent']['run_id'], 'guest_boot_id': guest_boot,
            'host_boot_id': value['boot_id'], 'inputs_sha256': value['inputs_sha256'],
            'sources_sha256': value['sources_sha256'], 'handoff_sha256': stage_runs.audit.digest(capsule_raw),
            'authorization_sha256': stage_runs.audit.digest(auth_raw)}
        if response != expected: fail('Toolchain guest response differs from exact current handoff')
        stage_runs.write(root / 'handoff-response.json', response)
        stage_runs.execution_guard(value, run_sha256)
        context.update(response=response, authorization=authorization)
        yield context
        proof = context.get('guest_artifact_evidence')
        if (not isinstance(proof, dict) or proof.get('result') != 'VERIFIED_GUEST_BYTES'
                or proof.get('run_id') != run_id or proof.get('guest_boot_id') != guest_boot):
            fail('Toolchain guest execution/artifact verification absent')
    except BaseException as error:
        errors.append(error)
        raise
    finally:
        try:
            stop()
            stage_runs.repository_snapshot(value, 'after')
        except BaseException as error:
            errors.append(error)
        proof = context.get('guest_artifact_evidence') if not errors else None
        context['outcome'] = stage_runs.finish(value, run_sha256, errors, proof, stopped_stability_writer)
    if errors:
        fail('Toolchain failed; preserve run and guest evidence; no automatic retry: ' + repr(errors))
    context['post_request'] = stage_runs.after_request(value, run_sha256)
    return context


def run_toolchain(mode, oc_confirmed, run_id):
    if oc_confirmed is not True or mode != 'multilib-m32':
        fail('Toolchain execution needs explicit OC-complete/start and selected m64+m32 ABI')
    phase1_acceptance_guard()
    if mode != manifest().get('abi_selection', {}).get('mode'):
        fail('Toolchain execution ABI differs from current source manifest')
    with toolchain_handoff_session(mode, True, run_id) as context:
        execute_toolchain_guest(context)
    print(json.dumps(context['post_request'], sort_keys=True))
    print('Guest toolchain evidence ready; privileged post audit, stage acceptance and checkpoint remain pending.')
    return context


def accept_stability(run_id, mode, after_audit_id):
    if mode != manifest()['abi_selection']['mode']:
        fail('Stability acceptance ABI differs from selected mode')
    proof = stability_proof(run_id, after_audit_id)
    receipt = {'evidence': proof, 'accepted_at_ns': time.time_ns()}
    # Never overwrite or trust an old generic PASS. A prior receipt may be
    # reused only after its entire proof is recomputed from current bytes.
    path = stage_runs.RUNS / run_id / 'acceptance.json'
    if path.exists():
        _, saved = stage_runs.read(path)
        if saved.get('evidence') != proof:
            fail('Previous stability acceptance differs; preserve evidence')
    else:
        stage_runs.write(path, receipt)
    checkpoint('stability', run_id, after_audit_id)
    print('Verified stability gate checkpoint created; other product stages remain separate.')


def accept_toolchain(run_id, mode, after_audit_id):
    if mode != manifest()['abi_selection']['mode'] or mode != 'multilib-m32':
        fail('Toolchain acceptance ABI differs from selected mode')
    proof = toolchain_proof(run_id, after_audit_id)
    receipt = {'evidence': proof, 'accepted_at_ns': time.time_ns()}
    path = stage_runs.RUNS / run_id / 'acceptance.json'
    if path.exists():
        _, saved = stage_runs.read(path)
        if saved.get('evidence') != proof:
            fail('Previous toolchain acceptance differs; preserve evidence')
    else:
        stage_runs.write(path, receipt)
    acceptance_path = ARTIFACTS / 'toolchain-acceptance.json'
    if acceptance_path.exists() or acceptance_path.is_symlink():
        fail('Existing toolchain acceptance artifact preserved; no overwrite')
    checkpoint('toolchain', run_id, after_audit_id)
    def stopped():
        if pid(): fail('Toolchain checkpoint inspection observed a live Builder; STOP')
    checkpoint_proof = checkpoint_store.inspect_accepted_checkpoint(
        VM, stopped, space_guard, name='toolchain')
    authority = {**proof, 'checkpoint_sha256': checkpoint_proof['checkpoint_sha256'],
                 'transaction_sha256': checkpoint_proof['transaction_sha256']}
    stage_runs.write(acceptance_path, authority)
    print('Verified toolchain gate checkpoint created; base package stage remains separate.')


def phase2(mode, oc_confirmed, run_id=None):
    if not oc_confirmed or mode not in ('x86_64', 'multilib-m32'):
        fail('Requires explicit OC-complete/start authorization and a 32-bit choice')
    phase1_acceptance_guard()
    selected = manifest().get('abi_selection', {}).get('mode')
    if selected is not None and selected != mode:
        fail('Phase 2 mode differs from the user-selected ABI')
    if run_id is None:
        fail('Phase 2 needs a prepared single-use stage run and current privileged before audit')
    value, run_sha256, before_raw = current_stage_run(run_id, mode)
    # This entrypoint starts the real stability gate. Product stage recipes
    # have their own acceptances; never pretend this gate builds the whole OS.
    if pid():
        fail('Stop the Phase 1 VM before starting the OC gate')
    verify_cache()
    verify_signatures()
    # Fail before starting a guest when host journal/CPU coverage is incomplete.
    baseline = sample()
    baseline_path = stage_runs.ARTIFACTS / run_id / 'host-baseline.json'
    with baseline_path.open('x') as output:
        output.write(json.dumps(baseline, indent=2, sort_keys=True) + '\n')
    if baseline['errors']:
        fail('Host monitor baseline failed; evidence=' + str(baseline_path))
    validate_sample(baseline)
    stage_runs.begin(value, run_sha256, before_raw)
    try:
        stage_runs.repository_snapshot(value, 'before')
        launch(offline=True, vcpus=16)
        sync()
        ensure_builder_python()
        authorization = {'stage': 'stability', 'mode': mode, 'oc_confirmed': True, 'inputs_sha256': inputs_digest(),
                         'run_id': run_id, 'sources_sha256': value['sources_sha256'],
                         'boot_id': value['boot_id'], 'authorized_at_ns': time.time_ns()}
        stage_runs.write(stage_runs.ARTIFACTS / run_id / 'authorization.json', authorization)
        run(ssh_args() + ['cat > /srv/infra/phase2-authorization.json'], input=(json.dumps(authorization) + '\n').encode())
        stability_run((value, run_sha256))
    except BaseException as stage_error:
        # Launch/sync/authorization errors also leave no live guest writer.
        try:
            stop()
        except (RuntimeError, OSError) as error:
            print('Guest shutdown failed; preserve disks: ' + str(error), file=sys.stderr)
        # Launch/sync failure occurs before stability_run can produce an outcome.
        if not (stage_runs.RUNS / run_id / 'outcome.json').exists():
            def stopped():
                if pid():
                    fail('Guest still live after failed stage setup')
            stage_runs.finish(value, run_sha256, [stage_error], None, stopped)
        raise
    print(json.dumps(stage_runs.after_request(value, run_sha256), sort_keys=True))
    print('Stability execution ended; privileged post audit and full stage acceptance/checkpoint remain pending.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('prepare', 'verify-cache', 'launch', 'provision', 'sync',
                                          'builder-python', 'smoke', 'stop', 'checkpoint', 'restore', 'monitor', 'verify-base-inventory', 'stage-request', 'stage-after-request', 'accept-stability', 'accept-toolchain', 'phase2', 'toolchain-run'))
    parser.add_argument('--offline', action='store_true')
    parser.add_argument('--name')
    parser.add_argument('--mode', choices=('x86_64', 'multilib-m32'))
    parser.add_argument('--oc-confirmed', action='store_true')
    parser.add_argument('--run-id')
    parser.add_argument('--audit-id')
    parser.add_argument('--parent-run-id')
    parser.add_argument('--parent-audit-id')
    args = parser.parse_args()
    initialize_dirs()
    if args.action == 'monitor':
        monitor()  # read-only sampling must remain usable while a writer runs
        return
    with (STATE / 'controller.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if args.action == 'prepare': prepare()
        elif args.action == 'verify-cache': verify_cache()
        elif args.action == 'launch': launch(args.offline)
        elif args.action in ('provision', 'smoke'): guest(args.action)
        elif args.action == 'builder-python': builder_python()
        elif args.action == 'sync': sync()
        elif args.action == 'stop': stop()
        elif args.action == 'checkpoint': checkpoint(args.name, args.run_id, args.audit_id)
        elif args.action == 'restore': restore(args.name)
        elif args.action == 'monitor': monitor()
        elif args.action == 'verify-base-inventory': verify_base_inventory()
        elif args.action == 'stage-request': stage_request(args.name, args.mode, args.parent_run_id, args.parent_audit_id)
        elif args.action == 'stage-after-request':
            value, run_sha256, _ = current_stage_run(args.run_id, args.mode, stage=args.name or 'stability')
            if pid(): fail('Post audit request requires stopped guest writers')
            print(json.dumps(stage_runs.after_request(value, run_sha256), sort_keys=True))
        elif args.action == 'accept-stability': accept_stability(args.run_id, args.mode, args.audit_id)
        elif args.action == 'accept-toolchain': accept_toolchain(args.run_id, args.mode, args.audit_id)
        elif args.action == 'phase2': phase2(args.mode, args.oc_confirmed, args.run_id)
        elif args.action == 'toolchain-run': run_toolchain(args.mode, args.oc_confirmed, args.run_id)


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, subprocess.CalledProcessError) as error:
        print(f'STOP: {error}', file=sys.stderr)
        sys.exit(1)
