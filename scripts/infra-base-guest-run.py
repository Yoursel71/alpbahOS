#!/usr/bin/env python3
"""Run the base guest with source-root-relative separate-build directories."""
import hashlib
import json
import os
import re
import stat
import sys
import tempfile
from pathlib import Path


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def root_test_tree(cwd, build_root=Path('/srv/lfs/build')):
    """Return the dedicated source tree made visible to a root user namespace."""
    tree = Path(cwd)
    if (tree / 'config.make').is_file() and (tree.parent / 'Makefile').is_file():
        tree = tree.parent  # Glibc's separate build directory.
    if tree.parent != Path(build_root) or tree.is_symlink() or tree.resolve() != tree:
        raise RuntimeError('Root test tree is outside the dedicated LFS build directory')
    return tree


M32_KERNEL_UAPI_DIRECTORIES = ('asm', 'asm-generic', 'linux')
M32_C_COMPILER = 'CC=/srv/lfs/tools/bin/x86_64-lfs-linux-gnu-gcc -m32'
M32_CXX_COMPILER = 'CXX=/srv/lfs/tools/bin/x86_64-lfs-linux-gnu-g++ -m32 -static-libgcc'
M32_HOST_C_COMPILER = 'CC=gcc -m32'
M32_HOST_CXX_COMPILER = 'CXX=g++ -m32'


def uses_m32_uapi_configure(argv, header_include='/srv/lfs/build/.m32-kernel-uapi/include'):
    marker = ' -I' + header_include
    return ('../configure' in argv
            and any(value.startswith(('CC=', 'CXX='))
                    and ' -m32' in value and marker in value for value in argv))


def uses_m32_uapi_build(cwd, header_include='/srv/lfs/build/.m32-kernel-uapi/include'):
    """Identify Glibc's m32 build from its isolated compiler configuration."""
    if cwd is None:
        return False
    config = Path(cwd) / 'config.make'
    if config.is_symlink() or not config.is_file():
        return False
    compiler = 'CC = /srv/lfs/tools/bin/x86_64-lfs-linux-gnu-gcc -m32 -I' + header_include
    return any(line == compiler for line in config.read_text().splitlines())


def disable_unavailable_m32_cxx(argv, cwd):
    """Keep bootstrap m32 Glibc from linking its optional C++ helper."""
    argv = list(argv)
    make_indexes = [index for index, value in enumerate(argv) if value == 'make']
    if not uses_m32_uapi_build(cwd) or not make_indexes:
        return argv
    tail = argv[make_indexes[-1] + 1:]
    building = len(tail) == 1 and re.fullmatch(r'-j[1-8]', tail[0])
    installing = (len(tail) >= 3 and re.fullmatch(r'-j[1-8]', tail[0])
                  and tail[-1] == 'install'
                  and any(value.startswith('DESTDIR=') for value in tail[1:-1]))
    if building or installing:
        argv.append('CXX=')
    return argv


