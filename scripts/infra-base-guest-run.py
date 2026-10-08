#!/usr/bin/env python3
"""Run the base guest with source-root-relative separate-build directories."""
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
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
    """Expose staged Ncurses to Readline through explicit linker search paths."""
    if cwd is None or Path(cwd).resolve() != Path(build_dir).resolve():
        return env
    link_variables = [index for index, arg in enumerate(argv)
                      if arg == 'SHLIB_LIBS=-lncursesw']
    if not link_variables:
        return env
    stage = Path(stage_root)
    library_dirs = (stage / 'usr/lib', stage / 'usr/lib32')
    for directory in library_dirs:
        if directory.is_symlink() or not directory.is_dir() or directory.resolve() != directory:
            raise RuntimeError('Pinned staged Ncurses library directory is missing or unsafe')
    # GCC's LIBRARY_PATH is rewritten through a cross compiler's sysroot on
    # some targets. Pass -L directly in SHLIB_LIBS so ld receives the staged
    # directories as-is. Search m32 first for the multilib build; GNU ld skips
    # an incompatible ELF class and then selects the m64 library when needed.
    search = ' '.join(f'-L{directory}' for directory in reversed(library_dirs))
    for index in link_variables:
        argv[index] = f'SHLIB_LIBS={search} -lncursesw'
    return env


def tcl_stub_archive_chmod(argv, cwd,
                           build_dir='/srv/lfs/build/base-tcl/unix',
                           stage_root='/srv/lfs/stage/base-tcl'):
    """Map Tcl's stale archive path to the installed stub archive, fail closed."""
    argv = list(argv)
    if cwd is None or Path(cwd).resolve() != Path(build_dir).resolve():
        return argv
    requested = Path(stage_root) / 'usr/lib/libtcl8.6.a'
    actual = Path(stage_root) / 'usr/lib/libtclstub8.6.a'
    if argv[-3:] != ['chmod', '644', str(requested)]:
        return argv
    stage, library = Path(stage_root), Path(stage_root) / 'usr/lib'
    if (stage.is_symlink() or stage.resolve() != stage or not stage.is_dir()
            or library.is_symlink() or library.resolve() != library or not library.is_dir()
            or requested.exists() or requested.is_symlink()
            or actual.is_symlink() or actual.resolve() != actual or not actual.is_file()):
        raise RuntimeError('Tcl stub archive staging layout is unexpected')
    argv[-1] = str(actual)
    return argv


