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


def prepare_m32_kernel_headers(argv, header_include='/srv/lfs/usr/include'):
    """Point the Builder's 32-bit compiler at the pinned LFS kernel headers."""
    argv = list(argv)
    if '../configure' not in argv or 'CC=gcc -m32' not in argv:
        return argv
    for index, value in enumerate(argv):
        if value == 'CC=gcc -m32':
            argv[index] = value + ' -I' + header_include
        elif value == 'CXX=g++ -m32':
            argv[index] = value + ' -I' + header_include
    return argv


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
    if ('CC=gcc -m32 -I/srv/lfs/usr/include' in argv
            and not Path('/srv/lfs/usr/include/asm/errno.h').is_file()):
        raise RuntimeError('Pinned LFS 32-bit kernel header is missing')
    if (len(argv) >= 3 and argv[0] == package_stage.RUNUSER
            and argv[1:3] == ['-u', 'root']):
        tree = root_test_tree(cwd)
        _run(['chown', '-hR', 'root:root', str(tree)], log)
    return _run(argv, log, cwd=cwd, env=env)


package_stage.run = run_with_root_owned_test_tree
import guest_base

guest_base.main()
