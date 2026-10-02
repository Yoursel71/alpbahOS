"""Guarded LFS Chapter 8 package sequence.

This guest-only runner starts from an accepted Chapter 4/5 checkpoint. It
preserves interrupted builds/installs and emits raw guest evidence only; the
host still has to verify bytes, audit the stopped VM, and issue acceptance.
"""
import hashlib
import importlib.util
import json
import os
import re
import time
from pathlib import Path

from base_plan import EXPECTED_COUNT, load as canonical_plan
from package_install import (canonical_key, fingerprint, guest_install_guard, install_staged,
                             packages, validate_bundle, verify_installed)
from package_stage import BOOT, REPO, LFS, INFRA, build_staged, heavy_recipe_guard, sha
from filesystem_layout import require_layout

TOOLCHAIN_ORDER = ('filesystem-layout', 'binutils-pass1', 'gcc-pass1', 'linux-headers',
                   'glibc-cross-m64', 'glibc-cross-m32', 'libstdcxx-cross')


def safe_json(path, value=None):
    if path.is_symlink() or path.resolve() != path:
        raise RuntimeError('Unsafe base-stage evidence path')
    if value is None:
        return json.loads(path.read_bytes())
    if path.exists():
        raise RuntimeError('Existing base-stage evidence preserved: ' + str(path))
    with path.open('x') as stream:
        stream.write(json.dumps(value, indent=2, sort_keys=True) + '\n')


def recipes(plan):
    if len(plan) != EXPECTED_COUNT:
        raise RuntimeError('Base sequence package count changed')
    output = []
    for row in plan:
        recipe = row.get('recipe_data')
        if not isinstance(recipe, dict) or recipe.get('name') != row.get('name'):
            raise RuntimeError('Base package recipe missing: ' + str(row.get('name')))
        output.append(recipe)
    if len({recipe['name'] for recipe in output}) != EXPECTED_COUNT:
        raise RuntimeError('Base sequence names are duplicated')
    return output


def saved_bundle(recipe, directory, binding):
    record = safe_json(directory / 'built.json')
    if record.get('binding') != binding or record.get('result') != 'BUILT':
        raise RuntimeError('Base build inputs changed; restore checkpoint')
    built = record['built']
    run_id = 'base-' + recipe['name']
    for field, suffix in (('archive', '.tar.gz'), ('manifest', '.json')):
        expected = directory / (run_id + suffix)
        if built.get(field) != str(expected):
            raise RuntimeError('Base bundle path changed')
        built[field] = expected
    validate_bundle(recipe, built)
    return built


def current_binding(plan, root):
    auth_path = INFRA / 'base-authorization.json'
    toolchain_path = INFRA / 'toolchain-acceptance.json'
    inputs_path = INFRA / 'inputs.json'
    for path in (auth_path, toolchain_path, inputs_path):
        if path.is_symlink() or not path.is_file() or path.resolve() != path:
            raise RuntimeError('Current base/toolchain authorization evidence missing or aliased')
    auth = json.loads(auth_path.read_bytes())
    toolchain = json.loads(toolchain_path.read_bytes())
    inputs = json.loads(inputs_path.read_bytes())
    boot_id = BOOT.read_text().strip()
    if (auth.get('schema') != 'alpbahOS.base-authorization/v1'
            or auth.get('result') != 'AUTHORIZED' or auth.get('stage') != 'base'
            or auth.get('guest_boot_id') != boot_id
            or toolchain.get('schema') != 'alpbahOS.toolchain-acceptance/v1'
            or toolchain.get('result') != 'PASS' or toolchain.get('stage') != 'toolchain'
            or toolchain.get('mode') != auth.get('mode')
            or inputs.get('inputs_sha256') != auth.get('inputs_sha256')
            or inputs.get('sources_sha256') != auth.get('sources_sha256')
            or not re.fullmatch(r'[0-9a-f]{32}', str(auth.get('run_id', '')))):
        raise RuntimeError('Base authorization is stale or belongs to another guest boot')
    sources_path = REPO / 'manifests/infra-sources.json'
    inventory_path = REPO / 'manifests/lfs-base-12.4-systemd.json'
    if (sha(sources_path) != inputs['sources_sha256']
            or inputs.get('inputs_sha256') != _current_inputs_digest()):
        raise RuntimeError('Base current build inputs/source manifest changed')
    plan_hash = fingerprint(plan)
    return {'schema': 'alpbahOS.base-guest-binding/v1',
            'run_id': auth['run_id'], 'guest_boot_id': boot_id,
            'mode': auth['mode'], 'inputs_sha256': inputs['inputs_sha256'],
            'sources_sha256': inputs['sources_sha256'], 'plan_sha256': plan_hash,
            'inventory_sha256': sha(inventory_path),
            'toolchain_acceptance_sha256': sha(toolchain_path),
            'base_authorization_sha256': sha(auth_path),
            'root': str(root)}