def expect_lfs_tcl_sysroot(argv, cwd, env, lfs_root='/srv/lfs',
                           build_dir='/srv/lfs/build/base-expect'):
    """Translate LFS-root paths for Expect's unchrooted Builder configure.

    The book recipe is written for a chroot where /usr/lib and /usr/include
    are the target root. This isolated builder runs outside that root, so the
    configure probe must point at the accepted Tcl installation under LFS.
    The configured Tcl metadata still uses target-root /usr paths. Its static
    stub archive is outside the Builder's /usr, so configure also gets the
    verified LFS library directory as its link search path. The Builder's
    compiler must use the same sysroot: LFS's libc linker script names its
    libraries as absolute /usr/lib paths, which otherwise resolve against the
    Builder root and make configure's compiler probe fail.
    """
    argv = list(argv)
    if cwd is None or Path(cwd).resolve() != Path(build_dir).resolve():
        return argv, env, False

    root = Path(lfs_root)
    if root.is_symlink() or root.resolve() != root or not root.is_dir():
        raise RuntimeError('Expect Tcl sysroot is not the dedicated LFS root')
    libdir, includedir = root / 'usr/lib', root / 'usr/include'
    config, header, library = (libdir / 'tclConfig.sh', includedir / 'tcl.h',
                               libdir / 'libtcl8.6.so')
    stub_archive = libdir / 'libtclstub8.6.a'
    if (libdir.is_symlink() or includedir.is_symlink()
            or not libdir.is_dir() or not includedir.is_dir()
            or config.is_symlink() or not config.is_file()
            or header.is_symlink() or not header.is_file()
            or not library.is_file() or stub_archive.is_symlink()
            or not stub_archive.is_file()):
        raise RuntimeError('Accepted Tcl config, headers, shared library or stub archive are missing')
    root_real = root.resolve()
    for path in (config, header, library, stub_archive):
        resolved = path.resolve(strict=True)
        if root_real not in resolved.parents:
            raise RuntimeError('Tcl sysroot payload escapes the dedicated LFS root')

    configure_indexes = [index for index, value in enumerate(argv) if value == './configure']
    configure_applied = False
    updated_env = dict(env or {})
    updated_env.pop('LD_LIBRARY_PATH', None)
    if configure_indexes:
        replacements = {
            '--with-tcl=/usr/lib': '--with-tcl=' + str(libdir),
            '--with-tclinclude=/usr/include': '--with-tclinclude=' + str(includedir),
        }
        for original, replacement in replacements.items():
            if argv.count(original) != 1:
                raise RuntimeError('Expect configure arguments differ from the pinned Tcl recipe')
            argv[argv.index(original)] = replacement
        env_indexes = [index for index, value in enumerate(argv[:configure_indexes[0]])
                       if value == 'env']
        if len(env_indexes) != 1:
            raise RuntimeError('Expect configure is missing its bounded env wrapper')
        compiler = 'CC=gcc --sysroot=' + str(root)
        assignments = [index for index, value in enumerate(argv) if value.startswith('CC=')]
        if assignments:
            if len(assignments) != 1:
                raise RuntimeError('Expect configure has multiple compiler assignments')
            argv[assignments[0]] = compiler
        else:
            argv.insert(env_indexes[0] + 1, compiler)
        # tclConfig.sh intentionally keeps target-root /usr paths for use
        # inside the LFS chroot. Expect is configured outside that chroot, so
        # its -L/usr/lib -ltclstub8.6 would otherwise search the Builder's
        # host libraries. Pass the verified LFS sysroot and libdir to
        # configure's link probes and generated Makefile without exporting
        # target libraries to unrelated Builder executables.
        updated_env['LDFLAGS'] = '-L' + str(libdir)
        configure_applied = True

    # A target-LFS LD_LIBRARY_PATH is unsafe for Builder tools (runuser, Bash,
    # make, and configure all use the Builder's ABI).  Drop any inherited path
    # here. The test-only command below uses the LFS loader directly when
    # Tcl/Expect target programs actually run.
    return argv, updated_env, configure_applied


def expect_tclsh_command(build_dir='/srv/lfs/build/base-expect', lfs_root='/srv/lfs'):
    """Run target Tcl directly and sanitize its environment before tests spawn tools."""
    root, build = Path(lfs_root), Path(build_dir)
    if (root.is_symlink() or root.resolve() != root or not root.is_dir()
            or build.is_symlink() or build.resolve() != build or not build.is_dir()
            or build.parent != root / 'build'):
        raise RuntimeError('Expect build directory is not the dedicated LFS source tree')
    loader = root / 'usr/lib/ld-linux-x86-64.so.2'
    libdir = root / 'usr/lib'
    tclsh = root / 'usr/bin/tclsh8.6'
    tcl_library_dir = libdir / 'tcl8.6'
    tcl_library = tcl_library_dir / 'init.tcl'
    for path in (loader, tclsh):
        if path.is_symlink() or path.resolve() != path or not path.is_file() or not os.access(path, os.X_OK):
            raise RuntimeError('Target Tcl loader, executable or script library is missing or unsafe')
    if (tcl_library.is_symlink() or tcl_library.resolve() != tcl_library
            or not tcl_library.is_file() or not os.access(tcl_library, os.R_OK)):
        raise RuntimeError('Target Tcl script library is missing or unsafe')
    bootstrap = build / '.alp-tclsh-bootstrap.tcl'
    contents = ("set test_script [lindex $argv 0]\n"
                "if {$test_script eq \"\"} { error \"missing test script\" }\n"
                "set argv [lrange $argv 1 end]\n"
                "set argc [llength $argv]\n"
                "set argv0 $test_script\n"
                "unset -nocomplain env(LD_LIBRARY_PATH)\n"
                f"set env(TCL_LIBRARY) {{{tcl_library_dir}}}\n"
                "source $test_script\n")
    if bootstrap.exists() or bootstrap.is_symlink():
        if (bootstrap.is_symlink() or bootstrap.resolve() != bootstrap
                or not bootstrap.is_file() or bootstrap.read_text() != contents
                or bootstrap.stat().st_mode & 0o777 != 0o644):
            raise RuntimeError('Existing Expect Tcl bootstrap differs from the pinned adapter')
    else:
        with bootstrap.open('x') as stream:
            stream.write(contents)
        bootstrap.chmod(0o644)
    # Expect's Makefile sets LD_LIBRARY_PATH for every spawned child. Passing
    # Tcl through a shell wrapper makes that shell load the target LFS glibc,
    # while clearing the variable only after Tcl starts keeps Builder tools
    # such as cat, rm, and stty on the Builder's own ABI.
    return (f'TCL_LIBRARY={tcl_library_dir} {loader} --library-path {libdir} '
            f'{tclsh} {bootstrap}')


