"""Guest-only staged core installation through the pinned Alp CLI.

Never edits Alp or writes its DB. Bundle validation is read-only; mutation
requires the guest disk identity, inherited writer lock and stage gates.
"""
import fcntl
import hashlib
import json
import os
import posixpath
import re
import shutil
import subprocess
import tarfile
import time
from pathlib import Path
from package_stage import heavy_recipe_guard, run, sha, source_pin

REPO = Path('/opt/alp-infra')
LFS = Path('/srv/lfs')
INFRA = Path('/srv/infra')
PYTHON = '/opt/alp-builder-python/bin/python3'


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def member_path(raw):
    if not isinstance(raw, str) or '\x00' in raw or '\\' in raw or raw.startswith('/'):
        raise RuntimeError('Unsafe archive path')
    while raw.startswith('./'):
        raw = raw[2:]
    raw = raw.rstrip('/')
    if raw in ('', '.'):
        return ''
    if any(p in ('', '.', '..') for p in raw.split('/')):
        raise RuntimeError('Unsafe archive path')
    return raw


def validate_bundle(recipe, built):
    for field in ('archive', 'manifest'):
        path = Path(built[field])
        if not path.is_file() or path.is_symlink() or sha(path) != built[field + '_sha256']:
            raise RuntimeError('Staged bundle bytes changed: ' + field)
    value = json.loads(Path(built['manifest']).read_text())
    expected = {'name': recipe['name'], 'version': recipe['version'],
                'source': {'url': built['source']['url'], 'sha256': built['source']['sha256']}}
    if value.get('schema') != 'alpbahOS.package-files/v1' or value.get('package') != expected:
        raise RuntimeError('Staged manifest package/source identity mismatch')
    entries = {}
    for entry in value.get('entries', []):
        raw = entry.get('path')
        if not isinstance(raw, str) or not raw.startswith('/') or raw.startswith('//'):
            raise RuntimeError('Unsafe manifest path')
        relative = member_path(raw[1:])
        if not relative or '/' + relative != raw or relative in entries:
            raise RuntimeError('Duplicate/noncanonical manifest path')
        if entry.get('type') not in ('directory', 'file', 'symlink'):
            raise RuntimeError('Unsupported core payload type')
        entries[relative] = entry
    if not entries:
        raise RuntimeError('Empty staged manifest')
    seen = set()
    with tarfile.open(built['archive']) as archive:
        for member in archive:
            name = member_path(member.name)
            if not name:
                if not member.isdir():
                    raise RuntimeError('Archive root must be a directory')
                continue
            if name in seen or name not in entries:
                raise RuntimeError('Duplicate/unmanifested archive entry')
            seen.add(name)
            expected = entries[name]
            kind = ('directory' if member.isdir() else 'symlink' if member.issym()
                    else 'file' if member.isfile() or member.islnk() else 'unsupported')
            if (kind != expected['type'] or member.mode != expected['mode']
                    or member.uid != expected['uid'] or member.gid != expected['gid']):
                raise RuntimeError('Archive metadata differs from manifest: ' + name)
            if kind == 'file':
                if member.islnk():
                    member_path(member.linkname)
                content = archive.extractfile(member)
                digest = hashlib.sha256(); size = 0
                while block := content.read(1024 * 1024):
                    digest.update(block); size += len(block)
                if size != expected['size'] or digest.hexdigest() != expected['sha256']:
                    raise RuntimeError('Archive file bytes differ from manifest: ' + name)
            elif kind == 'symlink':
                target = member.linkname
                resolved = posixpath.normpath(posixpath.join(posixpath.dirname(name), target))
                if (target.startswith('/') or '\x00' in target or '\\' in target
                        or resolved == '..' or resolved.startswith('../') or target != expected['target']):
                    raise RuntimeError('Unsafe/changed archive symlink: ' + name)
    if seen != set(entries):
        raise RuntimeError('Archive missing manifest entries')
    return value