def _current_inputs_digest():
    # Import the canonical host/guest input enumerator without trusting a
    # second hand-maintained list of recipe and manifest inputs.
    from buildctl import inputs_digest
    return inputs_digest()


def run_sequence(plan, root, result):
    guest_install_guard(root, result)
    if root != LFS:
        raise RuntimeError('Base install requires the dedicated LFS guest root')
    require_layout(root)
    package_plan = recipes(plan)
    if fingerprint(plan) != fingerprint(canonical_plan(REPO)):
        raise RuntimeError('Base sequence differs from canonical inventory/recipe files')
    for recipe in package_plan:
        heavy_recipe_guard(recipe)
    binding = current_binding(plan, root)
    if result.is_symlink() or result.resolve() != result or result.name != binding['run_id']:
        raise RuntimeError('Unsafe or incorrectly named base result directory')
    result.mkdir(exist_ok=True)
    header = result / 'inputs.json'
    if header.exists():
        if safe_json(header) != binding:
            raise RuntimeError('Base sequence inputs changed; restore checkpoint')
    else:
        safe_json(header, binding)

    expected_initial = set(TOOLCHAIN_ORDER)
    installed = packages(root)
    if not expected_initial <= set(installed):
        raise RuntimeError('Base stage must start from the exact accepted toolchain checkpoint')
    actions, previous = [], []

    def verify_prefix():
        for recipe, built, directory in previous:
            verify_installed(recipe, built, root, directory)

    # Resume only a contiguous package prefix. An install-started marker with
    # no DB record is ambiguous and must be recovered from a checkpoint.
    gap = False
    base_names = {recipe['name'] for recipe in package_plan}
    expected_seen = set(TOOLCHAIN_ORDER)
    for recipe in package_plan:
        name = recipe['name']; directory = result / name
        installed_now = name in packages(root)
        receipt, attempt = directory / (name + '.installed.json'), directory / 'install-started.json'
        if not installed_now and (attempt.exists() or attempt.is_symlink()):
            raise RuntimeError('Interrupted Alp attempt needs checkpoint recovery; no automatic retry')
        if installed_now or receipt.exists() or receipt.is_symlink():
            if gap or not installed_now or not receipt.is_file():
                raise RuntimeError('Partial/non-prefix base install; restore checkpoint')
            built = saved_bundle(recipe, directory, binding)
            verify_installed(recipe, built, root, directory)
            previous.append((recipe, built, directory)); expected_seen.add(name)
        else:
            gap = True
    actual = set(packages(root))
    if actual != expected_seen:
        if actual - (expected_initial | base_names):
            raise RuntimeError('Unexpected package exists in the base checkpoint')
        if not expected_initial <= actual:
            raise RuntimeError('Accepted toolchain package set changed')
        if actual != expected_seen:
            raise RuntimeError('Base Alp DB is not the exact accepted contiguous prefix')

    # Rebuild prior in-memory state in canonical order after validation.
    previous = []
    for recipe in package_plan:
        verify_prefix()
        name = recipe['name']; directory = result / name
        if directory.is_symlink() or directory.resolve() != directory:
            raise RuntimeError('Aliased base package evidence directory')
        directory.mkdir(exist_ok=True)
        state = directory / 'built.json'
        if state.is_symlink():
            raise RuntimeError('Aliased base bundle record')
        if state.exists():
            built = saved_bundle(recipe, directory, binding)
        else:
            marker = directory / 'build-started.json'
            if marker.exists() or marker.is_symlink():
                raise RuntimeError('Interrupted base build has no verified bundle; restore checkpoint')
            safe_json(marker, binding)
            built = build_staged(recipe, 'base-' + name, directory)
            validate_bundle(recipe, built)
            saved = {k: str(v) if isinstance(v, Path) else v for k, v in built.items()}
            safe_json(state, {'binding': binding, 'result': 'BUILT', 'built': saved})
        if name in packages(root):
            verify_installed(recipe, built, root, directory)
            action = 'verified installed; no rebuild/reinstall'
        else:
            receipt = directory / (name + '.installed.json')
            if receipt.exists() or receipt.is_symlink():
                raise RuntimeError('Alp record missing with old install evidence; restore checkpoint')
            safe_json(directory / 'install-started.json', {'package': name, 'binding': binding})
            install_staged(recipe, built, root, directory)
            action = 'installed verified bundle'
        previous.append((recipe, built, directory))
        actions.append({'package': name, 'action': action,
                        'archive_sha256': built['archive_sha256'],
                        'manifest_sha256': built['manifest_sha256']})
    verify_prefix()
    final = packages(root)
    if set(final) != set(TOOLCHAIN_ORDER) | base_names:
        raise RuntimeError('Base final Alp DB package coverage differs from exact accepted package set')
    summary = {'schema': 'alpbahOS.base-guest/v1', 'result': 'PASS', **binding,
               'package_count': len(package_plan), 'packages': actions,
               'scope': 'guest Chapter 8 package sequence only; host audit/checkpoint/acceptance required'}
    safe_json(result / ('summary-' + str(time.time_ns()) + '.json'), summary)
    return summary