def expect_make_tclsh(argv, cwd, tclsh_command,
                      build_dir='/srv/lfs/build/base-expect'):
    """Make Expect tests invoke Tcl through the verified target loader/bootstrap."""
    argv = list(argv)
    if cwd is None or Path(cwd).resolve() != Path(build_dir).resolve():
        return argv
    try:
        command_start = argv.index('--') + 1
    except ValueError:
        return argv
    make_index = next((i for i in range(command_start, len(argv)) if argv[i] == 'make'), None)
    if make_index is None:
        return argv
    assignment = 'TCLSH_PROG=' + str(tclsh_command)
    existing = [i for i in range(make_index + 1, len(argv))
                if argv[i].startswith('TCLSH_PROG=')]
    if existing:
        if len(existing) != 1 or argv[existing[0]] != assignment:
            raise RuntimeError('Expect make command overrides the target Tcl adapter')
    else:
        argv.insert(make_index + 1, assignment)
    return argv


def ncurses_doc_parent_setup(argv, stage_root='/srv/lfs/stage/base-ncurses',
                            build_root='/srv/lfs/build/base-ncurses'):
    """Create Ncurses' documentation parent before its staged-only doc copy."""
    stage, build = Path(stage_root), Path(build_root)
    expected = ['cp', '-a', str(build / 'doc'),
                str(stage / 'usr/share/doc/ncurses-6.5-20250809')]
    if list(argv[-4:]) != expected:
        return []
    source = build / 'doc'
    if (stage.is_symlink() or stage.resolve() != stage or not stage.is_dir()
            or build.is_symlink() or build.resolve() != build or not build.is_dir()
            or source.is_symlink() or source.resolve() != source or not source.is_dir()):
        raise RuntimeError('Ncurses documentation stage/source path is missing or unsafe')
    for ancestor in (stage / 'usr', stage / 'usr/share'):
        if ancestor.exists() and (ancestor.is_symlink() or not ancestor.is_dir()
                                  or ancestor.resolve() != ancestor):
            raise RuntimeError('Ncurses documentation parent contains an unsafe path')
    parent = stage / 'usr/share/doc'
    if parent.exists():
        if (parent.is_symlink() or not parent.is_dir() or parent.resolve() != parent
                or (parent.stat().st_uid, parent.stat().st_gid)
                != (build.stat().st_uid, build.stat().st_gid)):
            raise RuntimeError('Ncurses documentation parent has unexpected owner or type')
        return []
    owner = build.stat()
    return [['mkdir', '-p', str(parent)],
            ['chown', f'{owner.st_uid}:{owner.st_gid}', str(parent)]]


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


