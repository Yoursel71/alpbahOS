"""Read-only acceptance of collected guest stability artifacts.

Checks the actual saved archive/manifest/Alp DB bytes, never just a PASS
string. Host kernel/temperature and privileged RPM acceptance are separate.
"""
import json
import math
from pathlib import Path
from package_install import fingerprint, validate_bundle
from package_stage import sha


def evidence_file(root, name):
    if not isinstance(name, str):
        raise RuntimeError('Stability evidence filename missing')
    path = root / name
    if (Path(name).is_absolute() or '..' in Path(name).parts
            or not path.is_file() or path.resolve() != path or path.is_symlink()):
        raise RuntimeError('Stability evidence path unsafe/missing: ' + name)
    return path


def positive(value):
    return type(value) in (int, float) and math.isfinite(value) and value > 0


def verify_stability_artifacts(root, sources, inputs_sha256, sources_sha256, recipes):
    root = Path(root)
    summary_path = evidence_file(root, 'summary.json')
    summary = json.loads(summary_path.read_text())
    expected = {'result': 'PASS', 'inputs_sha256': inputs_sha256,
                'sources_sha256': sources_sha256, 'alp_sha256': sources['alp']['sha256'],
                'source_date_epoch': sources['source_date_epoch'],
                'mode': sources['abi_selection']['mode']}
    if any(summary.get(key) != value for key, value in expected.items()):
        raise RuntimeError('Stability summary failed or current input/ABI pins changed')
    if not positive(summary.get('seconds')) or not 1200 <= summary['seconds'] <= 1800:
        raise RuntimeError('Stability gate outside 20–30 minute window')
    stress = summary.get('stress')
    if (not isinstance(stress, list) or len(stress) != 16
            or any(row.get('ok') is not True or type(row.get('loops')) is not int
                   or row['loops'] <= 0 for row in stress)):
        raise RuntimeError('Stability compute evidence incomplete/failed')
    hashes = {'summary.json': sha(summary_path)}

    def checked_file(name):
        path = evidence_file(root, name)
        hashes[name] = sha(path)
        return path

    def bundle(recipe, row):
        item = next(s for s in sources['sources'] if s['filename'] == recipe['source'])
        if row.get('source') != item or not positive(row.get('seconds')):
            raise RuntimeError('Stability bundle source/timing differs from canonical source')
        built = {**row, 'archive': checked_file(row.get('archive')),
                 'manifest': checked_file(row.get('manifest'))}
        return validate_bundle(recipe, built)

    def installation(recipe, row, captured, target, archive_sha256, manifest_sha256):
        receipt_path = checked_file(row.get('receipt'))
        if row.get('receipt_sha256') != sha(receipt_path):
            raise RuntimeError('Stability install receipt changed')
        receipt = json.loads(receipt_path.read_text())
        bound = {**{key: expected[key] for key in ('inputs_sha256', 'alp_sha256', 'source_date_epoch')},
                 'result': 'PASS', 'package': recipe['name'], 'version': recipe['version'],
                 'root': target, 'recipe_sha256': fingerprint(recipe),
                 'archive_sha256': archive_sha256, 'manifest_sha256': manifest_sha256}
        if any(receipt.get(k) != v for k, v in bound.items()):
            raise RuntimeError('Stability installation receipt input/package binding changed')
        raw_path = checked_file(row.get('db'))
        if receipt.get('db_sha256') != sha(raw_path):
            raise RuntimeError('Stability saved raw DB differs from installation receipt')
        db = json.loads(raw_path.read_text())
        if db.get('schema_version') != 1 or set(db.get('packages', {})) != {recipe['name']}:
            raise RuntimeError('Stability raw DB schema/package scope changed')
        record = db['packages'][recipe['name']]
        url = f'file:///srv/lfs/packages/{recipe["name"]}-{recipe["version"]}-{archive_sha256}.tar.gz'
        if (record.get('status') != 'installed' or record.get('version') != recipe['version']
                or record.get('method') != 'core' or record.get('source', {}).get('url') != url
                or record.get('source', {}).get('sha256') != archive_sha256
                or fingerprint(record) != receipt.get('package_record_sha256')):
            raise RuntimeError('Stability raw Alp package identity/source/record changed')
        claims = {p.lstrip('/') for p in record.get('files', [])} | {p.lstrip('/') for p in record.get('symlinks', [])}
        payload = {entry['path'].lstrip('/') for entry in captured['entries']}
        required = {entry['path'].lstrip('/') for entry in captured['entries'] if entry['type'] != 'directory'}
        if not required <= claims <= payload:
            raise RuntimeError('Stability raw DB ownership missing/extra claims')
        index_name = str(Path(row['receipt']).parent / f'{recipe["name"]}.index.json')
        index_path = checked_file(index_name)
        if (receipt.get('index_sha256') != sha(index_path)
                or receipt.get('index') != '/srv/lfs/results/stability/' + index_name):
            raise RuntimeError('Stability installation index changed')
        index = json.loads(index_path.read_text())
        entry = {'method': 'core', 'name': recipe['name'], 'version': recipe['version'],
                 'url': url, 'sha256': archive_sha256,
                 'depends': list(recipe.get('requires', [])), 'protected': False}
        if index != {'schema_version': 1, 'entries': {recipe['name']: entry}}:
            raise RuntimeError('Stability installation index scope/source changed')
        return sha(raw_path)

    sbu = summary.get('sbu')
    if not isinstance(sbu, list) or [row.get('jobs') for row in sbu] != [1, 16]:
        raise RuntimeError('Stability j1/j16 SBU evidence missing')
    for row in sbu:
        prefix = f'sbu-j{row["jobs"]}'
        if (row.get('db') != prefix + '/db.json'
                or row.get('receipt') != prefix + f'/{recipes["sbu"]["name"]}.installed.json'
                or row.get('archive') != f'binutils-sbu-j{row["jobs"]}.tar.gz'
                or row.get('manifest') != f'binutils-sbu-j{row["jobs"]}.json'):
            raise RuntimeError('Stability SBU artifacts do not match j1/j16 runs')
        captured = bundle(recipes['sbu'], row)
        installation(recipes['sbu'], row, captured, '/srv/lfs/sbu-root',
                     row['archive_sha256'], row['manifest_sha256'])
    zlib = summary.get('zlib')
    if not isinstance(zlib, list) or len(zlib) != 2:
        raise RuntimeError('Stability two fresh zlib builds missing')
    for key in ('archive_sha256', 'manifest_sha256'):
        if zlib[0].get(key) != zlib[1].get(key):
            raise RuntimeError('Stability unequal package/manifest hashes')
    db_path = checked_file('db-repro-evidence.json')
    db_evidence = json.loads(db_path.read_text())
    records = db_evidence.get('records', [])
    if len(records) != 2 or db_evidence.get('equal') is not True:
        raise RuntimeError('Stability two raw DB reproducibility records missing/failed')
    raw_hashes = []
    for label, row, built in zip(('a', 'b'), records, zlib):
        if (row.get('root') != f'/srv/lfs/stability-db-{label}'
                or row.get('db') != f'db-repro-{label}.json'
                or row.get('receipt') != f'zlib-{label}/{recipes["zlib"]["name"]}.installed.json'):
            raise RuntimeError('Stability DB evidence must name distinct fresh roots/files')
        run_id = 'zlib-oc-' + ('1' if label == 'a' else '2')
        if built.get('archive') != run_id + '.tar.gz' or built.get('manifest') != run_id + '.json':
            raise RuntimeError('Stability artifacts must name two distinct builds')
        captured = bundle(recipes['zlib'], built)
        raw_hash = installation(recipes['zlib'], row, captured, row['root'],
                                built['archive_sha256'], built['manifest_sha256'])
        if row.get('db_sha256') != raw_hash:
            raise RuntimeError('Stability DB evidence/report bytes disagree')
        raw_hashes.append(raw_hash)
    if raw_hashes[0] != raw_hashes[1] or summary.get('db_sha256') != raw_hashes:
        raise RuntimeError('Stability raw DB hashes differ; no normalization permitted')
    return {'scope': 'guest artifacts only; host/production acceptance remains separate',
            'inputs_sha256': inputs_sha256, 'sources_sha256': sources_sha256,
            'artifact_sha256': hashes, 'db_sha256': raw_hashes}
