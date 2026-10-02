#!/usr/bin/env python3
"""Authorized Phase 2: j1/j16 SBU, deterministic CPU load, repeated zlib.

Not a production toolchain. Executes only via the guarded guest shell wrapper.
"""
import hashlib
import json
import multiprocessing
import os
import re
import subprocess
import time
from pathlib import Path
from package_stage import build_staged, sha, heavy_recipe_guard
from package_install import install_staged

REPO = Path('/opt/alp-infra')
LFS = Path('/srv/lfs')


def bundle_record(built, jobs=None):
    record = {key: built[key] for key in ('source', 'seconds', 'archive_sha256', 'manifest_sha256')}
    record.update(archive=built['archive'].name, manifest=built['manifest'].name)
    if jobs is not None:
        record['jobs'] = jobs
    return record


def install_pair(recipe, bundles, result):
    """Keep both raw DBs/evidence even when the reproducibility gate fails."""
    if len(bundles) != 2:
        raise RuntimeError('Two independently built bundles required')
    records = []
    for label, built in zip(('a', 'b'), bundles):
        root = LFS / f'stability-db-{label}'
        if root.exists() or root.is_symlink():
            raise RuntimeError('Existing stability DB root refused; restore checkpoint')
        root.mkdir()
        proof_dir = result / f'zlib-{label}'; proof_dir.mkdir()
        install_staged(recipe, built, root, proof_dir)
        raw = (root / 'var/lib/alp/db.json').read_bytes()
        saved = result / f'db-repro-{label}.json'; saved.write_bytes(raw)
        records.append({'root': str(root), 'db': saved.name,
                        'db_sha256': hashlib.sha256(raw).hexdigest(),
                        'receipt': f'zlib-{label}/{recipe["name"]}.installed.json',
                        'receipt_sha256': sha(proof_dir / f'{recipe["name"]}.installed.json')})
        if label == 'a':
            time.sleep(1.2)  # Must straddle a real clock tick, never normalize DB time.
    evidence = {'records': records, 'equal': records[0]['db_sha256'] == records[1]['db_sha256']}
    (result / 'db-repro-evidence.json').write_text(json.dumps(evidence, indent=2, sort_keys=True) + '\n')
    return evidence


def stress_worker(deadline, result):
    payload = b'alp-infra-stability-v1' * 51200
    expected = bytes.fromhex('0e0e543b78caf32700160436a2ec498e8b1d1098b015c21104364102f0ee9b9e')
    loops = 0
    while time.monotonic() < deadline:
        if hashlib.sha256(payload).digest() != expected:
            result.put({'ok': False, 'loops': loops})
            return
        loops += 1
    result.put({'ok': True, 'loops': loops})


def main():
    heavy_recipe_guard({'phase': 'stability'})
    authorization = json.loads(Path('/srv/infra/phase2-authorization.json').read_text())
    if authorization.get('mode') not in ('x86_64', 'multilib-m32') or authorization.get('oc_confirmed') is not True:
        raise SystemExit('No OC/ABI authorization')
    if not isinstance(authorization.get('run_id'), str) or not re.fullmatch('[0-9a-f]{32}', authorization['run_id']):
        raise SystemExit('No current stage run identity')
    manifest = json.loads((REPO / 'manifests/infra-sources.json').read_text())
    os.environ.update(SOURCE_DATE_EPOCH=str(manifest['source_date_epoch']),
                      ALP_REPRODUCIBLE_BUILD='1', LC_ALL='C', LANG='C', TZ='UTC')
    os.umask(0o022)
    start = time.monotonic()
    result = LFS / 'results/stability'
    result.mkdir()
    recipe = json.loads((REPO / 'recipes/bootstrap/binutils-sbu.json').read_text())
    measurements = []
    sbu_root = LFS / 'sbu-root'
    if sbu_root.exists() or sbu_root.is_symlink():
        raise SystemExit('Existing SBU root refused; restore checkpoint')
    sbu_root.mkdir()
    for jobs in (1, 16):
        built = build_staged(recipe, f'binutils-sbu-j{jobs}', result, jobs=jobs)
        proof_dir = result / f'sbu-j{jobs}'; proof_dir.mkdir()
        install_staged(recipe, built, sbu_root, proof_dir, reinstall=jobs == 16)
        (proof_dir / 'db.json').write_bytes((sbu_root / 'var/lib/alp/db.json').read_bytes())
        measurements.append({**bundle_record(built, jobs),
                             'receipt': f'sbu-j{jobs}/{recipe["name"]}.installed.json',
                             'db': f'sbu-j{jobs}/db.json',
                             'receipt_sha256': sha(proof_dir / f'{recipe["name"]}.installed.json')})
    # Keep the gate at least 20 minutes, bounded to 30 minutes externally.
    deadline = start + 1200
    queue = multiprocessing.Queue()
    children = [multiprocessing.Process(target=stress_worker, args=(deadline, queue)) for _ in range(16)]
    for child in children: child.start()
    for child in children: child.join(max(0, deadline - time.monotonic()) + 10)
    if any(child.is_alive() or child.exitcode != 0 for child in children):
        for child in children:
            if child.is_alive(): child.terminate()
        raise SystemExit('Possible OC instability: stress worker failed/timeout')
    results = [queue.get(timeout=5) for _ in children]
    if not all(item['ok'] and item['loops'] > 0 for item in results):
        raise SystemExit('Possible OC instability: arithmetic/hash mismatch')
    # Fresh unique zlib trees; no reuse of the Phase 1 build directories.
    smoke = json.loads((REPO / 'recipes/smoke/zlib.json').read_text())
    smoke['phase'] = 'stability'
    first = build_staged(smoke, 'zlib-oc-1', result)
    second = build_staged(smoke, 'zlib-oc-2', result)
    if first['archive_sha256'] != second['archive_sha256'] or first['manifest_sha256'] != second['manifest_sha256']:
        raise SystemExit('Possible OC instability/reproducibility fault: package hashes differ')
    db_evidence = install_pair(smoke, (first, second), result)
    elapsed = time.monotonic() - start
    if not 1200 <= elapsed <= 1800:
        raise SystemExit('Stability gate outside 20–30 minute window; do not accept')
    sources_path = REPO / 'manifests/infra-sources.json'
    inputs = json.loads(Path('/srv/infra/inputs.json').read_text())
    summary = {'result': 'PASS' if db_evidence['equal'] else 'FAIL_DB_REPRODUCIBILITY',
               'run_id': authorization['run_id'],
               'seconds': round(elapsed, 3), 'sbu': measurements, 'stress': results,
               'mode': authorization['mode'], 'inputs_sha256': inputs['inputs_sha256'],
               'sources_sha256': sha(sources_path), 'alp_sha256': manifest['alp']['sha256'],
               'source_date_epoch': manifest['source_date_epoch'],
               'zlib': [bundle_record(first), bundle_record(second)],
               'db_sha256': [r['db_sha256'] for r in db_evidence['records']],
               'scope': 'guest stability only; host audit/stage acceptance still required'}
    (result / 'summary.json').write_text(json.dumps(summary, indent=2, sort_keys=True) + '\n')
    print(json.dumps(summary, sort_keys=True))
    if not db_evidence['equal']:
        raise SystemExit('STOP: raw Alp DB hashes differ; preserve evidence, no normalization')


if __name__ == '__main__':
    main()
