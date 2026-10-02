"""Two-disk qcow2 checkpoint transaction for a stopped, locked Builder.

Caller owns the controller lock and must verify stage acceptance first.
Temporary hardlinks avoid copying large images; both overlays are prepared
before replacing either active path. No VM is launched here.
"""
import hashlib
import json
import os
import stat
import subprocess
import time
from pathlib import Path

DISKS = ('builder', 'lfs')


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def checked(path, vm):
    if path.resolve() != path or not path.is_file() or vm not in path.parents:
        raise RuntimeError('Checkpoint file is missing/aliased/outside private VM root')
    value = path.stat()
    if not stat.S_ISREG(value.st_mode) or value.st_uid != os.getuid() or value.st_dev != vm.stat().st_dev:
        raise RuntimeError('Checkpoint file owner/device/type mismatch')
    return value


def command(argv):
    return subprocess.run([str(a) for a in argv], check=True, capture_output=True, text=True)


def save(path, value):
    temporary = path.with_name(path.name + '.pending')
    with temporary.open('x') as stream:
        json.dump(value, stream, indent=2, sort_keys=True); stream.write('\n')
        stream.flush(); os.fsync(stream.fileno())
    temporary.replace(path)
    fd = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def unfinished(vm):
    for directory in vm.glob('checkpoint-*'):
        if directory.resolve() != directory or directory.is_symlink() or not directory.is_dir():
            raise RuntimeError('Unsafe checkpoint transaction directory')
        record = directory / 'transaction.json'
        if record.exists():
            checked(record, vm)
            if json.loads(record.read_text()).get('status') != 'COMPLETE':
                raise RuntimeError('Incomplete checkpoint transaction; do not launch/restore: ' + str(directory))
        if not (directory / 'checkpoint.json').is_file():
            raise RuntimeError('Incomplete checkpoint without commit record: ' + str(directory))
        checked(directory / 'checkpoint.json', vm)


def inspect_disks(vm, stopped, space_guard):
    """Read-only current two-disk chains; never inspect a live writer."""
    vm = Path(vm)
    if os.geteuid() == 0 or vm.resolve() != vm or vm.stat().st_uid != os.getuid() or vm.stat().st_mode & 0o077:
        raise RuntimeError('Disk inspection requires private unprivileged VM root')
    stopped(); space_guard(); unfinished(vm)
    chains = {}
    for disk in DISKS:
        stopped()
        active = vm / (disk + '-active.qcow2')
        if checked(active, vm).st_nlink != 1:
            raise RuntimeError('Active disk hardlink alias forbidden')
        rows = json.loads(command(['qemu-img', 'info', '--output=json', '--backing-chain', active]).stdout)
        if not rows or any(row.get('format') != 'qcow2' for row in rows):
            raise RuntimeError('Current disk backing format invalid')
        paths = [Path(row['filename']) for row in rows]
        if paths[0] != active or len(set(paths)) != len(paths):
            raise RuntimeError('Current disk chain path/identity invalid')
        captured = []
        for path in paths:
            before = checked(path, vm)
            checksum = sha(path)
            after = checked(path, vm)
            if (before.st_ino, before.st_size, before.st_mtime_ns, before.st_ctime_ns) != (after.st_ino, after.st_size, after.st_mtime_ns, after.st_ctime_ns):
                raise RuntimeError('Current disk changed during inspection')
            captured.append({'path': str(path), 'sha256': checksum})
        command(['qemu-img', 'check', active])
        chains[disk] = captured
    stopped(); space_guard()
    return chains