def handoff_glibc_rpc_bootstrap_owner(recipe, built, root, result, installer,
                                     package_install):
    """Transfer identical /etc/rpc from the cross-compiler package to base Glibc.

    The bootstrap package must be its sole recorded owner and the installed
    bytes/metadata must match the incoming Glibc manifest. The old file and DB
    are restored if Alp installation fails, so an interrupted attempt cannot
    leave an ownership gap in a resumable guest.
    """
    if recipe.get('name') != 'glibc' or recipe.get('phase') != 'base':
        raise RuntimeError('Bootstrap RPC ownership handoff is only for base Glibc')
    value = package_install.validate_bundle(recipe, built)
    entries = [entry for entry in value['entries'] if entry.get('path') == '/etc/rpc']
    if len(entries) != 1 or entries[0].get('type') != 'file':
        raise RuntimeError('Base Glibc manifest must contain exactly one regular /etc/rpc')
    entry = entries[0]
    root, result = Path(root), Path(result)
    target = root / 'etc/rpc'
    db = root / 'var/lib/alp/db.json'
    for path in (root, target.parent, db.parent, result):
        if path.is_symlink() or path.resolve() != path:
            raise RuntimeError('RPC ownership handoff path is aliased')
    if not result.is_dir():
        raise RuntimeError('RPC ownership receipt directory is missing')
    receipt = result / 'glibc-rpc-ownership-transfer.json'
    if receipt.exists() or receipt.is_symlink():
        raise RuntimeError('Existing RPC ownership transfer receipt; preserve attempt')
    if target.is_symlink() or not target.is_file():
        raise RuntimeError('Bootstrap /etc/rpc is not a regular file')
    current_stat = target.stat(follow_symlinks=False)
    if (stat.S_IMODE(current_stat.st_mode) != entry.get('mode')
            or current_stat.st_uid != entry.get('uid')
            or current_stat.st_gid != entry.get('gid')
            or current_stat.st_size != entry.get('size')
            or sha(target) != entry.get('sha256')):
        raise RuntimeError('Bootstrap /etc/rpc does not exactly match base Glibc manifest')
    if db.is_symlink() or not db.is_file():
        raise RuntimeError('Alp DB is missing or aliased during RPC ownership handoff')
    raw_db = db.read_bytes()
    database = json.loads(raw_db)
    if database.get('schema_version') != 1 or not isinstance(database.get('packages'), dict):
        raise RuntimeError('Unsupported Alp database during RPC ownership handoff')
    packages = database['packages']
    owners, old_files_owner = [], None
    for owner, record in packages.items():
        files = record.get('files', [])
        symlinks = record.get('symlinks', [])
        claims_file = any(str(path).lstrip('/') == 'etc/rpc' for path in files)
        claims_link = any(str(path).lstrip('/') == 'etc/rpc' for path in symlinks)
        if claims_file or claims_link:
            owners.append(owner)
            if claims_file and not claims_link:
                old_files_owner = owner
    if owners != ['glibc-cross-m64'] or old_files_owner != 'glibc-cross-m64':
        raise RuntimeError('Bootstrap /etc/rpc ownership is not exclusively glibc-cross-m64')
    old_record = packages[old_files_owner]
    if old_record.get('status') != 'installed':
        raise RuntimeError('Bootstrap Glibc owner is not installed')
    run_id = result.parent.name
    if not re.fullmatch(r'[0-9a-f]{32}', run_id):
        raise RuntimeError('RPC ownership transfer is not bound to a base run')
    backup = target.with_name('.rpc.infra-transfer-' + run_id + '.bak')
    if os.path.lexists(backup):
        raise RuntimeError('Existing RPC transfer backup; preserve attempt')
    prior_db_sha = hashlib.sha256(raw_db).hexdigest()
    db_stat = db.stat(follow_symlinks=False)
    old_record['files'] = [path for path in old_record.get('files', [])
                           if str(path).lstrip('/') != 'etc/rpc']
    updated_db = (json.dumps(database, sort_keys=True, indent=2) + '\n').encode()

    def atomic_db_write(raw):
        fd, name = tempfile.mkstemp(prefix='.db.json.rpc-transfer-', dir=str(db.parent))
        temp = Path(name)
        try:
            with os.fdopen(fd, 'wb') as stream:
                stream.write(raw)
                stream.flush()
                os.fsync(stream.fileno())
            os.chmod(temp, stat.S_IMODE(db_stat.st_mode))
            os.chown(temp, db_stat.st_uid, db_stat.st_gid)
            os.replace(temp, db)
            dirfd = os.open(db.parent, os.O_RDONLY | getattr(os, 'O_DIRECTORY', 0))
            try:
                os.fsync(dirfd)
            finally:
                os.close(dirfd)
        finally:
            if temp.exists():
                temp.unlink()

    original_db = db.with_name('.db.json.rpc-transfer-original-' + run_id)
    if os.path.lexists(original_db):
        raise RuntimeError('Existing RPC database backup; preserve attempt')
    fd = os.open(original_db, os.O_WRONLY | os.O_CREAT | os.O_EXCL, stat.S_IMODE(db_stat.st_mode))
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(raw_db)
            stream.flush()
            os.fsync(stream.fileno())
        os.chown(original_db, db_stat.st_uid, db_stat.st_gid)
    except BaseException:
        original_db.unlink(missing_ok=True)
        raise
    moved_file = False
    try:
        # Keep an exact DB copy until Alp has installed and claimed the file.
        atomic_db_write(updated_db)
        os.replace(target, backup)
        moved_file = True
        installed = installer(recipe, built, root, result)
        current_db = json.loads(db.read_bytes())
        if 'glibc' not in current_db.get('packages', {}):
            raise RuntimeError('Base Glibc did not claim /etc/rpc in Alp DB')
        glibc = current_db['packages']['glibc']
        if not any(str(path).lstrip('/') == 'etc/rpc' for path in glibc.get('files', [])):
            raise RuntimeError('Base Glibc DB record is missing /etc/rpc ownership')
        final_stat = target.stat(follow_symlinks=False)
        if (target.is_symlink() or not target.is_file()
                or stat.S_IMODE(final_stat.st_mode) != entry['mode']
                or final_stat.st_uid != entry['uid'] or final_stat.st_gid != entry['gid']
                or final_stat.st_size != entry['size'] or sha(target) != entry['sha256']):
            raise RuntimeError('Installed /etc/rpc differs from verified manifest')
        evidence = {'schema': 'alpbahOS.glibc-rpc-ownership-transfer/v1',
                    'run_id': run_id, 'path': '/etc/rpc',
                    'from_package': 'glibc-cross-m64', 'to_package': 'glibc',
                    'prior_db_sha256': prior_db_sha,
                    'manifest_sha256': built['manifest_sha256'],
                    'file_sha256': entry['sha256'], 'result': 'TRANSFERRED'}
        with receipt.open('x') as stream:
            json.dump(evidence, stream, sort_keys=True, indent=2)
            stream.write('\n')
            stream.flush()
            os.fsync(stream.fileno())
        backup.unlink()
        original_db.unlink()
        for parent in (target.parent, db.parent, result):
            dirfd = os.open(parent, os.O_RDONLY | getattr(os, 'O_DIRECTORY', 0))
            try:
                os.fsync(dirfd)
            finally:
                os.close(dirfd)
        return installed
    except BaseException:
        if moved_file:
            if os.path.lexists(target):
                if target.is_dir() and not target.is_symlink():
                    raise RuntimeError('Unsafe directory appeared at /etc/rpc during rollback')
                target.unlink()
            if backup.exists():
                os.replace(backup, target)
        if original_db.exists():
            if db.exists() or db.is_symlink():
                db.unlink()
            os.replace(original_db, db)
        raise


