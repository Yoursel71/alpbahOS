"""Minimal ml-12.4 usr-merge skeleton as a pinned, staged Alp core package.

The renderer writes only a new DESTDIR. Product mutation still goes through
the guest/OC/stability guards and the existing Alp installer, never direct ln
or mkdir against the product root.
"""
import json
import os
import re
import stat
import time
from pathlib import Path
from package_stage import heavy_recipe_guard, pack_staged, sha, source_pin
from package_install import guest_install_guard, ownership_check, packages, fingerprint

REPO = Path('/opt/alp-infra')
LFS = Path('/srv/lfs')
NAME = 'filesystem-layout'
VERSION = '12.4-ml32.1'
DIRECTORIES = {p: 0o755 for p in ('etc', 'var', 'usr', 'usr/bin', 'usr/lib', 'usr/sbin',
                                 'usr/lib32', 'lib64', 'tools')}
LINKS = {'bin': 'usr/bin', 'lib': 'usr/lib', 'sbin': 'usr/sbin', 'lib32': 'usr/lib32'}
FORBIDDEN = ['usr/lib64', 'usr/libx32', 'libx32']


def validate_layout(recipe):
    required = {'schema': 'alpbahOS.recipe/v1', 'name': NAME, 'version': VERSION,
                'kind': 'layout', 'phase': 'toolchain', 'abi': 'multilib-m32',
                'source': 'filesystem-layout.json', 'directories': DIRECTORIES,
                'symlinks': LINKS, 'forbidden_paths': FORBIDDEN}
    if any(recipe.get(k) != v for k, v in required.items()):
        raise RuntimeError('Layout differs from the approved m64+m32 path whitelist')


def pinned_recipe():
    manifest = json.loads((REPO / 'manifests/infra-sources.json').read_text())
    item = source_pin(manifest, 'filesystem-layout.json', REPO)
    recipe = json.loads((REPO / item['path']).read_text())
    validate_layout(recipe)
    return recipe, item


def render_layout(recipe, destination):
    """Host fixtures may use this pure renderer; no installed root is touched."""
    validate_layout(recipe)
    destination = Path(destination)
    if (destination.resolve() != destination or destination.exists() or destination.is_symlink()
            or not destination.parent.is_dir()):
        raise RuntimeError('Layout staging must be a new directory under a resolved parent')
    destination.mkdir(mode=0o755)
    destination.chmod(0o755)
    for name, mode in sorted(recipe['directories'].items()):
        path = destination / name
        path.mkdir(mode=mode)
        path.chmod(mode)
    for name, target in sorted(recipe['symlinks'].items()):
        (destination / name).symlink_to(target)
    return destination


def build_layout(recipe, run_id, result):
    validate_layout(recipe)
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._+-]*', run_id):
        raise RuntimeError('Invalid layout run identity')
    guest_install_guard(LFS, Path(result))
    heavy_recipe_guard(recipe)
    pinned, item = pinned_recipe()
    if fingerprint(recipe) != fingerprint(pinned):
        raise RuntimeError('Layout recipe differs from its canonical source pin')
    stage = LFS / 'stage' / run_id
    started = time.monotonic()
    render_layout(recipe, stage)
    sources = json.loads((REPO / 'manifests/infra-sources.json').read_text())
    env = {**os.environ, 'SOURCE_DATE_EPOCH': str(sources['source_date_epoch']),
           'LC_ALL': 'C', 'LANG': 'C', 'TZ': 'UTC'}
    return pack_staged(recipe, stage, Path(result), run_id, item, env,
                       round(time.monotonic() - started, 3))


def require_layout(root):
    """Read actual directory/link types and Alp claims before cross builds."""
    root = Path(root)
    if not root.is_dir() or root.resolve() != root or root.is_symlink():
        raise RuntimeError('Unresolved or missing layout root')
    recipe, item = pinned_recipe()
    for name in recipe['forbidden_paths']:
        if os.path.lexists(root / name):
            raise RuntimeError('Forbidden ABI/library layout path: ' + name)
    for name, mode in recipe['directories'].items():
        path = root / name
        if (path.is_symlink() or not path.is_dir() or path.resolve() != path
                or stat.S_IMODE(path.stat().st_mode) != mode):
            raise RuntimeError('Required real layout directory missing/changed: ' + name)
    for name, target in recipe['symlinks'].items():
        path = root / name
        if not path.is_symlink() or os.readlink(path) != target or not path.resolve().is_dir():
            raise RuntimeError('Required usr-merge alias missing/changed: ' + name)
    installed = packages(root)
    record = installed.get(NAME, {})
    if (record.get('status') != 'installed' or record.get('version') != VERSION
            or record.get('method') != 'core' or record.get('protected') is not True):
        raise RuntimeError('Protected Alp filesystem-layout package missing')
    entries = [{'path': '/' + name, 'type': 'symlink'} for name in LINKS]
    ownership_check(root, {'entries': entries}, installed, NAME)
