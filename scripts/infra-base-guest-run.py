#!/usr/bin/env python3
"""Run the base guest with source-root-relative separate-build directories."""
import hashlib
import json
import os
import re
import shutil
import stat
import sys
import tempfile
from pathlib import Path

REPO = Path('/opt/alp-infra')
LFS = Path('/srv/lfs')
INFRA = Path('/srv/infra')


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def fingerprint(value):
    raw = json.dumps(value, sort_keys=True, separators=(',', ':')).encode()
    return hashlib.sha256(raw).hexdigest()


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


def use_staged_file_magic_compiler(argv, cwd,
                                   build_dir='/srv/lfs/build/base-file',
                                   stage_root='/srv/lfs/stage/base-file'):
    """Use the just-built native file tool for the multilib magic database.

    The file package's --host=i686 configure step marks its magic compiler as
    cross-compiled and defaults FILE_COMPILE to the Builder's installed
    `file`. That version can lag the source release. The native package stage
    already contains the matching 64-bit file executable and libmagic, so use
    those for this one cross-build make invocation.
    """
    argv = list(argv)
    if cwd is None or Path(cwd).resolve() != Path(build_dir).resolve():
        return argv
    makefile = Path(cwd) / 'magic/Makefile'
    native_file_compiler = re.compile(
        r'FILE_COMPILE = file(?:\$\{EXEEXT\}|\$\(EXEEXT\))?')
    if (not makefile.is_file()
            or not any(native_file_compiler.fullmatch(line)
                       for line in makefile.read_text().splitlines())):
        return argv
    make_indexes = [index for index, value in enumerate(argv) if value == 'make']
    if not make_indexes:
        return argv
    make_index = make_indexes[-1]
    make_args = argv[make_index + 1:]
    if not any(re.fullmatch(r'-j[1-8]', value) for value in make_args) or 'install' in make_args:
        return argv
    if any(value.startswith('FILE_COMPILE=') for value in make_args):
        return argv

    stage = Path(stage_root)
    compiler = stage / 'usr/bin/file'
    library_dir = stage / 'usr/lib'
    if (compiler.is_symlink() or not compiler.is_file() or not os.access(compiler, os.X_OK)
            or library_dir.is_symlink() or not library_dir.is_dir()):
        raise RuntimeError('Matching staged native file compiler is missing or unsafe')
    env_indexes = [index for index, value in enumerate(argv[:make_index]) if value == 'env']
    if not env_indexes:
        raise RuntimeError('Cross-compiled file make is missing its bounded env wrapper')
    env_index = env_indexes[-1]
    ld_library_path = 'LD_LIBRARY_PATH=' + str(library_dir)
    existing_ld = next((index for index in range(env_index + 1, make_index)
                        if argv[index].startswith('LD_LIBRARY_PATH=')), None)
    if existing_ld is None:
        argv.insert(env_index + 1, ld_library_path)
        make_index += 1
    else:
        argv[existing_ld] = ld_library_path
    argv.insert(make_index + 1, 'FILE_COMPILE=' + str(compiler))
    return argv


def readline_ncurses_environment(argv, cwd, env,
                                build_dir='/srv/lfs/build/base-readline',
                                stage_root='/srv/lfs/stage/base-ncurses'):
    """Expose staged Ncurses only to the canonical Readline linker commands."""
    if cwd is None or Path(cwd).resolve() != Path(build_dir).resolve():
        return env
    if 'SHLIB_LIBS=-lncursesw' not in argv:
        return env
    stage = Path(stage_root)
    library_dirs = (stage / 'usr/lib', stage / 'usr/lib32')
    for directory in library_dirs:
        if directory.is_symlink() or not directory.is_dir() or directory.resolve() != directory:
            raise RuntimeError('Pinned staged Ncurses library directory is missing or unsafe')
    updated = dict(os.environ if env is None else env)
    staged = ':'.join(str(directory) for directory in library_dirs)
    existing = updated.get('LIBRARY_PATH')
    updated['LIBRARY_PATH'] = staged + (':' + existing if existing else '')
    return updated