def inspect_accepted_checkpoint(vm, stopped, space_guard, name='stability'):
    """Revalidate relocated accepted stage bytes and their fresh children.

    Only the former active filename is relocated. Hashes and all ancestor
    filenames must stay exactly as captured by the closed stage.
    """
    vm = Path(vm)
    current = inspect_disks(vm, stopped, space_guard)
    if name not in ('stability', 'toolchain'):
        raise RuntimeError('Unsupported accepted checkpoint stage')
    directory = vm / ('checkpoint-' + name)
    if (directory.resolve() != directory or not directory.is_dir()
            or directory.stat().st_uid != os.getuid() or directory.stat().st_mode & 0o077):
        raise RuntimeError('Accepted checkpoint directory is not private/canonical')
    def read(name):
        path = directory / name
        value = checked(path, vm)
        if value.st_nlink != 1 or value.st_mode & 0o022:
            raise RuntimeError('Accepted checkpoint metadata alias/permissions invalid')
        raw = path.read_bytes()
        return raw, json.loads(raw)
    raw, record = read('checkpoint.json')
    transaction_raw, transaction = read('transaction.json')
    proof = record.get('acceptance')
    schema = {'stability': 'alpbahOS.stability-acceptance/v1',
              'toolchain': 'alpbahOS.toolchain-acceptance/v1'}[name]
    if (not isinstance(proof, dict) or proof.get('schema') != schema or proof.get('result') != 'PASS'
            or transaction.get('status') != 'COMPLETE'
            or transaction.get('name') != name or transaction.get('acceptance') != proof
            or any(transaction.get(k) != list(DISKS) for k in ('linked', 'created', 'committed'))
            or type(transaction.get('start_ns')) is not int or type(transaction.get('end_ns')) is not int
            or transaction['end_ns'] < transaction['start_ns']
            or any(record.get(k) != proof.get(k) or transaction.get(k) != proof.get(k)
                   for k in ('inputs_sha256', 'sources_sha256'))):
        raise RuntimeError('Complete accepted stability checkpoint binding missing')
    originals = proof.get('closed_disk_chains')
    if (not isinstance(originals, dict) or set(originals) != set(DISKS)
            or transaction.get('backing_chains') != originals
            or record.get('active_overlays') != transaction.get('active_overlays')
            or set(record.get('active_overlays', {})) != set(DISKS)):
        raise RuntimeError('Accepted checkpoint original/fresh disk pins missing')
    for disk in DISKS:
        stopped(); space_guard()
        saved = directory / (disk + '.qcow2')
        value = checked(saved, vm)
        if value.st_nlink != 1 or stat.S_IMODE(value.st_mode) != 0o400:
            raise RuntimeError('Accepted saved image must be immutable without aliases')
        original = originals[disk]
        active = str(vm / (disk + '-active.qcow2'))
        if not original or original[0].get('path') != active:
            raise RuntimeError('Accepted original active disk path invalid')
        expected = [{'path': str(saved), 'sha256': original[0]['sha256']}, *original[1:]]
        if (record.get(disk) != expected[0] or record.get('backing_chains', {}).get(disk) != expected
                or transaction.get('original_sha256', {}).get(disk) != original[0]['sha256']
                or current[disk][1:] != expected):
            raise RuntimeError('Accepted saved/backing disk bytes differ; STOP')
        # qemu-img inspected every actual ancestor above, not a claimed list.
        if record['active_overlays'][disk] != current[disk][0]:
            raise RuntimeError('Fresh active overlay changed since checkpoint; STOP')
        command(['qemu-img', 'check', saved])
    stopped(); space_guard()
    if read('checkpoint.json')[0] != raw or read('transaction.json')[0] != transaction_raw:
        raise RuntimeError('Accepted checkpoint metadata changed during inspection; STOP')
    return {'closed_disk_chains': originals, 'acceptance': proof,
            'checkpoint_sha256': hashlib.sha256(raw).hexdigest(),
            'transaction_sha256': hashlib.sha256(transaction_raw).hexdigest(),
            'active_overlays': record['active_overlays'], 'saved_disk_chains': record['backing_chains']}


