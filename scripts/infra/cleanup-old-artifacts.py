#!/usr/bin/env python3
"""Apply the user's frozen old-artifact cleanup list; never infer new targets."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

BASE = Path('/mnt/alpbahOS-data/alpbahos-infra-rebuild')
D34 = Path('/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs')
NVME_ROOT = Path('/home/yrslf/alpbahOS-nvme')
HDD_BUILD_ROOT = Path('/mnt/alpbahOS-data/alpbahOS-build')
DIR_ROOTS = (Path('/home/yrslf/alpbahOS-nvme/builds/m07'),
             Path('/home/yrslf/alpbahOS-nvme/m10-alpha-20260930T'),
             Path('/mnt/alpbahOS-data/alpbahOS-build/backups'),
             Path('/mnt/alpbahOS-ssd/alpbahos-builds/archive'))
FLATPAK_CGROUP = re.compile(
    r'^0::/user\.slice/user-1000\.slice/user@1000\.service/app\.slice/'
    r'app-flatpak-[A-Za-z0-9_.\\x2d-]+-[0-9]+\.scope$')
DEVICE_MATCH_CACHE = {}
SUBVOLUME_INDEX = {}


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        while block := stream.read(4 * 1024 * 1024):
            h.update(block)
    return h.hexdigest()


def desktop_sandbox_identity(uid, cgroups, argv):
    """Recognize current-user Flatpak app/proxy processes in their own app scope."""
    if uid != 1000 or not any(FLATPAK_CGROUP.fullmatch(line) for line in cgroups):
        return False
    return (bool(argv) and argv[0] == '/usr/bin/bwrap'
            and any(arg in ('/usr/bin/xdg-dbus-proxy', '/app/bin/zypak-helper', 'spotify', 'opera-gx')
                    for arg in argv))


def known_desktop_sandbox(proc):
    """Do not mistake a Flatpak app process for a build sandbox."""
    try:
        uid = proc.stat().st_uid
        cgroups = (proc / 'cgroup').read_text().splitlines()
        argv = [part.decode(errors='replace') for part in (proc / 'cmdline').read_bytes().split(b'\0') if part]
    except OSError:
        return False
    return desktop_sandbox_identity(uid, cgroups, argv)


def device_identity_matches(path, expected, actual):
    if actual == expected:
        return True
    home_btrfs = Path('/home/yrslf/alpbahOS-nvme')
    if home_btrfs not in path.parents:
        return False
    key = (expected, actual)
    if key in DEVICE_MATCH_CACHE:
        return DEVICE_MATCH_CACHE[key]
    result = subprocess.run(['findmnt', '-n', '-o', 'TARGET,FSTYPE', '-T', str(path)],
                            capture_output=True, text=True,
                            env={**os.environ, 'LC_ALL': 'C'})
    matched = result.returncode == 0 and result.stdout.strip() == '/home btrfs' and not result.stderr.strip()
    DEVICE_MATCH_CACHE[key] = matched
    return matched


def subvolume_index():
    output = subprocess.run(['btrfs', 'subvolume', 'list', '-u', '/home'], check=True,
                            capture_output=True, text=True,
                            env={**os.environ, 'LC_ALL': 'C'}).stdout
    values = {}
    for line in output.splitlines():
        match = re.match(r'^ID\s+(\d+).*?\buuid\s+(\S+)\s+path\s+(.+)$', line)
        require(match is not None, 'Unexpected Btrfs subvolume inventory row')
        relative = match.group(3)
        require(relative not in values, 'Duplicate path in Btrfs subvolume inventory')
        values[relative] = {'id': int(match.group(1)), 'uuid': match.group(2)}
    return values


def subvolume_index_if_needed(user_clean):
    """User cleanup never deletes subvolumes, so it needs no root-only inventory."""
    return {} if user_clean else subvolume_index()


def within_nvme(path):
    path = Path(path)
    return path == NVME_ROOT or NVME_ROOT in path.parents


def within_hdd_build(path):
    path = Path(path)
    return path == HDD_BUILD_ROOT or HDD_BUILD_ROOT in path.parents


def subvolume_identity(path, record, index=None):
    if index is not None:
        relative = path.relative_to('/home').as_posix()
        value = index.get(relative)
        require(value is not None, 'Subvolume missing from current Btrfs inventory: ' + str(path))
        if record.get('uuid'):
            require(value['uuid'] == record['uuid'], 'Subvolume UUID changed: ' + str(path))
        if type(record.get('id')) is int:
            require(value['id'] == record['id'], 'Subvolume ID changed: ' + str(path))
        return
    info = subprocess.run(['btrfs', 'subvolume', 'show', str(path)], check=True,
                          capture_output=True, text=True,
                          env={**os.environ, 'LC_ALL': 'C'}).stdout
    uuid = re.search(r'^\s*UUID:\s*(\S+)\s*$', info, re.M)
    identity = re.search(r'^\s*Subvolume ID:\s*(\d+)\s*$', info, re.M)
    if record.get('uuid'):
        require(uuid and uuid.group(1) == record['uuid'], 'Subvolume UUID changed: ' + str(path))
    if type(record.get('id')) is int:
        require(identity and int(identity.group(1)) == record['id'], 'Subvolume ID changed: ' + str(path))


def save_json(path, value):
    require(path.parent == BASE / 'logs', 'Output outside private log directory')
    for parent in path.parents:
        require(not parent.is_symlink(), 'Output ancestor is a symlink')
    if path.exists() or path.is_symlink():
        require(not path.is_symlink() and path.stat().st_uid == os.geteuid(), 'Foreign or symlink output')
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o644)
    with os.fdopen(fd, 'w') as stream:
        stream.write(json.dumps(value, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--plan', type=Path, required=True)
    parser.add_argument('--plan-sha256', required=True)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--user-clean', action='store_true')
    parser.add_argument('--nvme-only', action='store_true', help='Limit cleanup to NVMe targets')
    parser.add_argument('--hdd-only', action='store_true', help='Limit cleanup to HDD build-artifact targets')
    parser.add_argument('--host-audit', action='store_true', help='Root-run read-only RPM/kernel audit before and after cleanup')
    args = parser.parse_args()
    require(args.plan == BASE / 'logs/cleanup-root.plan.json', 'Plan path not allowlisted')
    require(sha(args.plan) == args.plan_sha256, 'Frozen plan changed; STOP')
    plan = json.loads(args.plan.read_text())
    require(plan['schema'] == 'alpbahOS.cleanup-d34/v1', 'Unknown plan')
    require(not args.user_clean or os.geteuid() == 1000, 'User cleanup must be unprivileged')
    require(not (args.nvme_only and args.hdd_only), 'Choose only one cleanup scope')
    require(not args.hdd_only or (not args.user_clean and os.geteuid() == 0), 'HDD scope requires root cleanup')
    require(not args.apply or args.user_clean or os.geteuid() == 0, 'Subvolume cleanup requires user-run sudo')
    require(not args.host_audit or (args.apply and not args.user_clean and os.geteuid() == 0), 'Host audit requires user-run root cleanup')
    for proc in Path('/proc').iterdir():
        if not proc.name.isdigit():
            continue
        try:
            comm = (proc / 'comm').read_text().strip()
        except OSError:
            continue
        blocked = (comm in ('make', 'ninja', 'gcc', 'cc1', 'cc1plus', 'chroot', 'mksquashfs', 'xorriso')
                   or comm.startswith('qemu-system')
                   or (comm == 'bwrap' and not known_desktop_sandbox(proc)))
        require(not blocked, 'Live build/image process: ' + proc.name + ' ' + comm)
    mounts = [Path(line.split()[4].replace('\\040', ' '))
              for line in Path('/proc/self/mountinfo').read_text().splitlines()]
    keep = plan['keep']
    require(keep['path'] == str(D34 / 'libwacom-20260930T193342Z-37efbf1e/after-ro'), 'Retained D34 target changed')
    require(keep['uuid'] == 'c57a57dc-9b42-084a-8304-9151bfa384f9', 'Retained UUID changed')
    require(sha(Path(keep['ledger_path'])) == keep['ledger_sha256'], 'Retained ownership ledger changed')
    SUBVOLUME_INDEX.update(subvolume_index_if_needed(args.user_clean))
    retained_names = list(plan['retained_images'])
    if args.nvme_only:
        retained_names = [name for name in retained_names if within_nvme(name)]
    elif args.hdd_only:
        retained_names = [name for name in retained_names if within_hdd_build(name)]
    protected = [Path(keep['path']), *map(Path, retained_names)]
    for name in retained_names:
        record = plan['retained_images'][name]
        path = Path(name)
        require(path.is_file() and not path.is_symlink(), 'Retained milestone missing or aliased: ' + name)
        st = path.stat()
        require(device_identity_matches(path, record['device'], st.st_dev)
                and (st.st_ino, st.st_size) == (record['inode'], record['size'])
                and sha(path) == record.get('sha256'),
                'Retained milestone changed: ' + name)

    def validate(record, subvolume=False, check_subvolume=True):
        path = Path(record['path'])
        require(path.is_absolute() and '..' not in path.parts, 'Noncanonical target')
        if subvolume:
            require(D34 in path.parents and path.parent.parent == D34
                    and path.name in ('base-ro', 'working-root', 'after-ro', 'build-test-after-ro'), 'Subvolume scope violation')
        else:
            require(any(root in path.parents for root in DIR_ROOTS), 'Directory/file scope violation')
        require(not any(path == p or path in p.parents for p in protected), 'Protected milestone selected')
        require(not any(path == m or path in m.parents for m in mounts), 'Target is/contains a mount')
        require(not any(root == m or root in m.parents for root in DIR_ROOTS for m in mounts if m in path.parents),
                'Nested backing mount')
        for ancestor in (path, *path.parents):
            require(not ancestor.is_symlink(), 'Symlink target/ancestor')
        if not path.exists():
            return None
        st = path.stat()
        require(device_identity_matches(path, record['device'], st.st_dev)
                and st.st_ino == record['inode'], 'Target identity changed: ' + str(path))
        if subvolume:
            require(st.st_ino == 256, 'Not a Btrfs subvolume root')
            if check_subvolume:
                subvolume_identity(path, record, SUBVOLUME_INDEX)
        elif record in plan['delete_deferred_images']:
            require(path.is_file() and st.st_size == record['size'] and st.st_uid == record['uid'],
                    'Deferred image identity changed: ' + str(path))
        else:
            require(path.is_dir(), 'Obsolete directory target changed type: ' + str(path))
        return path

    targets = []
    for kind, rows in (('subvolume', plan['delete_subvolumes']),
                       ('file', plan['delete_deferred_images']),
                       ('directory', plan['delete_obsolete_directories'])):
        for row in rows:
            if args.user_clean and kind == 'subvolume':
                continue
            if args.nvme_only and not within_nvme(row['path']):
                continue
            if args.hdd_only and not within_hdd_build(row['path']):
                continue
            path = validate(row, kind == 'subvolume', check_subvolume=not args.user_clean)
            if path is not None:
                targets.append((kind, row))
    if not args.apply:
        print(json.dumps({'dry_run': True, 'existing_targets': len(targets), 'retained_milestones': len(protected)}))
        return
    def host_audit(label):
        stamp = time.time_ns()
        audit = {'uid': os.geteuid(), 'captured_at_ns': stamp,
                 'boot_id': Path('/proc/sys/kernel/random/boot_id').read_text().strip(), 'commands': {}}
        for name, argv in (('rpm', ['rpm', '-Va']), ('kernel', ['journalctl', '-k', '-b', '--no-pager'])):
            process = subprocess.run(argv, capture_output=True, env={**os.environ, 'LC_ALL': 'C'})
            log = BASE / f'logs/root-cleanup-audit-{label}-{stamp}.{name}.log'
            with log.open('xb') as stream:
                stream.write(process.stdout)
            stderr = log.with_suffix(log.suffix + '.stderr')
            with stderr.open('xb') as stream:
                stream.write(process.stderr)
            audit['commands'][name] = {'argv': argv, 'exit': process.returncode, 'stdout': str(log),
                                       'sha256': sha(log), 'stderr': str(stderr), 'stderr_sha256': sha(stderr)}
        save_json(BASE / f'logs/root-host-audit-{label}.json', audit)
    if args.host_audit:
        host_audit('before')
    result = {'start_ns': time.time_ns(), 'user_clean': args.user_clean, 'removed': [], 'deferred': []}
    output = BASE / ('logs/cleanup-user-directories-result.json' if args.user_clean else 'logs/cleanup-root-result.json')
    if not args.user_clean:
        info = subprocess.run(['btrfs', 'subvolume', 'show', keep['path']], check=True, capture_output=True, text=True,
                              env={**os.environ, 'LC_ALL': 'C'}).stdout
        require(re.search(r'^\s*UUID:\s*' + re.escape(keep['uuid']) + r'\s*$', info, re.M), 'Retained subvolume UUID mismatch')
    for kind, row in targets:
        if args.user_clean and kind == 'subvolume':
            continue
        path = validate(row, kind == 'subvolume', check_subvolume=False)
        if path is None:
            continue
        try:
            if kind == 'subvolume':
                subvolume_identity(path, row)
                subprocess.run(['btrfs', 'subvolume', 'delete', str(path)], check=True, stdout=subprocess.DEVNULL)
            elif kind == 'file':
                require(path.stat().st_size == row['size'], 'Image file size changed')
                path.unlink()
            else:
                require(shutil.rmtree.avoids_symlink_attacks, 'Safe directory remover unavailable')
                shutil.rmtree(path)
            result['removed'].append({'kind': kind, 'path': str(path)})
        except PermissionError as error:
            if not args.user_clean:
                raise
            result['deferred'].append({'kind': kind, 'path': str(path), 'error': str(error)})
        save_json(output, result)
    if not args.user_clean:
        subprocess.run(['btrfs', 'filesystem', 'sync', '/home/yrslf'], check=True)
    for name in retained_names:
        require(Path(name).is_file(), 'Retained image missing after cleanup')
    require(Path(keep['path']).is_dir(), 'Retained D34 root missing after cleanup')
    result['after'] = {str(p): {'free_gib': round(shutil.disk_usage(p).free / 1024**3, 2),
                              'free_percent': round(100 * shutil.disk_usage(p).free / shutil.disk_usage(p).total, 2)}
                       for p in ('/', '/mnt/alpbahOS-ssd', '/mnt/alpbahOS-data')}
    result['end_ns'] = time.time_ns()
    result['complete'] = not args.user_clean and not result['deferred']
    if args.host_audit:
        host_audit('after')
    save_json(output, result)
    print(json.dumps({'removed': len(result['removed']), 'deferred': len(result['deferred']), 'after': result['after']}))


if __name__ == '__main__':
    main()