def prepare_m32_kernel_headers(argv, header_include='/srv/lfs/build/.m32-kernel-uapi/include'):
    """Point the Builder's 32-bit compiler at an isolated kernel-header view."""
    argv = list(argv)
    if '../configure' not in argv:
        return argv
    for index, value in enumerate(argv):
        if value in (M32_HOST_C_COMPILER, M32_HOST_CXX_COMPILER):
            compiler = M32_C_COMPILER if value.startswith('CC=') else M32_CXX_COMPILER
            argv[index] = compiler
        if argv[index] in (M32_C_COMPILER, M32_CXX_COMPILER):
            argv[index] += ' -I' + header_include
    return argv


def install_m32_kernel_headers(source_include='/srv/lfs/usr/include',
                               header_include='/srv/lfs/build/.m32-kernel-uapi/include'):
    """Expose only installed Linux UAPI directories to the Builder compiler."""
    source = Path(source_include)
    target = Path(header_include)
    source_directories = {}
    for name in M32_KERNEL_UAPI_DIRECTORIES:
        directory = source / name
        if not directory.is_dir() or directory.is_symlink():
            raise RuntimeError('Pinned LFS kernel UAPI directory is missing: ' + str(directory))
        source_directories[name] = directory.resolve()
    if not (source / 'asm/errno.h').is_file():
        raise RuntimeError('Pinned LFS kernel UAPI errno header is missing')
    if target.is_symlink():
        raise RuntimeError('Kernel UAPI include root must not be a symlink')
    target.mkdir(parents=True, exist_ok=True)
    if not target.is_dir():
        raise RuntimeError('Kernel UAPI include root is not a directory')
    expected_names = set(M32_KERNEL_UAPI_DIRECTORIES)
    if any(path.name not in expected_names for path in target.iterdir()):
        raise RuntimeError('Kernel UAPI include root contains unexpected entries')
    for name, source_directory in source_directories.items():
        link = target / name
        if link.is_symlink():
            if link.resolve() != source_directory:
                raise RuntimeError('Kernel UAPI link target changed: ' + str(link))
        elif link.exists():
            raise RuntimeError('Kernel UAPI include entry is not an expected symlink: ' + str(link))
        else:
            link.symlink_to(source_directory, target_is_directory=True)
    if not (target / 'asm/errno.h').is_file():
        raise RuntimeError('Kernel UAPI include view is incomplete')
    return target


if len(sys.argv) != 2 or not re.fullmatch(r'[0-9a-f]{64}', sys.argv[1]):
    raise SystemExit('STOP: expected pinned guest runner SHA-256')
if sha(__file__) != sys.argv[1]:
    raise SystemExit('STOP: guest base runner bytes changed')

sys.path.insert(0, '/opt/alp-infra/scripts/infra')
import package_stage

_recipe_working_directory = package_stage.recipe_working_directory


def recipe_working_directory(root, recipe, step):
    # build_staged already changes cwd to <source-root>/build when
    # separate_build is true. Recipe working_directories remain source-root
    # relative, so resolve them from the parent to avoid build/build.
    if recipe.get('separate_build'):
        root = Path(root).parent
    return _recipe_working_directory(root, recipe, step)


package_stage.recipe_working_directory = recipe_working_directory

_run = package_stage.run


def run_with_root_owned_test_tree(argv, log, cwd=None, env=None):
    argv = prepare_m32_kernel_headers(argv)
    argv = disable_unavailable_m32_cxx(argv, cwd)
    if uses_m32_uapi_configure(argv):
        install_m32_kernel_headers()
    if (len(argv) >= 3 and argv[0] == package_stage.RUNUSER
            and argv[1:3] == ['-u', 'root']):
        tree = root_test_tree(cwd)
        _run(['chown', '-hR', 'root:root', str(tree)], log)
    return _run(argv, log, cwd=cwd, env=env)


package_stage.run = run_with_root_owned_test_tree
import guest_base

_install_staged = guest_base.install_staged


def install_staged_with_glibc_rpc_handoff(recipe, built, root, result, reinstall=False):
    if recipe.get('name') == 'glibc':
        return handoff_glibc_rpc_bootstrap_owner(
            recipe, built, root, result, _install_staged, package_install)
    return _install_staged(recipe, built, root, result, reinstall=reinstall)


import package_install
guest_base.install_staged = install_staged_with_glibc_rpc_handoff

guest_base.main()