def bootstrap_ncurses_bundle(guest_base, package_stage):
    """Stage the pinned Ncurses bundle before Readline without installing it."""
    plan = guest_base.canonical_plan(REPO)
    recipes = guest_base.recipes(plan)
    recipe = next((item for item in recipes if item.get('name') == 'ncurses'), None)
    if recipe is None:
        raise RuntimeError('Canonical base package plan has no Ncurses recipe')
    for item in recipes:
        guest_base.heavy_recipe_guard(item)
    auth = guest_base.safe_json(INFRA / 'base-authorization.json')
    run_id = auth.get('run_id')
    if not re.fullmatch(r'[0-9a-f]{32}', str(run_id)):
        raise RuntimeError('Base authorization has no valid run identity')
    result_root = LFS / 'results/base'
    result = result_root / run_id
    guest_base.guest_install_guard(LFS, result_root)
    if (result_root.is_symlink() or result_root.resolve() != result_root
            or result.is_symlink() or result.resolve() != result):
        raise RuntimeError('Unsafe Ncurses bootstrap evidence directory')
    result_root.mkdir(exist_ok=True)
    result.mkdir(exist_ok=True)
    binding = guest_base.current_binding(plan, LFS)
    header = result / 'inputs.json'
    if header.exists():
        if guest_base.safe_json(header) != binding:
            raise RuntimeError('Ncurses bootstrap binding changed; restore checkpoint')
    else:
        guest_base.safe_json(header, binding)
    directory = result / 'ncurses'
    if directory.is_symlink() or directory.resolve() != directory:
        raise RuntimeError('Unsafe Ncurses package evidence directory')
    directory.mkdir(exist_ok=True)
    state = directory / 'built.json'
    if state.exists():
        built = guest_base.saved_bundle(recipe, directory, binding)
    else:
        marker = directory / 'build-started.json'
        if marker.exists() or marker.is_symlink():
            raise RuntimeError('Interrupted Ncurses bootstrap needs checkpoint recovery')
        guest_base.safe_json(marker, binding)
        built = package_stage.build_staged(recipe, 'base-ncurses', directory)
        guest_base.validate_bundle(recipe, built)
        saved = {key: str(value) if isinstance(value, Path) else value
                 for key, value in built.items()}
        guest_base.safe_json(state, {'binding': binding, 'result': 'BUILT', 'built': saved})
    return built