def create(vm, name, inputs_sha256, sources_sha256, acceptance, stopped, space_guard):
    vm = Path(vm)
    if (os.geteuid() == 0 or vm.resolve() != vm or not vm.is_dir()
            or vm.stat().st_uid != os.getuid() or vm.stat().st_mode & 0o077):
        raise RuntimeError('Checkpoint requires unprivileged private VM root')
    if not name or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789-' for c in name):
        raise RuntimeError('Unsafe checkpoint name')
    stopped(); space_guard(); unfinished(vm)
    directory = vm / ('checkpoint-' + name)
    if directory.exists() or directory.is_symlink():
        raise RuntimeError('Checkpoint exists; never overwrite it')
    originals, identities, chains = {}, {}, {}
    # Complete all checks and hashes before creating a directory or hardlink.
    for disk in DISKS:
        active = vm / (disk + '-active.qcow2')
        value = checked(active, vm)
        if value.st_nlink != 1:
            raise RuntimeError('Active checkpoint image already has hardlink aliases')
        chain = json.loads(command(['qemu-img', 'info', '--output=json', '--backing-chain', active]).stdout)
        if not chain or any(row.get('format') != 'qcow2' for row in chain):
            raise RuntimeError('Checkpoint backing format is not qcow2')
        rows = []
        for row in chain:
            path = Path(row['filename']); checked(path, vm)
            rows.append({'path': str(path), 'sha256': sha(path)})
        command(['qemu-img', 'check', active])
        originals[disk] = rows[0]['sha256']
        identities[disk] = (value.st_dev, value.st_ino, value.st_size, value.st_mtime_ns)
        chains[disk] = rows
    if acceptance and acceptance.get('closed_disk_chains') is not None and acceptance['closed_disk_chains'] != chains:
        raise RuntimeError('Checkpoint disk bytes differ from accepted stage; STOP before mutation')
    stopped(); space_guard()
    directory.mkdir(mode=0o700)
    transaction = {'status': 'STARTED', 'name': name, 'inputs_sha256': inputs_sha256,
                   'sources_sha256': sources_sha256, 'acceptance': acceptance,
                   'original_sha256': originals, 'backing_chains': chains,
                   'start_ns': time.time_ns(), 'linked': [], 'created': [], 'committed': []}
    modes = {}
    try:
        save(directory / 'transaction.json', transaction)
        for disk in DISKS:
            stopped(); space_guard()
            active, saved = vm / (disk + '-active.qcow2'), directory / (disk + '.qcow2')
            value = checked(active, vm)
            if (value.st_dev, value.st_ino, value.st_size, value.st_mtime_ns) != identities[disk]:
                raise RuntimeError('Active image changed during checkpoint preparation')
            modes[disk] = stat.S_IMODE(value.st_mode)
            os.link(active, saved)
            transaction['linked'].append(disk)
            save(directory / 'transaction.json', transaction)
        for disk in DISKS:
            stopped(); space_guard()
            saved, overlay = directory / (disk + '.qcow2'), directory / (disk + '.overlay.qcow2')
            command(['qemu-img', 'create', '-f', 'qcow2', '-F', 'qcow2', '-b', saved, overlay])
            transaction['created'].append(disk)
            command(['qemu-img', 'check', overlay])
            save(directory / 'transaction.json', transaction)
        transaction['status'] = 'COMMITTING'; save(directory / 'transaction.json', transaction)
        for disk in DISKS:
            stopped(); space_guard()
            saved = directory / (disk + '.qcow2')
            active = vm / (disk + '-active.qcow2')
            value, snapshot = checked(active, vm), checked(saved, vm)
            if (value.st_dev, value.st_ino) != (snapshot.st_dev, snapshot.st_ino):
                raise RuntimeError('Checkpoint active identity changed before commit')
            if sha(saved) != originals[disk]:
                raise RuntimeError('Checkpoint original bytes changed; STOP')
            (directory / (disk + '.overlay.qcow2')).replace(active)
            transaction['committed'].append(disk)
            save(directory / 'transaction.json', transaction)
        for disk in DISKS:
            (directory / (disk + '.qcow2')).chmod(0o400)
        records = {disk: {'path': str(directory / (disk + '.qcow2')), 'sha256': originals[disk]} for disk in DISKS}
        checkpoint_chains = {disk: [{'path': records[disk]['path'], 'sha256': originals[disk]},
                                    *chains[disk][1:]] for disk in DISKS}
        active_overlays = {disk: {'path': str(vm / (disk + '-active.qcow2')),
                                 'sha256': sha(vm / (disk + '-active.qcow2'))} for disk in DISKS}
        transaction['active_overlays'] = active_overlays
        records.update(inputs_sha256=inputs_sha256, sources_sha256=sources_sha256,
                       acceptance=acceptance, backing_chains=checkpoint_chains, active_overlays=active_overlays)
        save(directory / 'checkpoint.json', records)
        transaction['status'] = 'COMPLETE'; transaction['end_ns'] = time.time_ns()
        save(directory / 'transaction.json', transaction)
        return directory
    except BaseException as error:
        transaction['error'] = repr(error)
        try:
            # Only roll back if both originals still have their reviewed bytes.
            stopped()
            for disk in transaction['linked']:
                saved = directory / (disk + '.qcow2'); checked(saved, vm)
                if sha(saved) != originals[disk]:
                    raise RuntimeError('Checkpoint rollback original hash mismatch; preserve all files')
            for disk in transaction['linked']:
                saved, active = directory / (disk + '.qcow2'), vm / (disk + '-active.qcow2')
                if disk in transaction['committed']:
                    checked(active, vm); saved.replace(active)
                else:
                    if active.stat().st_ino != saved.stat().st_ino or active.stat().st_dev != saved.stat().st_dev:
                        raise RuntimeError('Checkpoint rollback active identity mismatch')
                    saved.unlink()  # New alias only; the original active inode remains.
                active.chmod(modes[disk])
            for disk in DISKS:
                overlay = directory / (disk + '.overlay.qcow2')
                if overlay.exists():
                    checked(overlay, vm); overlay.unlink()  # Empty, never-launched new child.
            completed = directory / 'checkpoint.json'
            if completed.exists():
                completed.rename(directory / 'uncommitted-checkpoint.json')
            transaction['status'] = 'ROLLED_BACK'
            save(directory / 'transaction.json', transaction)
            failed = vm / f'failed-checkpoint-{name}-{time.time_ns()}'
            directory.rename(failed)  # No qcow2/backing references remain here.
        except BaseException as rollback_error:
            transaction['status'] = 'FAILED'; transaction['rollback_error'] = repr(rollback_error)
            try:
                save(directory / 'transaction.json', transaction)
            except OSError:
                pass  # Preserve pending journal too; absence of COMPLETE blocks launch.
        raise