def binutils_lfs_zlib_environment(argv, cwd,
                                  build_dir='/srv/lfs/build/base-binutils/build',
                                  lfs_root='/srv/lfs'):
    """Expose staged LFS zlib only to the unchrooted Binutils build."""
    command = list(argv)
    if cwd is None or Path(cwd).resolve() != Path(build_dir).resolve():
        return command
    # The pinned Binutils recipe is part of the already accepted toolchain
    # input digest, so keep its declared command unchanged.  Adapt only its
    # exact test invocation here: DejaGNU rebuilds target objects with the
    # configured path-map flags, and linker bootstrap checks need staged zlib.
    test_scripts = [index for index, value in enumerate(command)
                    if isinstance(value, str) and 'test-policy.py binutils' in value]
    if test_scripts:
        if len(test_scripts) != 1:
            raise RuntimeError('Binutils test adapter found an ambiguous test-policy command')
        script = command[test_scripts[0]]
        original = ("env -u SOURCE_DATE_EPOCH make CFLAGS='-O2 -g0' "
                    "CXXFLAGS='-O2 -g0' -j1 -k check")
        staged_zlib = str(Path(lfs_root) / 'stage/base-zlib/usr/lib')
        adapted = ("env -u SOURCE_DATE_EPOCH "
                   f"LIBRARY_PATH={staged_zlib} LD_LIBRARY_PATH={staged_zlib} make "
                   "CFLAGS='-O2 -g0' CXXFLAGS='-O2 -g0' "
                   "CFLAGS_FOR_TARGET='-g -O2 -g0' "
                   "CXXFLAGS_FOR_TARGET='-g -O2 -g0 -D_GNU_SOURCE' -j1 -k check")
        if script.count(original) != 1:
            raise RuntimeError('Binutils test command differs from the pinned recipe')
        command[test_scripts[0]] = script.replace(original, adapted)
    root = Path(lfs_root)
    header = root / 'usr/include/zlib.h'
    include = root / 'usr/include'
    # Search only the zlib package's isolated staging directory.  The merged
    # LFS library directory also contains glibc's linker script, whose absolute
    # /usr/lib references are invalid while linking against the Builder libc.
    library_dir = root / 'stage/base-zlib/usr/lib'
    library = library_dir / 'libz.so'
    if (root.is_symlink() or root.resolve() != root or not root.is_dir()
            or include.is_symlink() or include.resolve() != include
            or not include.is_dir() or header.is_symlink() or not header.is_file()
            or include not in header.resolve().parents
            or any(path.is_symlink() or path.resolve() != path
                   for path in (root / 'stage', root / 'stage/base-zlib',
                                root / 'stage/base-zlib/usr', library_dir))
            or not library_dir.is_dir() or not library.is_file()):
        raise RuntimeError('Installed LFS zlib headers or shared library are missing or aliased for Binutils')
    if any((library_dir / name).exists()
           for name in ('libc.so', 'libc.so.6', 'libc_nonshared.a',
                        'ld-linux-x86-64.so.2')):
        raise RuntimeError('Isolated LFS zlib staging directory contains Builder-shadowing system libraries')
    try:
        resolved_library = library.resolve(strict=True)
    except (OSError, RuntimeError) as error:
        raise RuntimeError('Installed LFS zlib shared library is missing or aliased for Binutils') from error
    if resolved_library.parent != library_dir:
        raise RuntimeError('Installed LFS zlib shared library escapes its library directory')
    prefix = ['/usr/sbin/runuser', '-u', 'lfs', '--', 'env']
    if command[:len(prefix)] != prefix:
        raise RuntimeError('Binutils LFS zlib adapter received an unexpected runner command')
    if any(item.startswith(('CC=', 'CXX=', 'LDFLAGS=')) for item in command[len(prefix):]):
        raise RuntimeError('Binutils compiler or linker flags already have an explicit override')
    # Binutils is built with the Builder's libc and its own headers.  A normal
    # -I here puts every staged LFS header ahead of both, mixing target and
    # Builder headers (notably glibc's obstack.h/stdlib.h).  The staged tree
    # must only be a fallback so zlib.h is available when Builder lacks it;
    # pass the same fallback to both C and C++ because gprofng compiles zlib.h
    # through CXX rather than CC.
    # Configure and libtool also need the staged m64 zlib library: this
    # Builder does not provide an unversioned libz for Binutils' -lz link.
    command.insert(len(prefix), 'CC=gcc -idirafter ' + str(include))
    command.insert(len(prefix) + 1, 'CXX=g++ -idirafter ' + str(include))
    command.insert(len(prefix) + 2, 'LDFLAGS=-L' + str(library_dir))
    return command