def accepted_glibc_cross_manifest(root, package_install, package_name):
    """Load an exact accepted cross-ABI Glibc bundle from the toolchain stage."""
    if package_name not in ('glibc-cross-m64', 'glibc-cross-m32'):
        raise RuntimeError('Unsupported accepted bootstrap Glibc package')
    acceptance_path = INFRA / 'toolchain-acceptance.json'
    inputs_path = INFRA / 'inputs.json'
    for path in (acceptance_path, inputs_path):
        if path.is_symlink() or not path.is_file() or path.resolve() != path:
            raise RuntimeError('Accepted toolchain ownership evidence is missing or aliased')
    acceptance, inputs = json.loads(acceptance_path.read_bytes()), json.loads(inputs_path.read_bytes())
    run_id = acceptance.get('run_id')
    if (acceptance.get('schema') != 'alpbahOS.toolchain-acceptance/v1'
            or acceptance.get('result') != 'PASS' or acceptance.get('stage') != 'toolchain'
            or not re.fullmatch(r'[0-9a-f]{32}', str(run_id))
            or inputs.get('inputs_sha256') != acceptance.get('inputs_sha256')):
        raise RuntimeError('Accepted toolchain binding is invalid')
    directory = root / 'results/toolchain' / run_id / package_name
    receipt_path, built_path, snapshot_path = (directory / (package_name + '.installed.json'),
                                                directory / 'built.json',
                                                directory / (package_name + '.db.json'))
    for path in (directory, receipt_path, built_path, snapshot_path):
        if path.is_symlink() or path.resolve() != path:
            raise RuntimeError('Accepted bootstrap Glibc evidence is aliased')
    receipt = json.loads(receipt_path.read_bytes())
    record = json.loads(built_path.read_bytes())
    snapshot = json.loads(snapshot_path.read_bytes())
    old_recipe_path = REPO / 'recipes/toolchain' / (package_name + '.json')
    if old_recipe_path.is_symlink() or not old_recipe_path.is_file():
        raise RuntimeError('Pinned bootstrap Glibc recipe is unavailable')
    old_recipe = json.loads(old_recipe_path.read_bytes())
    source_manifest = REPO / 'manifests/infra-sources.json'
    sources = json.loads(source_manifest.read_bytes())
    pinned_source = package_install.source_pin(sources, old_recipe['source'], REPO)
    built = record.get('built', {})
    prior_record = snapshot.get('packages', {}).get(package_name)
    manifest_path = directory / ('toolchain-' + package_name + '.json')
    archive_path = directory / ('toolchain-' + package_name + '.tar.gz')
    if (record.get('result') != 'BUILT'
            or record.get('binding', {}).get('run_id') != run_id
            or record.get('binding', {}).get('inputs_sha256') != inputs.get('inputs_sha256')
            or built.get('manifest') != str(manifest_path) or built.get('archive') != str(archive_path)
            or receipt.get('result') != 'PASS' or receipt.get('package') != package_name
            or receipt.get('root') != str(root) or receipt.get('version') != old_recipe.get('version')
            or receipt.get('inputs_sha256') != inputs.get('inputs_sha256')
            or receipt.get('recipe_sha256') != fingerprint(old_recipe)
            or receipt.get('manifest_sha256') != built.get('manifest_sha256')
            or receipt.get('archive_sha256') != built.get('archive_sha256')
            or any(built.get('source', {}).get(key) != pinned_source[key]
                   for key in ('filename', 'url', 'sha256'))
            or receipt.get('db_sha256') != package_install.sha(snapshot_path)
            or not isinstance(prior_record, dict)
            or receipt.get('package_record_sha256') != fingerprint(prior_record)):
        raise RuntimeError('Accepted Glibc bootstrap receipt does not match its pinned bundle/DB')
    current = package_install.packages(root).get(package_name)
    if not isinstance(current, dict) or fingerprint(current) != fingerprint(prior_record):
        raise RuntimeError('Installed bootstrap Glibc DB record differs from accepted toolchain evidence')
    if package_install.sha(manifest_path) != built.get('manifest_sha256'):
        raise RuntimeError('Accepted bootstrap Glibc manifest bytes changed')
    if package_install.sha(archive_path) != built.get('archive_sha256'):
        raise RuntimeError('Accepted bootstrap Glibc archive bytes changed')
    package_install.validate_bundle(old_recipe, built)
    return json.loads(manifest_path.read_bytes())


def accepted_glibc_cross_m64_manifest(root, package_install):
    return accepted_glibc_cross_manifest(root, package_install, 'glibc-cross-m64')


def accepted_glibc_cross_m32_manifest(root, package_install):
    return accepted_glibc_cross_manifest(root, package_install, 'glibc-cross-m32')


