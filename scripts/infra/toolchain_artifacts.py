"""Toolchain raw package/DB/payload export; host byte verification follows.

No CLI, VM launch, Alp edit or acceptance certificate is emitted here.
Guest export reads the actual installed payload under the VM writer guard.
"""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
from package_install import guest_install_guard, verify_installed, canonical_key, packages
from package_stage import heavy_recipe_guard, sha

LFS = Path('/srv/lfs')
REPO = Path('/opt/alp-infra')


def exclusive(path, raw):
    if path.resolve() != path or path.is_symlink():
        raise RuntimeError('Toolchain export path aliased')
    with path.open('xb') as stream:
        stream.write(raw); stream.flush(); os.fsync(stream.fileno())


def json_record(path, value):
    exclusive(path, (json.dumps(value, sort_keys=True, indent=2) + '\n').encode())


def export_guest(plan, root, result, summary):
    """Full current prefix verification precedes any new exported evidence."""
    from guest_toolchain import ORDER, saved_bundle
    guest_install_guard(root, result)
    if root != LFS or tuple(r['name'] for r in plan) != ORDER:
        raise RuntimeError('Toolchain export root/sequence not allowlisted')
    if (result.resolve() != result or result.is_symlink() or result.name != summary.get('run_id')
            or result.parent != LFS / 'results/toolchain' or (result / 'summary.json').exists()):
        raise RuntimeError('Toolchain export requires fresh current job directory')
    binding = json.loads((result / 'inputs.json').read_bytes())
    if any(summary.get(k) != v for k, v in binding.items()) or summary.get('result') != 'PASS':
        raise RuntimeError('Toolchain export summary/current run binding changed')
    if set(packages(root)) != set(ORDER):
        raise RuntimeError('Toolchain export exact canonical package coverage missing')
    verified = []
    for recipe in plan:
        heavy_recipe_guard(recipe)
        directory = result / recipe['name']
        built = saved_bundle(recipe, directory, binding)
        verify_installed(recipe, built, root, directory)
        verified.append((recipe, built, directory))
    script = REPO / 'scripts/capture-package-manifest.py'
    if script.resolve() != script or script.is_symlink():
        raise RuntimeError('Unsafe installed payload measurement producer')
    spec = importlib.util.spec_from_file_location('infra_capture_observation', script)
    capture = importlib.util.module_from_spec(spec); spec.loader.exec_module(capture)
    db = root / 'var/lib/alp/db.json'
    db_before = sha(db)
    rows = []
    for recipe, built, directory in verified:
        manifest = json.loads(built['manifest'].read_bytes())
        observed = []
        for entry in manifest['entries']:
            relative = entry['path'].lstrip('/')
            canonical_key(root, relative)  # Parent aliases may never escape LFS.
            current = capture.entry_record(str(root / relative), relative)
            if current != entry:
                raise RuntimeError('Actual installed toolchain payload differs from bundle: ' + entry['path'])
            observed.append(current)
        json_record(directory / 'observed.json', {'schema': 'alpbahOS.installed-observation/v1',
                    'run_id': summary['run_id'], 'package': recipe['name'], 'root': str(root), 'entries': observed})
        rows.append({'package': recipe['name'], 'observed': recipe['name'] + '/observed.json',
                     'observed_sha256': sha(directory / 'observed.json')})
    raw = db.read_bytes()
    if hashlib.sha256(raw).hexdigest() != db_before:
        raise RuntimeError('Toolchain final raw DB changed during payload observation')
    exclusive(result / 'db-final.json', raw)
    if sha(db) != db_before or sha(result / 'db-final.json') != db_before:
        raise RuntimeError('Toolchain final raw DB snapshot drift')
    json_record(result / 'summary.json', {**summary, 'observations': rows, 'final_db_sha256': db_before})
