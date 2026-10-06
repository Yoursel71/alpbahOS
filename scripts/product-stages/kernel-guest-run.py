#!/usr/bin/env python3
"""Build, test, package and Alp-install the pinned kernel inside Builder."""
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

REPO = Path('/opt/alp-infra')
LFS = Path('/srv/lfs')
INFRA = Path('/srv/infra')
BOOT = Path('/proc/sys/kernel/random/boot_id')
RECIPE_PATH = REPO / 'scripts/product-stages/kernel.recipe.json'
RUNNER_PATH = REPO / 'scripts/product-stages/kernel-guest-run.py'
RESULTS = LFS / 'results/kernel'
RELEASE = '6.16.1-alpbahOS'
HEX32 = re.compile(r'[0-9a-f]{32}')
HEX64 = re.compile(r'[0-9a-f]{64}')

sys.path.insert(0, str(REPO / 'scripts/infra'))
import package_install
import package_stage


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def write_new(path, value):
    raw = (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()
    with Path(path).open('xb') as stream:
        stream.write(raw)
        stream.flush()
        os.fsync(stream.fileno())
    return hashlib.sha256(raw).hexdigest()


def remove_transient(path, parent):
    """Remove only a direct, canonical per-run build/stage directory in LFS."""
    path, parent = Path(path), Path(parent)
    if (os.geteuid() != 0 or parent not in (LFS / 'build', LFS / 'stage')
            or parent.is_symlink()
            or not parent.is_dir() or path.parent != parent or path.is_symlink()
            or path.resolve() != path or not re.fullmatch(r'[0-9a-f]{32}', path.name)
            or not path.is_dir()):
        raise RuntimeError('Transient cleanup path is not a direct private LFS run directory')
    shutil.rmtree(path)
    if path.exists() or path.is_symlink():
        raise RuntimeError('Transient per-run directory remains after cleanup')


def run(run_id, recipe_sha256):
    if os.geteuid() != 0 or not HEX32.fullmatch(run_id) or not HEX64.fullmatch(recipe_sha256):
        raise RuntimeError('Kernel guest runner identity/root invalid')
    if (RECIPE_PATH.is_symlink() or not RECIPE_PATH.is_file()
            or sha(RECIPE_PATH) != recipe_sha256 or RUNNER_PATH.is_symlink()
            or not RUNNER_PATH.is_file()):
        raise RuntimeError('Pinned kernel recipe/runner bytes missing or changed')
    recipe = json.loads(RECIPE_PATH.read_bytes())
    if (recipe.get('schema') != 'alpbahOS.recipe/v1' or recipe.get('name') != 'linux-kernel'
            or recipe.get('version') != RELEASE or recipe.get('phase') != 'base'
            or recipe.get('abi') != 'multilib-m32' or recipe.get('source') != 'linux-6.16.1.tar.xz'):
        raise RuntimeError('Kernel recipe identity differs from accepted product scope')
    inputs_path = INFRA / 'inputs.json'
    sources_path = REPO / 'manifests/infra-sources.json'
    inputs = json.loads(inputs_path.read_bytes())
    sources_raw = sources_path.read_bytes()
    sources = json.loads(sources_raw)
    source = package_stage.source_pin(sources, recipe['source'])
    source_path = LFS / 'sources' / source['filename']
    if (not HEX64.fullmatch(inputs.get('inputs_sha256', ''))
            or not HEX64.fullmatch(inputs.get('sources_sha256', ''))
            or sha(sources_path) != inputs['sources_sha256']
            or source_path.is_symlink() or sha(source_path) != source['sha256']):
        raise RuntimeError('Kernel source/input provenance mismatch')
    result = RESULTS / run_id
    if RESULTS.is_symlink() or not RESULTS.is_dir() or result.exists() or result.is_symlink():
        raise RuntimeError('Kernel result location missing, aliased or already used')
    result.mkdir(mode=0o700)
    boot_id = BOOT.read_text().strip()
    if not re.fullmatch(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', boot_id):
        raise RuntimeError('Kernel guest boot identity malformed')
    started = time.time_ns()
    built = package_stage.build_staged(recipe, run_id, result, jobs=recipe['jobs'])
    built = {**built, 'archive': str(built['archive']), 'manifest': str(built['manifest'])}
    built_sha = write_new(result / 'built.json', {'schema': 'alpbahOS.kernel-built/v1',
                                                   'run_id': run_id, 'recipe_sha256': recipe_sha256,
                                                   'built': built})
    bundle = package_install.validate_bundle(recipe, built)
    installed = package_install.install_staged(recipe, built, LFS, result)
    package_db = package_install.packages(LFS)
    record = package_db.get(recipe['name'])
    if (not isinstance(record, dict) or record.get('status') != 'installed'
            or record.get('version') != RELEASE or record.get('source', {}).get('sha256') != built['archive_sha256']):
        raise RuntimeError('Alp database does not own the accepted kernel package identity')
    package_install.ownership_check(LFS, bundle, package_db, recipe['name'])
    expected_boot = {'/boot/vmlinuz-' + RELEASE, '/boot/System.map-' + RELEASE,
                     '/boot/config-' + RELEASE}
    observed_paths = {entry['path'] for entry in bundle['entries'] if entry['type'] != 'directory'}
    if not expected_boot.issubset(observed_paths):
        raise RuntimeError('Kernel package lacks boot image/map/config ownership')
    db_raw = (LFS / 'var/lib/alp/db.json').read_bytes()
    db_path = result / 'db-final.json'
    with db_path.open('xb') as stream:
        stream.write(db_raw)
        stream.flush()
        os.fsync(stream.fileno())
    config = LFS / 'build' / run_id / '.config'
    release_file = LFS / 'build' / run_id / 'include/config/kernel.release'
    if (config.is_symlink() or not config.is_file() or not HEX64.fullmatch(sha(config))
            or release_file.is_symlink() or not release_file.is_file()
            or release_file.read_text().strip() != RELEASE):
        raise RuntimeError('Built kernel config/release evidence invalid')
    summary = {
        'schema': 'alpbahOS.kernel-guest/v1', 'result': 'PASS', 'stage': 'kernel',
        'run_id': run_id, 'guest_boot_id': boot_id, 'inputs_sha256': inputs['inputs_sha256'],
        'sources_sha256': inputs['sources_sha256'], 'source': source,
        'source_archive_sha256': sha(source_path), 'recipe_sha256': recipe_sha256,
        'runner_sha256': sha(RUNNER_PATH), 'kernel_release': RELEASE,
        'config_sha256': sha(config), 'config_options_required': 26,
        'archive': Path(built['archive']).name, 'archive_sha256': built['archive_sha256'],
        'manifest': Path(built['manifest']).name, 'manifest_sha256': built['manifest_sha256'],
        'built_record_sha256': built_sha,
        'manifest_entry_count': len(bundle['entries']), 'alp_package': recipe['name'],
        'alp_version': record['version'], 'alp_record_sha256': package_install.fingerprint(record),
        'alp_database_sha256': hashlib.sha256(db_raw).hexdigest(),
        'install_receipt_sha256': sha(result / 'linux-kernel.installed.json'),
        'build_log_sha256': sha(result / f'{run_id}.log'),
        'install_log_sha256': sha(result / 'linux-kernel.install.log'),
        'test': 'headers_check', 'result_directory': str(result),
        'started_at_ns': started, 'ended_at_ns': time.time_ns()
    }
    remove_transient(LFS / 'build' / run_id, LFS / 'build')
    remove_transient(LFS / 'stage' / run_id, LFS / 'stage')
    if (LFS / 'build' / run_id).exists() or (LFS / 'stage' / run_id).exists():
        raise RuntimeError('Kernel build/stage cleanup verification failed')
    summary['transient_build_removed'] = True
    summary['transient_stage_removed'] = True
    summary_sha = write_new(result / 'kernel-summary.json', summary)
    print(json.dumps({'result': 'PASS', 'summary': str(result / 'kernel-summary.json'),
                      'summary_sha256': summary_sha, 'archive_sha256': built['archive_sha256'],
                      'manifest_sha256': built['manifest_sha256'], 'alp_database_sha256': summary['alp_database_sha256']},
                     sort_keys=True))
    return summary


if __name__ == '__main__':
    try:
        if len(sys.argv) != 3:
            raise RuntimeError('Usage: kernel-guest-run.py RUN_ID RECIPE_SHA256')
        run(sys.argv[1], sys.argv[2])
    except (RuntimeError, OSError, subprocess.SubprocessError, ValueError, KeyError) as error:
        print('STOP: ' + str(error), file=sys.stderr)
        raise SystemExit(1)