def handoff_glibc_bootstrap_owners(recipe, built, root, result, installer,
                                   package_install, previous_manifests):
    """Transactionally transfer shared paths from accepted bootstrap Glibc packages.

    The multilib toolchain's m64 and m32 Glibc packages can both own paths in
    the final base Glibc manifest. Verify each accepted manifest, back up every
    overlap, and let Alp install the base package as the sole owner. Restore
    every payload and DB record if installation fails.
    """
    if recipe.get('name') != 'glibc' or recipe.get('phase') != 'base':
        raise RuntimeError('Bootstrap Glibc ownership handoff is only for base Glibc')
    value = package_install.validate_bundle(recipe, built)
    new_entries = {entry['path']: entry for entry in value['entries'] if entry['type'] != 'directory'}
    old_entries_by_owner = {}
    old_directories_by_owner = {}
    manifests_by_owner = {}
    for previous_manifest in previous_manifests:
        owner = previous_manifest.get('package', {}).get('name')
        if (owner not in ('glibc-cross-m64', 'glibc-cross-m32') or owner in manifests_by_owner
                or previous_manifest.get('schema') != 'alpbahOS.package-files/v1'
                or previous_manifest.get('package', {}).get('version') != recipe.get('version')):
            raise RuntimeError('Previous bootstrap Glibc manifest identity is invalid')
        manifests_by_owner[owner] = previous_manifest
        entries = previous_manifest.get('entries', [])
        old_entries_by_owner[owner] = {entry['path']: entry for entry in entries
                                       if entry.get('type') != 'directory'}
        old_directories_by_owner[owner] = {entry['path'] for entry in entries
                                           if entry.get('type') == 'directory'}
    if not manifests_by_owner:
        raise RuntimeError('Accepted bootstrap Glibc manifests are missing')
    root, result = Path(root), Path(result)
    db = root / 'var/lib/alp/db.json'
    for path in (root, db.parent, result):
        if path.is_symlink() or path.resolve() != path:
            raise RuntimeError('Glibc ownership handoff path is aliased')
    if not result.is_dir():
        raise RuntimeError('Glibc ownership receipt directory is missing')
    receipt = result / 'glibc-bootstrap-ownership-transfer.json'
    if receipt.exists() or receipt.is_symlink():
        raise RuntimeError('Existing Glibc ownership transfer receipt; preserve attempt')
    if db.is_symlink() or not db.is_file():
        raise RuntimeError('Alp DB is missing or aliased during Glibc ownership handoff')
    raw_db = db.read_bytes()
    database = json.loads(raw_db)
    if database.get('schema_version') != 1 or not isinstance(database.get('packages'), dict):
        raise RuntimeError('Unsupported Alp database during Glibc ownership handoff')
    packages = database['packages']
    for owner in manifests_by_owner:
        if owner not in packages or packages[owner].get('status') != 'installed':
            raise RuntimeError('Bootstrap Glibc owner is not installed: ' + owner)
    run_id = result.parent.name
    if not re.fullmatch(r'[0-9a-f]{32}', run_id):
        raise RuntimeError('Glibc ownership transfer is not bound to a base run')
    prior_db_sha = hashlib.sha256(raw_db).hexdigest()
    db_stat = db.stat(follow_symlinks=False)
    claims_by_owner = {}
    for owner in manifests_by_owner:
        record = packages[owner]
        claims = {str(path) if str(path).startswith('/') else '/' + str(path)
                  for field in ('files', 'symlinks') for path in record.get(field, [])}
        # Alp records created directories in `files`, but omits shared dirs.
        if claims - old_directories_by_owner[owner] != set(old_entries_by_owner[owner]):
            raise RuntimeError('Accepted Glibc manifest differs from DB ownership: ' + owner)
        claims_by_owner[owner] = claims
    transfer_owners = {}
    for owner, claims in claims_by_owner.items():
        for path in claims & set(new_entries):
            transfer_owners.setdefault(path, set()).add(owner)
    transfer_paths = sorted(transfer_owners)
    if not transfer_paths:
        raise RuntimeError('Base Glibc has no paths to take over from bootstrap Glibc')
    for path in transfer_paths:
        owners = {owner for owner, record in packages.items()
                  if any(str(item).lstrip('/') == path.lstrip('/')
                         for field in ('files', 'symlinks') for item in record.get(field, []))}
        if owners != transfer_owners[path]:
            raise RuntimeError('Shared Glibc path has unverified Alp owners: ' + path)
        entries = [old_entries_by_owner[owner][path] for owner in sorted(transfer_owners[path])]
        if any(entry != entries[0] for entry in entries[1:]):
            raise RuntimeError('Bootstrap Glibc owners disagree on shared payload: ' + path)
    old_entries = {path: old_entries_by_owner[sorted(transfer_owners[path])[0]][path]
                   for path in transfer_paths}
    transfer_set = set(transfer_paths)
    for owner in manifests_by_owner:
        record = packages[owner]
        record['files'] = [path for path in record.get('files', [])
                           if ('/' + str(path).lstrip('/')) not in transfer_set]
        record['symlinks'] = [path for path in record.get('symlinks', [])
                              if ('/' + str(path).lstrip('/')) not in transfer_set]
    updated_db = (json.dumps(database, sort_keys=True, indent=2) + '\n').encode()

    def atomic_db_write(raw):
        fd, name = tempfile.mkstemp(prefix='.db.json.glibc-transfer-', dir=str(db.parent))
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

    backup_dir = root / ('var/tmp/alp-infra-glibc-handoff-' + run_id)
    if os.path.lexists(backup_dir) or backup_dir.is_symlink():
        raise RuntimeError('Existing Glibc ownership backup; preserve attempt')
    backup_dir.parent.mkdir(parents=True, exist_ok=True)
    if backup_dir.parent.is_symlink() or root not in backup_dir.parent.resolve().parents:
        raise RuntimeError('Glibc ownership backup directory escapes install root')
    backup_dir.mkdir(mode=0o700)
    original_db = backup_dir / 'db.json.original'
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
    moved_paths = []
    committed = False
    try:
        # Keep exact originals until Alp has installed and claimed all shared paths.
        atomic_db_write(updated_db)
        for raw_path in transfer_paths:
            entry = old_entries[raw_path]
            target = root / raw_path.lstrip('/')
            parent = target.parent.resolve()
            if parent != root and root not in parent.parents:
                raise RuntimeError('Existing Glibc payload path escapes install root: ' + raw_path)
            ancestor = target.parent
            while ancestor != root:
                if ancestor.is_symlink():
                    raise RuntimeError('Bootstrap payload has a symlink parent: ' + raw_path)
                ancestor = ancestor.parent
            if target.is_symlink() or not os.path.lexists(target):
                if entry['type'] == 'symlink' and target.is_symlink():
                    pass
                else:
                    raise RuntimeError('Existing bootstrap payload is missing or aliased: ' + raw_path)
            current_stat = target.lstat()
            if (stat.S_IMODE(current_stat.st_mode) != entry.get('mode')
                    or current_stat.st_uid != entry.get('uid') or current_stat.st_gid != entry.get('gid')):
                raise RuntimeError('Bootstrap payload metadata changed: ' + raw_path)
            if entry['type'] == 'file':
                if (not target.is_file() or current_stat.st_size != entry.get('size')
                        or sha(target) != entry.get('sha256')):
                    raise RuntimeError('Bootstrap payload bytes changed: ' + raw_path)
            elif entry['type'] == 'symlink':
                if not target.is_symlink() or os.readlink(target) != entry.get('target'):
                    raise RuntimeError('Bootstrap symlink changed: ' + raw_path)
            else:
                raise RuntimeError('Unsupported bootstrap payload type: ' + raw_path)
            backup = backup_dir / raw_path.lstrip('/')
            backup.parent.mkdir(parents=True, exist_ok=True)
            moved_paths.append((target, backup))
            os.replace(target, backup)
        installed = installer(recipe, built, root, result)
        current_db = json.loads(db.read_bytes())
        if 'glibc' not in current_db.get('packages', {}):
            raise RuntimeError('Base Glibc did not claim shared bootstrap payload in Alp DB')
        glibc = current_db['packages']['glibc']
        package_install.ownership_check(root, value, current_db['packages'], 'glibc')
        evidence = {'schema': 'alpbahOS.glibc-bootstrap-ownership-transfer/v2',
                    'run_id': run_id, 'paths': transfer_paths,
                    'from_packages': sorted({owner for owners in transfer_owners.values()
                                             for owner in owners}), 'to_package': 'glibc',
                    'prior_db_sha256': prior_db_sha,
                    'manifest_sha256': built['manifest_sha256'],
                    'previous_manifest_sha256': {owner: fingerprint(manifests_by_owner[owner])
                                                 for owner in sorted(manifests_by_owner)},
                    'paths_by_package': {owner: sorted(path for path in transfer_paths
                                                       if owner in transfer_owners[path])
                                         for owner in sorted(manifests_by_owner)},
                    'path_count': len(transfer_paths), 'result': 'TRANSFERRED'}
        for parent in {target.parent for target, _ in moved_paths} | {db.parent}:
            dirfd = os.open(parent, os.O_RDONLY | getattr(os, 'O_DIRECTORY', 0))
            try:
                os.fsync(dirfd)
            finally:
                os.close(dirfd)
        with receipt.open('x') as stream:
            json.dump(evidence, stream, sort_keys=True, indent=2)
            stream.write('\n')
            stream.flush()
            os.fsync(stream.fileno())
        dirfd = os.open(result, os.O_RDONLY | getattr(os, 'O_DIRECTORY', 0))
        try:
            os.fsync(dirfd)
        finally:
            os.close(dirfd)
        committed = True
        shutil.rmtree(backup_dir)
        return installed
    except BaseException:
        if committed:
            raise
        for target, backup in reversed(moved_paths):
            if backup.exists() or backup.is_symlink():
                if os.path.lexists(target):
                    if target.is_dir() and not target.is_symlink():
                        raise RuntimeError('Unsafe directory appeared during Glibc ownership rollback')
                    target.unlink()
                target.parent.mkdir(parents=True, exist_ok=True)
                os.replace(backup, target)
            elif not os.path.lexists(target):
                raise RuntimeError('Bootstrap payload disappeared during Glibc ownership rollback')
        if original_db.exists():
            if db.exists() or db.is_symlink():
                db.unlink()
            os.replace(original_db, db)
        if not moved_paths:
            shutil.rmtree(backup_dir, ignore_errors=True)
        elif all(not backup.exists() and not backup.is_symlink() for _, backup in moved_paths):
            shutil.rmtree(backup_dir, ignore_errors=True)
        raise