def export_guest(plan, root, result, summary):
    """Capture installed payload bytes and the actual raw Alp DB under guest lock."""
    guest_install_guard(root, result)
    package_plan = recipes(plan)
    if (root != LFS or result.resolve() != result or result.is_symlink()
            or result.name != summary.get('run_id') or summary.get('result') != 'PASS'):
        raise RuntimeError('Base export run/root binding invalid')
    binding = safe_json(result / 'inputs.json')
    if any(summary.get(k) != v for k, v in binding.items()):
        raise RuntimeError('Base export summary/input binding changed')
    if set(packages(root)) != set(TOOLCHAIN_ORDER) | {r['name'] for r in package_plan}:
        raise RuntimeError('Base export exact package coverage missing')
    verified = []
    for recipe in package_plan:
        heavy_recipe_guard(recipe)
        directory = result / recipe['name']
        built = saved_bundle(recipe, directory, binding)
        verify_installed(recipe, built, root, directory)
        verified.append((recipe, built, directory))
    capture_path = REPO / 'scripts/capture-package-manifest.py'
    if capture_path.resolve() != capture_path or capture_path.is_symlink():
        raise RuntimeError('Unsafe installed payload measurement producer')
    spec = importlib.util.spec_from_file_location('infra_capture_base_observation', capture_path)
    capture = importlib.util.module_from_spec(spec); spec.loader.exec_module(capture)
    db = root / 'var/lib/alp/db.json'; db_before = sha(db); rows = []
    for recipe, built, directory in verified:
        manifest = json.loads(Path(built['manifest']).read_bytes())
        observed = []
        for entry in manifest['entries']:
            relative = entry['path'].lstrip('/')
            canonical_key(root, relative)
            current = capture.entry_record(str(root / relative), relative)
            if current != entry:
                raise RuntimeError('Actual installed base payload differs from bundle: ' + entry['path'])
            observed.append(current)
        path = directory / 'observed.json'
        raw = (json.dumps({'schema': 'alpbahOS.installed-observation/v1',
                           'run_id': summary['run_id'], 'package': recipe['name'],
                           'root': str(root), 'entries': observed}, sort_keys=True, indent=2) + '\n').encode()
        with path.open('xb') as stream:
            stream.write(raw); stream.flush(); os.fsync(stream.fileno())
        rows.append({'package': recipe['name'], 'observed': recipe['name'] + '/observed.json',
                     'observed_sha256': sha(path)})
    raw_db = db.read_bytes()
    if hashlib.sha256(raw_db).hexdigest() != db_before or sha(db) != db_before:
        raise RuntimeError('Base raw Alp DB changed during payload observation')
    with (result / 'db-final.json').open('xb') as stream:
        stream.write(raw_db); stream.flush(); os.fsync(stream.fileno())
    full = {**summary, 'observations': rows, 'final_db_sha256': db_before}
    safe_json(result / 'summary.json', full)
    return full


def main():
    os.umask(0o022)
    plan = canonical_plan(REPO)
    package_plan = recipes(plan)
    for recipe in package_plan:
        heavy_recipe_guard(recipe)
    auth = safe_json(INFRA / 'base-authorization.json')
    run_id = auth['run_id']
    result_root = LFS / 'results/base'
    guest_install_guard(LFS, result_root)
    if result_root.resolve() != result_root or result_root.is_symlink():
        raise RuntimeError('Unsafe base results parent')
    result_root.mkdir(exist_ok=True)
    result = result_root / run_id
    summary = run_sequence(plan, LFS, result)
    export_guest(plan, LFS, result, summary)


if __name__ == '__main__':
    main()