def shared_library_dependency_view(library, view):
    """Copy a verified shared library and its aliases without libtool metadata."""
    library, view = Path(library), Path(view)
    libdir = library.parent
    resolved = library.resolve(strict=True)
    expected = {resolved.name}
    aliases = {}
    for source in sorted(libdir.glob(library.name + '*')):
        if source.resolve(strict=True) != resolved:
            raise RuntimeError('Native dependency shared-library alias has an unexpected target')
        if source.is_symlink():
            aliases[source.name] = resolved.name
            expected.add(source.name)
        elif source != resolved:
            raise RuntimeError('Native dependency has an unexpected shared-library file')
    # These guest-only directories are owned by the orchestrator, outside all
    # package stages. No accepted package file or .la sidecar is modified.
    for directory in reversed((view, *view.parents)):
        if directory.is_symlink() or directory.resolve() != directory:
            raise RuntimeError('Native dependency view directory is aliased')
        if not directory.exists():
            directory.mkdir()
        if not directory.is_dir():
            raise RuntimeError('Native dependency view path is not a directory')
    if view.stat().st_uid != os.geteuid():
        raise RuntimeError('Native dependency view has an unexpected owner')
    if any(path.name not in expected for path in view.iterdir()):
        raise RuntimeError('Native dependency view contains unexpected files or libtool metadata')
    target = view / resolved.name
    if target.is_symlink():
        raise RuntimeError('Native dependency view payload is aliased')
    if target.exists():
        if not target.is_file() or target.read_bytes() != resolved.read_bytes():
            raise RuntimeError('Native dependency view payload differs from its stage')
    else:
        with target.open('xb') as output, resolved.open('rb') as source:
            shutil.copyfileobj(source, output)
        shutil.copystat(resolved, target)
    for name, destination in aliases.items():
        alias = view / name
        if alias.is_symlink():
            if os.readlink(alias) != destination:
                raise RuntimeError('Native dependency view alias changed')
        elif alias.exists():
            raise RuntimeError('Native dependency view alias is not a symlink')
        else:
            alias.symlink_to(destination)
    return view


def acl_dependency_library_directory(argv, build):
    """Select Attr's ABI from ACL's configure command or generated compiler."""
    m32_compilers = ('gcc -m32', M32_C_COMPILER.removeprefix('CC='))
    if './configure' in argv:
        compilers = [value for value in argv if value.startswith('CC=')]
        if compilers and (len(compilers) != 1
                          or compilers[0].removeprefix('CC=') not in m32_compilers):
            raise RuntimeError('ACL dependency adapter received an unexpected compiler')
        return 'lib32' if compilers else 'lib'
    status = Path(build) / 'config.status'
    if status.is_symlink() or not status.is_file() or status.resolve() != status:
        raise RuntimeError('ACL configured compiler metadata is missing or aliased')
    if status.stat().st_size > 8 * 1024 * 1024:
        raise RuntimeError('ACL configured compiler metadata is unexpectedly large')
    compilers = re.findall(r'^S\["CC"\]="([^"\n]+)"$', status.read_text(), re.MULTILINE)
    if len(compilers) != 1 or compilers[0] not in ('gcc', *m32_compilers):
        raise RuntimeError('ACL dependency adapter received an unexpected configured compiler')
    return 'lib32' if compilers[0] in m32_compilers else 'lib'