def guest_install_guard(root, result):
    if os.geteuid() != 0:
        raise RuntimeError('Alp installation requires guarded guest root; host invocation refused')
    if root not in (LFS, LFS / 'smoke-root', LFS / 'smoke-db-a', LFS / 'smoke-db-b',
                    LFS / 'sbu-root', LFS / 'stability-db-a', LFS / 'stability-db-b'):
        raise RuntimeError('Install root not allowlisted')
    for path in (root, result, LFS / 'packages'):
        if path.resolve() != path or path.is_symlink():
            raise RuntimeError('Install/artifact path is symlink or unresolved')
    if LFS / 'results' not in result.parents:
        raise RuntimeError('Install evidence outside dedicated results')
    if (LFS / '.infra-volume').read_text().strip() != 'alpbahOS-infra-v1':
        raise RuntimeError('Guest volume identity mismatch')
    virt = subprocess.check_output(['systemd-detect-virt', '--vm'], text=True).strip()
    disk = Path('/dev/disk/by-id/virtio-ALP_LFS_V1').resolve(strict=True)
    source = subprocess.check_output(['findmnt', '-n', '-o', 'SOURCE', '-T', str(LFS)], text=True).strip()
    if virt not in ('kvm', 'qemu') or source != str(disk):
        raise RuntimeError('Guest disk/VM identity mismatch')
    if subprocess.check_output(['findmnt', '-n', '-o', 'FSTYPE', '-T', str(LFS)], text=True).strip() != 'ext4':
        raise RuntimeError('Dedicated guest filesystem mismatch')
    held, expected = os.fstat(9), (INFRA / 'writer.lock').stat()
    if (held.st_dev, held.st_ino) != (expected.st_dev, expected.st_ino):
        raise RuntimeError('Inherited guest writer lock missing')
    fcntl.flock(9, fcntl.LOCK_EX | fcntl.LOCK_NB)
    usage = shutil.disk_usage(LFS)
    if usage.free / usage.total < .15:
        raise RuntimeError('Guest free space below 15%')


def canonical_key(root, relative):
    relative = member_path(relative.lstrip('/'))
    target = root / relative
    parent = target.parent.resolve()
    if parent != root and root not in parent.parents:
        raise RuntimeError('Installed path parent escapes root')
    return str(parent / target.name)


def packages(root):
    path = root / 'var/lib/alp/db.json'
    canonical_key(root, 'var/lib/alp/db.json')
    if not path.exists():
        return {}
    if path.is_symlink() or not path.is_file():
        raise RuntimeError('Unsafe Alp DB path')
    value = json.loads(path.read_text())
    if value.get('schema_version') != 1 or not isinstance(value.get('packages'), dict):
        raise RuntimeError('Unsupported Alp database schema')
    return value['packages']


def ownership_check(root, value, installed, name, before=False):
    claims = {}
    for owner, record in installed.items():
        for raw in set(record.get('files', [])) | set(record.get('symlinks', [])):
            relative = member_path(raw.lstrip('/'))
            path = root / relative
            if path.is_dir() and not path.is_symlink():
                continue  # Alp may own newly created directories; shared dirs are allowed.
            claims.setdefault(canonical_key(root, relative), set()).add(owner)
    required = set()
    for entry in value['entries']:
        key = canonical_key(root, entry['path'])
        if entry['type'] == 'directory':
            continue
        required.add(key)
        owners = claims.get(key, set())
        if owners - {name} or (not before and owners != {name}):
            raise RuntimeError('Payload ownership missing/conflicting: ' + entry['path'])
        target = root / entry['path'].lstrip('/')
        if before and os.path.lexists(target) and name not in owners:
            raise RuntimeError('Existing unowned payload path: ' + entry['path'])
    if not before:
        actual = {key for key, owners in claims.items() if name in owners}
        if actual != required:
            raise RuntimeError('Alp owns unexpected nondirectory package paths')


