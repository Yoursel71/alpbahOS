#!/usr/bin/env python3
"""Real zlib build twice, deterministic package, Alp ownership/remove/restore.

Called only through guest-package.sh's VM/disk/writer guard. This does not
install Debian packages into the product; Alp receives only staged zlib files.
"""
import hashlib
import json
import os
import time
from pathlib import Path
from package_stage import build_staged, run
from package_install import install_staged

REPO = Path('/opt/alp-infra')
LFS = Path('/srv/lfs')
RESULT = LFS / 'results/zlib-smoke'


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def main():
    manifest = json.loads((REPO / 'manifests/infra-sources.json').read_text())
    recipe = json.loads((REPO / 'recipes/smoke/zlib.json').read_text())
    item = next(s for s in manifest['sources'] if s['filename'] == recipe['source'])
    source = LFS / 'sources' / item['filename']
    assert sha(source) == item['sha256'], 'Source hash mismatch; stop'
    alp = REPO / 'runtime/alp.py'
    assert sha(alp) == manifest['alp']['sha256'], 'Alp pin mismatch'
    epoch = str(manifest['source_date_epoch'])
    os.environ.update(SOURCE_DATE_EPOCH=epoch, ALP_REPRODUCIBLE_BUILD='1',
                      LC_ALL='C', LANG='C', TZ='UTC')
    os.umask(0o022)
    input_record = json.loads(Path('/srv/infra/inputs.json').read_text())
    assert input_record['sources_sha256'] == sha(REPO / 'manifests/infra-sources.json'), 'Input manifest changed'
    archives, manifests, timings = [], [], []
    for repetition in (1, 2):
        built = build_staged(recipe, f'zlib-smoke-{repetition}', RESULT)
        timings.append(built['seconds'])
        # Stable externally documented names remain unchanged.
        archive = RESULT / f'zlib-{repetition}.tar.gz'
        built['archive'].rename(archive)
        captured = RESULT / f'manifest-{repetition}.json'
        built['manifest'].rename(captured)
        archives.append(built['archive_sha256'])
        manifests.append(built['manifest_sha256'])
    assert archives[0] == archives[1], 'Different archive hashes: possible instability/reproducibility fault'
    assert manifests[0] == manifests[1], 'Different staging manifests'
    root = LFS / 'smoke-root'
    if any(root.iterdir()):
        raise SystemExit('Smoke root not empty')
    bundle = {'source': item, 'archive': RESULT / 'zlib-1.tar.gz',
              'manifest': RESULT / 'manifest-1.json', 'archive_sha256': archives[0],
              'manifest_sha256': manifests[0]}
    acceptance = install_staged(recipe, bundle, root, RESULT)
    index = Path(acceptance['index'])
    command = ['/opt/alp-builder-python/bin/python3', str(alp), '--root', str(root), '--index', str(index)]
    log = RESULT / 'ownership.log'
    database = json.loads((root / 'var/lib/alp/db.json').read_text())
    records = database['installed'] if 'installed' in database else database['packages']
    record = records['zlib']
    entries = json.loads((RESULT / 'manifest-1.json').read_text())['entries']
    owned = set(record['files']) | set(record.get('symlinks', {}))
    required = {e['path'].lstrip('/') for e in entries if e['type'] != 'directory'}
    assert required <= {p.lstrip('/') for p in owned}, 'Missing Alp ownership'
    run(command + ['remove', '-y', 'zlib'], log)
    assert all(not (root / p).exists() and not (root / p).is_symlink() for p in required)
    # Reinstall the exact verified core package is the remove undo path;
    # it is not presented as Alp's nonexistent general historical rollback CLI.
    run(command + ['install', '-y', 'zlib'], log)
    run(['python3', str(REPO / 'scripts/compare-package-manifest.py'),
         '--root', str(root), '--manifest', str(RESULT / 'manifest-1.json')], log)
    run(command + ['check'], log)
    # Install the identical package in two fresh roots across a real clock
    # tick. Compare raw DB bytes; never normalize timestamps or omit the DB.
    db_records = []
    for label in ('a', 'b'):
        db_root = LFS / f'smoke-db-{label}'
        assert not db_root.exists() and not db_root.is_symlink(), 'Existing DB test root refused'
        db_root.mkdir()
        db_command = ['/opt/alp-builder-python/bin/python3', str(alp), '--root', str(db_root), '--index', str(index)]
        run(db_command + ['install', '-y', 'zlib'], log,
            env={**os.environ, 'SOURCE_DATE_EPOCH': epoch, 'ALP_REPRODUCIBLE_BUILD': '1',
                 'LC_ALL': 'C', 'LANG': 'C', 'TZ': 'UTC'})
        db_file = db_root / 'var/lib/alp/db.json'
        raw = db_file.read_bytes()
        (RESULT / f'db-repro-{label}.json').write_bytes(raw)
        db_records.append({'root': str(db_root), 'db_sha256': hashlib.sha256(raw).hexdigest()})
        if label == 'a':
            time.sleep(1.2)
    db_equal = db_records[0]['db_sha256'] == db_records[1]['db_sha256']
    db_evidence = {'source_date_epoch': int(epoch), 'alp_reproducible_build_mode': True,
                   'alp_sha256': manifest['alp']['sha256'],
                   'inputs_sha256': input_record['inputs_sha256'], 'records': db_records, 'equal': db_equal}
    (RESULT / 'db-repro-evidence.json').write_text(json.dumps(db_evidence, indent=2) + '\n')
    summary = {'package': 'zlib-1.3.1', 'result': 'PASS',
               'source_date_epoch': int(epoch), 'alp_reproducible_build_mode': True,
               'alp_sha256': manifest['alp']['sha256'],
               'inputs_sha256': input_record['inputs_sha256'],
               'db_sha256': [r['db_sha256'] for r in db_records], 'db_repeatable': db_equal,
               'source_sha256': item['sha256'], 'archive_sha256': archives,
               'manifest_sha256': manifests, 'build_test_stage_seconds': timings,
               'owned_nondirectory_paths': len(required), 'install_remove_restore': 'PASS',
               'restoration_method': 'reinstall same SHA256 pinned core archive',
               'scope': 'isolated smoke-root; not 79-package LFS or ISO acceptance'}
    if not db_equal:
        summary['result'] = 'FAIL_DB_REPRODUCIBILITY'
    (RESULT / 'summary.json').write_text(json.dumps(summary, indent=2, sort_keys=True) + '\n')
    print(json.dumps(summary, sort_keys=True))
    if not db_equal:
        raise SystemExit('STOP: raw Alp DB hashes differ; request engine-owner fix, do not patch/normalize')


if __name__ == '__main__':
    main()