def prepare_m32_kernel_headers(argv, header_include='/srv/lfs/build/.m32-kernel-uapi/include'):
    """Use the LFS 32-bit compiler and isolate Glibc's kernel-header view."""
    argv = list(argv)
    configure = any(value in ('configure', './configure', '../configure')
                    or value.endswith('/configure') for value in argv)
    glibc_configure = '../configure' in argv
    for index, value in enumerate(argv):
        if value == M32_HOST_C_COMPILER or value.startswith(M32_HOST_C_COMPILER + ' '):
            argv[index] = M32_C_COMPILER + value[len(M32_HOST_C_COMPILER):]
        elif value == M32_HOST_CXX_COMPILER or value.startswith(M32_HOST_CXX_COMPILER + ' '):
            argv[index] = M32_CXX_COMPILER + value[len(M32_HOST_CXX_COMPILER):]
        if glibc_configure and argv[index] in (M32_C_COMPILER, M32_CXX_COMPILER):
            argv[index] += ' -I' + header_include
    if not configure:
        return argv
    m32_cflags = any(value.startswith('CFLAGS=')
                     and re.search(r'(?:^|\s)-m32(?:\s|$)', value.partition('=')[2])
                     for value in argv)
    configured_m32_cc = any(value.startswith('CC=') and ' -m32' in value for value in argv)
    if m32_cflags and not configured_m32_cc:
        configure_index = next(index for index, value in enumerate(argv)
                               if value in ('configure', './configure', '../configure')
                               or value.endswith('/configure'))
        argv.insert(configure_index, M32_C_COMPILER)
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
    argv = use_staged_file_magic_compiler(argv, cwd)
    env = readline_ncurses_environment(argv, cwd, env)
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


def install_staged_with_glibc_handoff(recipe, built, root, result, reinstall=False):
    if recipe.get('name') == 'glibc':
        previous_manifests = [accepted_glibc_cross_m64_manifest(root, package_install),
                              accepted_glibc_cross_m32_manifest(root, package_install)]
        return handoff_glibc_bootstrap_owners(
            recipe, built, root, result, _install_staged, package_install, previous_manifests)
    return _install_staged(recipe, built, root, result, reinstall=reinstall)


import package_install
guest_base.install_staged = install_staged_with_glibc_handoff

# The canonical LFS sequence builds Readline before Ncurses although Readline
# links against it. Prebuild Ncurses into its normal package evidence/stage;
# the sequence still installs it later at its canonical position.
if hasattr(guest_base, 'current_binding'):
    bootstrap_ncurses_bundle(guest_base, package_stage)

guest_base.main()
