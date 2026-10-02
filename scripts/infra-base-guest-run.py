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
import guest_base

guest_base.main()
