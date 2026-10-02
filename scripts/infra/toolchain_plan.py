"""Canonical pinned Chapter4/5 plan, shared by host and guest readers."""
import json
from package_stage import source_pin, validate_recipe

ORDER = ('filesystem-layout', 'binutils-pass1', 'gcc-pass1', 'linux-headers',
         'glibc-cross-m64', 'glibc-cross-m32', 'libstdcxx-cross')


def load(repo):
    manifest = json.loads((repo / 'manifests/infra-sources.json').read_bytes())
    plan, available = [], set()
    for name in ORDER:
        path = repo / 'recipes/toolchain' / (name + '.json')
        if not path.is_file() or path.is_symlink() or path.resolve() != path:
            raise RuntimeError('Unsafe/missing toolchain recipe')
        recipe = json.loads(path.read_bytes())
        if (recipe.get('name') != name or recipe.get('phase') != 'toolchain'
                or recipe.get('abi') != 'multilib-m32' or not set(recipe.get('requires', [])) <= available):
            raise RuntimeError('Toolchain identity/ABI/dependency order invalid')
        validate_recipe(recipe, recipe['jobs'])
        source_pin(manifest, recipe['source'], repo)
        available.add(name); plan.append(recipe)
    return plan