def native_staged_dependency_environment(argv, cwd, lfs_root='/srv/lfs'):
    """Give unchrooted native builds only their isolated staged dependencies."""
    command = list(argv)
    root = Path(lfs_root)
    consumers = {
        root / 'build/base-mpfr': ('gmp',),
        root / 'build/base-mpc': ('gmp', 'mpfr'),
        root / 'build/base-gcc/build': ('gmp', 'mpfr', 'mpc', 'zlib'),
        root / 'build/base-acl': ('attr',),
        root / 'build/base-coreutils': ('attr', 'acl'),
    }
    dependencies = consumers.get(Path(cwd).resolve()) if cwd is not None else None
    if dependencies is None:
        return command
    # Recipe pre/post actions do not use the env wrapper and need no link paths.
    if len(command) < 5 or command[4] != 'env':
        return command
    coreutils_root_tests = (Path(cwd).resolve() == root / 'build/base-coreutils'
                            and command[2] == 'root')
    if (command[0] != '/usr/sbin/runuser' or command[1] != '-u'
            or (command[2] not in ('lfs', 'tester') and not coreutils_root_tests)
            or command[3] != '--'):
        raise RuntimeError('Native math dependency adapter received an unexpected runner')
    variables = ('CPPFLAGS=', 'LDFLAGS=', 'LD_LIBRARY_PATH=', 'LIBRARY_PATH=')
    if any(value.startswith(variables) for value in command[5:]):
        raise RuntimeError('Native math dependency flags already have an explicit override')
    headers = {'gmp': 'gmp.h', 'mpfr': 'mpfr.h', 'mpc': 'mpc.h', 'zlib': 'zlib.h',
               'attr': 'attr/error_context.h', 'acl': 'sys/acl.h'}
    libraries = {'gmp': 'libgmp.so', 'mpfr': 'libmpfr.so',
                 'mpc': 'libmpc.so', 'zlib': 'libz.so',
                 'attr': 'libattr.so', 'acl': 'libacl.so'}
    library_directory = (acl_dependency_library_directory(command, root / 'build/base-acl')
                         if dependencies == ('attr',) else 'lib')
    includes, libdirs = [], []
    for name in dependencies:
        stage = root / ('stage/base-' + name)
        include, libdir = stage / 'usr/include', stage / 'usr' / library_directory
        for directory in (root, root / 'stage', stage, stage / 'usr', include, libdir):
            if (directory.is_symlink() or directory.resolve() != directory
                    or not directory.is_dir()):
                raise RuntimeError('Native dependency directory missing or aliased: ' + str(directory))
        header, library = include / headers[name], libdir / libraries[name]
        if header.is_symlink() or not header.is_file() or header.resolve() != header:
            raise RuntimeError('Native dependency header missing or aliased: ' + str(header))
        try:
            resolved = library.resolve(strict=True)
        except (OSError, RuntimeError) as error:
            raise RuntimeError('Native dependency shared library missing: ' + str(library)) from error
        if not resolved.is_file() or resolved.parent != libdir:
            raise RuntimeError('Native dependency shared library escapes its stage: ' + str(library))
        if (any((libdir / item).exists() or (libdir / item).is_symlink()
                for item in ('libc.so', 'libc.so.6', 'libc_nonshared.a',
                             'ld-linux-x86-64.so.2'))
                or any((include / item).exists() or (include / item).is_symlink()
                       for item in ('stdio.h', 'stdlib.h', 'string.h', 'unistd.h'))):
            raise RuntimeError('Native dependency stage contains Builder-shadowing system files')
        view = shared_library_dependency_view(
            library, root / ('build/.native-dependency-libs/' + name
                             + ('-m32' if library_directory == 'lib32' else '')))
        includes.append(str(include)); libdirs.append(str(view))
    command[5:5] = ['CPPFLAGS=' + ' '.join('-I' + path for path in includes),
                    'LD_LIBRARY_PATH=' + ':'.join(libdirs),
                    'LIBRARY_PATH=' + ':'.join(libdirs)]
    if coreutils_root_tests:
        # Nested runuser drops LD_LIBRARY_PATH. Restore only the isolated
        # dependency view for the unchanged book tester suite.
        original = 'runuser -u tester -- env "PATH=$test_path" LC_ALL=C.UTF-8'
        if command[-3:-1] != ['bash', '-euc'] or command[-1].count(original) != 1:
            raise RuntimeError('Coreutils root/tester command differs from the pinned recipe')
        command[-1] = command[-1].replace(
            original, 'runuser -u tester -- env "PATH=$test_path" '
            'LD_LIBRARY_PATH=' + ':'.join(libdirs) + ' LC_ALL=C.UTF-8')
    # GCC finds the view through LIBRARY_PATH, without exporting -L build
    # paths into installed .la dependency_libs. The view excludes .la files,
    # so Libtool cannot follow their target /usr/lib paths on the Builder.
    return command


def parallel_glibc_tests(argv, cwd, build_dir='/srv/lfs/build/base-glibc/build'):
    """Use the recipe's four-job budget for the complete critical test suite."""
    command = list(argv)
    if cwd is None or Path(cwd).resolve() != Path(build_dir).resolve():
        return command
    scripts = [index for index, value in enumerate(command)
               if isinstance(value, str) and 'test-policy.py glibc' in value]
    if not scripts:
        return command
    original = 'set +e; make -k check with-lld=; make_exit=$?; set -e; '
    if len(scripts) != 1 or command[scripts[0]].count(original) != 1:
        raise RuntimeError('Glibc test command differs from the pinned recipe')
    command[scripts[0]] = command[scripts[0]].replace(
        original, 'set +e; make -j4 -k check with-lld=; make_exit=$?; set -e; ')
    return command