def install_staged(recipe, built, root, result, reinstall=False):
    root, result = Path(root), Path(result)
    guest_install_guard(root, result)
    if recipe.get('phase') not in ('smoke', 'stability', 'toolchain', 'base'):
        raise RuntimeError('Package install phase not integrated yet')
    heavy_recipe_guard(recipe)
    if recipe.get('phase') == 'toolchain':
        if root != LFS:
            raise RuntimeError('Production toolchain install requires dedicated LFS root')
        if recipe.get('kind') != 'layout':
            from filesystem_layout import require_layout
            require_layout(root)
    value = validate_bundle(recipe, built)
    source_manifest = REPO / 'manifests/infra-sources.json'
    sources = json.loads(source_manifest.read_text())
    inputs = json.loads((INFRA / 'inputs.json').read_text())
    if (inputs.get('sources_sha256') != sha(source_manifest)
            or not isinstance(inputs.get('inputs_sha256'), str)
            or not re.fullmatch('[0-9a-f]{64}', inputs['inputs_sha256'])):
        raise RuntimeError('Installation source inputs changed')
    item = source_pin(sources, recipe['source'], REPO)
    if any(built['source'].get(k) != item[k] for k in ('filename', 'url', 'sha256')):
        raise RuntimeError('Installation source provenance differs from canonical manifest')
    alp = REPO / 'runtime/alp.py'
    if sha(alp) != sources['alp']['sha256']:
        raise RuntimeError('Installation Alp pin mismatch')
    name, version = recipe['name'], recipe['version']
    if not all(re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._+-]*', token) for token in (name, version)):
        raise RuntimeError('Invalid package identity')
    installed = packages(root)
    snapshot = result / f'{name}.db.json'
    if recipe['phase'] == 'toolchain' and (snapshot.exists() or snapshot.is_symlink()):
        raise RuntimeError('Existing toolchain raw DB snapshot; preserve attempt/restore checkpoint')
    for path in ('var/lib/alp/db.json', 'var/cache/alp/archive', 'var/log/alp/install.log'):
        canonical_key(root, path)
    if name in installed and not reinstall:
        raise RuntimeError('Existing package requires explicit reinstall or verified resume')
    for dependency in recipe.get('requires', []):
        if installed.get(dependency, {}).get('status') != 'installed':
            raise RuntimeError('Package prerequisite not installed: ' + dependency)
    ownership_check(root, value, installed, name, before=True)
    store = LFS / 'packages'; store.mkdir(exist_ok=True)
    archive = store / f'{name}-{version}-{built["archive_sha256"]}.tar.gz'
    if archive.is_symlink():
        raise RuntimeError('Canonical archive is symlink')
    if not archive.exists():
        with archive.open('xb') as output, Path(built['archive']).open('rb') as source:
            shutil.copyfileobj(source, output)
    if sha(archive) != built['archive_sha256']:
        raise RuntimeError('Canonical archive bytes changed')
    # Content-addressed, fixed guest paths keep Alp source URLs independent
    # of build run labels, which would otherwise change raw DB bytes.
    entry = {'method': 'core', 'name': name, 'version': version,
             'url': archive.as_uri(), 'sha256': built['archive_sha256'],
             'depends': list(recipe.get('requires', [])), 'protected': recipe['phase'] == 'toolchain'}
    index = result / f'{name}.index.json'
    receipt = result / f'{name}.installed.json'
    for path in (index, receipt):
        if path.is_symlink():
            raise RuntimeError('Installation output is symlink')
    if receipt.exists():
        receipt.rename(result / f'{name}.installed-before-{time.time_ns()}.json')
    index.write_text(json.dumps({'schema_version': 1, 'entries': {name: entry}}, indent=2, sort_keys=True) + '\n')
    command = [PYTHON, str(alp), '--root', str(root), '--index', str(index)]
    env = {**os.environ, 'SOURCE_DATE_EPOCH': str(sources['source_date_epoch']),
           'ALP_REPRODUCIBLE_BUILD': '1',
           'LC_ALL': 'C', 'LANG': 'C', 'TZ': 'UTC'}
    log = result / f'{name}.install.log'
    argv = command + ['install', '-y', name]
    if reinstall:
        argv.append('--reinstall')
    run(argv, log, env=env)
    run(['python3', str(REPO / 'scripts/compare-package-manifest.py'), '--root', str(root),
         '--manifest', str(built['manifest'])], log, env=env)
    current = packages(root)
    ownership_check(root, value, current, name)
    record = current.get(name, {})
    if (record.get('status') != 'installed' or record.get('version') != version
            or record.get('method') != 'core' or record.get('source', {}).get('sha256') != built['archive_sha256']
            or record.get('source', {}).get('url') != archive.as_uri()):
        raise RuntimeError('Alp installed record identity/source mismatch')
    run(command + ['check'], log, env=env)
    if recipe.get('kind') == 'layout':
        from filesystem_layout import require_layout
        require_layout(root)
    acceptance = {'result': 'PASS', 'package': name, 'version': version,
                  'inputs_sha256': inputs['inputs_sha256'], 'recipe_sha256': fingerprint(recipe),
                  'alp_sha256': sources['alp']['sha256'], 'source_date_epoch': sources['source_date_epoch'],
                  'archive_sha256': built['archive_sha256'], 'manifest_sha256': built['manifest_sha256'],
                  'package_record_sha256': fingerprint(record), 'db_sha256': sha(root / 'var/lib/alp/db.json'),
                  'index': str(index), 'index_sha256': sha(index), 'root': str(root), 'log': str(log)}
    if recipe['phase'] == 'toolchain':
        raw = (root / 'var/lib/alp/db.json').read_bytes()
        if hashlib.sha256(raw).hexdigest() != acceptance['db_sha256']:
            raise RuntimeError('Toolchain raw DB changed during snapshot; preserve attempt')
        with snapshot.open('xb') as stream:
            stream.write(raw); stream.flush(); os.fsync(stream.fileno())
        if sha(snapshot) != acceptance['db_sha256'] or sha(root / 'var/lib/alp/db.json') != acceptance['db_sha256']:
            raise RuntimeError('Toolchain raw DB snapshot drift; preserve attempt')
    receipt.write_text(json.dumps(acceptance, indent=2, sort_keys=True) + '\n')
    return acceptance


