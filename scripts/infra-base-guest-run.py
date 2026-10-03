#!/usr/bin/env python3
"""Run the base guest with source-root-relative separate-build directories."""
import hashlib
import re
import sys
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
M32_CXX_COMPILER = 'CXX=/srv/lfs/tools/bin/x86_64-lfs-linux-gnu-g++ -m32'
M32_HOST_C_COMPILER = 'CC=gcc -m32'
M32_HOST_CXX_COMPILER = 'CXX=g++ -m32'


def uses_m32_uapi_configure(argv, header_include='/srv/lfs/build/.m32-kernel-uapi/include'):
    marker = ' -I' + header_include
    return ('../configure' in argv
            and any(value.startswith(('CC=', 'CXX='))
                    and ' -m32' in value and marker in value for value in argv))


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
    if uses_m32_uapi_configure(argv):
        install_m32_kernel_headers()
    if (len(argv) >= 3 and argv[0] == package_stage.RUNUSER
            and argv[1:3] == ['-u', 'root']):
        tree = root_test_tree(cwd)
        _run(['chown', '-hR', 'root:root', str(tree)], log)
    return _run(argv, log, cwd=cwd, env=env)


package_stage.run = run_with_root_owned_test_tree
import guest_base

guest_base.main()