def glibc_deterministic_archive_commands(argv, stage_root='/srv/lfs/stage/base-glibc'):
    """Normalize m32 ar symbol indexes before manifest/archive capture."""
    if list(argv[:2]) != ['python3', '/opt/alp-infra/scripts/capture-package-manifest.py']:
        return []
    if '--name' not in argv:
        return []
    name_index = argv.index('--name') + 1
    if name_index >= len(argv):
        raise RuntimeError('Glibc archive normalization received an unexpected capture command')
    if argv[name_index] != 'glibc':
        return []
    stage = Path(stage_root)
    if (list(argv).count('--stage') != 1
            or argv.index('--stage') + 1 >= len(argv)
            or argv[argv.index('--stage') + 1] != str(stage)
            or list(argv).count('--name') != 1):
        raise RuntimeError('Glibc archive normalization received an unexpected capture command')
    directory = stage / 'usr/lib32'
    for path in (stage, stage / 'usr', directory):
        if path.is_symlink() or path.resolve() != path or not path.is_dir():
            raise RuntimeError('Glibc archive normalization directory is missing or aliased')
    commands = []
    for name in ('libBrokenLocale.a', 'libc.a', 'libc_nonshared.a',
                 'libg.a', 'libm.a', 'libresolv.a'):
        archive = directory / name
        if archive.is_symlink() or not archive.is_file() or archive.stat().st_uid != os.geteuid():
            raise RuntimeError('Glibc static archive is missing, aliased or foreign-owned')
        with archive.open('rb') as stream:
            if stream.read(8) != b'!<arch>\n':
                raise RuntimeError('Glibc static archive has an unexpected format')
        commands.append(['/usr/bin/ranlib', '-D', str(archive)])
    return commands


def gmp_gcc15_configure_compatibility(argv, cwd, gcc_version,
                                      build_dir='/srv/lfs/build/base-gmp'):
    """Apply GMP's configure sed workaround only on the GCC versions that need it."""
    command = list(argv)
    if cwd is None or Path(cwd).resolve() != Path(build_dir).resolve():
        return command, None
    expected = ['/usr/sbin/runuser', '-u', 'lfs', '--', 'sed', '-i',
                '/long long t1;/,+1s/()/(...)/', 'configure']
    if command != expected:
        return command, None
    match = re.match(r'^\s*(\d+)(?:\.|$)', str(gcc_version))
    if not match:
        raise RuntimeError('GMP configure adapter could not parse the guest GCC version')
    major = int(match.group(1))
    if major < 15:
        # The pinned MLFS edit changes a C function prototype to the GCC-15
        # compatibility form. GCC 12 rejects that form as invalid ISO C.
        return ['/usr/bin/true'], f'BUILD_ADAPTER gmp-gcc15-sed=skipped guest-gcc={gcc_version}'
    return command, f'BUILD_ADAPTER gmp-gcc15-sed=kept guest-gcc={gcc_version}'


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
    argv = binutils_lfs_zlib_environment(argv, cwd)
    original = argv
    argv = native_staged_dependency_environment(argv, cwd)
    argv = parallel_glibc_tests(argv, cwd)
    if argv != original:
        with Path(log).open('ab') as output:
            output.write(('BUILD_ADAPTER native-dependencies-or-glibc-j4 cwd=' + str(cwd) + '\n').encode())
    gmp_pre = (cwd is not None and Path(cwd).resolve() == Path('/srv/lfs/build/base-gmp')
               and argv == ['/usr/sbin/runuser', '-u', 'lfs', '--', 'sed', '-i',
                            '/long long t1;/,+1s/()/(...)/', 'configure'])
    if gmp_pre:
        version = subprocess.run(['/usr/bin/gcc', '-dumpfullversion'], check=True,
                                 capture_output=True, text=True).stdout.strip()
        argv, message = gmp_gcc15_configure_compatibility(argv, cwd, version)
        if message:
            with Path(log).open('ab') as output:
                output.write((message + '\n').encode())
    argv = disable_unavailable_m32_cxx(argv, cwd)
    argv = use_staged_file_magic_compiler(argv, cwd)
    env = readline_ncurses_environment(argv, cwd, env)
    argv = tcl_stub_archive_chmod(argv, cwd)
    argv, env, expect_tcl_adapter = expect_lfs_tcl_sysroot(argv, cwd, env)
    if cwd is not None and Path(cwd).resolve() == Path('/srv/lfs/build/base-expect'):
        expect_command = expect_tclsh_command()
        argv = expect_make_tclsh(argv, cwd, expect_command)
    if expect_tcl_adapter:
        with Path(log).open('ab') as output:
            output.write(('BUILD_ADAPTER expect-configure=/srv/lfs/usr/lib/tclConfig.sh '
                          'include=/srv/lfs/usr/include/tcl.h '
                          'tclsh-command=' + str(expect_command) + '\n').encode())
    for setup_command in ncurses_doc_parent_setup(argv):
        _run(setup_command, log)
    for normalize_command in glibc_deterministic_archive_commands(argv):
        _run(normalize_command, log)
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