def verify_installed(recipe, built, root, result):
    """Resume requires current package bytes/owners, not a stamp or old DB hash."""
    root, result = Path(root), Path(result)
    guest_install_guard(root, result)
    heavy_recipe_guard(recipe)
    if recipe.get('phase') == 'toolchain':
        if root != LFS:
            raise RuntimeError('Production toolchain resume requires dedicated LFS root')
        from filesystem_layout import require_layout
        require_layout(root)
    value = validate_bundle(recipe, built)
    inputs = json.loads((INFRA / 'inputs.json').read_text())
    sources_path = REPO / 'manifests/infra-sources.json'
    sources = json.loads(sources_path.read_text())
    item = source_pin(sources, recipe['source'], REPO)
    if any(built['source'].get(k) != item[k] for k in ('filename', 'url', 'sha256')):
        raise RuntimeError('Resume source provenance differs from canonical manifest')
    receipt = result / f'{recipe["name"]}.installed.json'
    if receipt.is_symlink() or not receipt.is_file():
        raise RuntimeError('Verified package receipt missing')
    acceptance = json.loads(receipt.read_text())
    expected = {'result': 'PASS', 'root': str(root), 'package': recipe['name'],
                'version': recipe['version'], 'recipe_sha256': fingerprint(recipe),
                'inputs_sha256': inputs['inputs_sha256'], 'alp_sha256': sources['alp']['sha256'],
                'source_date_epoch': sources['source_date_epoch'],
                'archive_sha256': built['archive_sha256'], 'manifest_sha256': built['manifest_sha256']}
    if (any(acceptance.get(k) != v for k, v in expected.items())
            or inputs.get('sources_sha256') != sha(sources_path)
            or sha(REPO / 'runtime/alp.py') != sources['alp']['sha256']):
        raise RuntimeError('Package resume receipt/input binding changed')
    if recipe.get('phase') == 'toolchain':
        snapshot = result / f'{recipe["name"]}.db.json'
        if snapshot.resolve() != snapshot or snapshot.is_symlink() or sha(snapshot) != acceptance.get('db_sha256'):
            raise RuntimeError('Toolchain installation raw DB snapshot changed')
    index = result / f'{recipe["name"]}.index.json'
    if index.is_symlink() or acceptance.get('index_sha256') != sha(index):
        raise RuntimeError('Package resume index changed')
    installed = packages(root)
    ownership_check(root, value, installed, recipe['name'])
    if acceptance.get('package_record_sha256') != fingerprint(installed.get(recipe['name'])):
        raise RuntimeError('Package resume DB record changed')
    archive = LFS / 'packages' / f'{recipe["name"]}-{recipe["version"]}-{built["archive_sha256"]}.tar.gz'
    if archive.is_symlink() or sha(archive) != built['archive_sha256']:
        raise RuntimeError('Package resume canonical archive changed')
    run(['python3', str(REPO / 'scripts/compare-package-manifest.py'), '--root', str(root),
         '--manifest', str(built['manifest'])], result / f'{recipe["name"]}.resume.log')
    return acceptance
