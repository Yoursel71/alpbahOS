"""Shared clean source -> unprivileged build -> DESTDIR -> manifest -> archive.

Guest-only library. Root callers must first hold guest-guard's VM/disk lock.
Recipes are local reviewed argv lists, never downloaded shell snippets.
"""
import hashlib
import json
import os
import re
import subprocess
import time
from pathlib import Path

REPO = Path('/opt/alp-infra')
LFS = Path('/srv/lfs')
INFRA = Path('/srv/infra')
BOOT = Path('/proc/sys/kernel/random/boot_id')
RUNUSER = '/usr/sbin/runuser'


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def local_source_guard(item, repo):
    """Locally authored inputs are pinned alongside downloaded sources."""
    name = item.get('filename', '')
    if (item.get('kind') != 'repository-file'
            or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._+-]*', name)
            or not re.fullmatch(r'[0-9a-f]{64}', item.get('sha256', ''))
            or item.get('path') != 'recipes/toolchain/' + name
            or not item.get('url', '').startswith('urn:alpbahOS:source:')):
        raise RuntimeError('Invalid local source pin/path')
    path = repo / item['path']
    if path.resolve() != path or path.is_symlink() or not path.is_file() or sha(path) != item['sha256']:
        raise RuntimeError('Local source bytes changed; stop')
    return path


def source_pin(manifest, name, repo=REPO):
    matches = [s for s in [*manifest['sources'], *manifest.get('local_sources', [])] if s['filename'] == name]
    if len(matches) != 1:
        raise RuntimeError('Source pin missing/ambiguous: ' + name)
    item = matches[0]
    if item in manifest.get('local_sources', []):
        local_source_guard(item, repo)
    return item


def run(argv, log, cwd=None, env=None):
    if os.geteuid() == 0:
        from guest_process import run_logged
        return run_logged(argv, log, cwd=cwd, env=env)
    with log.open('ab') as output:
        output.write(('COMMAND ' + repr(argv) + '\n').encode())
        output.flush()
        subprocess.run(argv, cwd=cwd, env=env, stdout=output, stderr=subprocess.STDOUT, check=True)


def relative_path(root, name):
    path = Path(name)
    if path.is_absolute() or '..' in path.parts or path == Path('.'):
        raise RuntimeError('Unsafe relative recipe path')
    target = root / path
    if root not in target.resolve().parents or target.is_symlink():
        raise RuntimeError('Recipe path escaped or is symlink')
    return target


def recipe_working_directory(root, recipe, step):
    """Resolve an optional recipe step directory under its private build tree."""
    relative = recipe.get('working_directories', {}).get(step, '.')
    if root.is_symlink() or root.resolve() != root:
        raise RuntimeError('Recipe working directory root changed or is unsafe')
    if relative == '.':
        target = root
    else:
        target = relative_path(root, relative)
        cursor = root
        for part in Path(relative).parts:
            cursor = cursor / part
            if cursor.is_symlink():
                raise RuntimeError('Recipe working directory traverses a symlink')
    if target.is_symlink() or not target.is_dir():
        raise RuntimeError('Recipe working directory is missing or unsafe')
    return target


def validate_recipe(recipe, jobs):
    if recipe.get('test_user', 'lfs') not in ('lfs', 'tester', 'root'):
        raise RuntimeError('Recipe test_user must be lfs, tester or root')
    if recipe.get('test_locale', 'C') not in ('C', 'C.UTF-8'):
        raise RuntimeError('Recipe test_locale is not allowlisted')
    for field in ('pre', 'compile', 'test', 'stage', 'post_stage'):
        for argv in recipe.get(field, []):
            if not isinstance(argv, list) or not argv or not all(isinstance(a, str) for a in argv):
                raise RuntimeError('Recipe commands must be nonempty argv lists')
            if any('-march=native' in a for a in argv):
                raise RuntimeError('Native CPU flags forbidden')
    if jobs not in recipe.get('allowed_jobs', [recipe['jobs']]) or not isinstance(jobs, int) or jobs < 1:
        raise RuntimeError('Job override not permitted for this recipe')
    for item in recipe.get('prerequisites', []):
        if not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9._+-]*', item['directory']):
            raise RuntimeError('Unsafe prerequisite directory')
    allowed_env = {'PATH', 'LFS', 'LFS_TGT', 'LFS_TGT32', 'CC', 'CXX', 'AR', 'RANLIB', 'MAKEFLAGS', 'NINJAJOBS'}
    if set(recipe.get('environment', {})) - allowed_env:
        raise RuntimeError('Recipe environment name not allowlisted')
    if 'NINJAJOBS' in recipe.get('environment', {}) and not re.fullmatch(
            r'[1-9][0-9]{0,2}', recipe['environment']['NINJAJOBS']):
        raise RuntimeError('NINJAJOBS must be a positive bounded integer')
    prefix = Path(recipe.get('strip_stage_prefix', ''))
    if prefix.is_absolute() or '..' in prefix.parts:
        raise RuntimeError('Invalid stage prefix')
    working_directories = recipe.get('working_directories', {})
    if not isinstance(working_directories, dict) or set(working_directories) - {'compile', 'test', 'stage', 'post_stage'}:
        raise RuntimeError('Recipe working directory step is invalid')
    for name in working_directories.values():
        if not isinstance(name, str) or not name or (name != '.' and
                (Path(name).is_absolute() or '..' in Path(name).parts or '\\' in name)):
            raise RuntimeError('Recipe working directory must stay under the build tree')


def test_identity_guard(recipe):
    """Only a root guest coordinator may run root/tester-owned package tests."""
    identity = recipe.get('test_user', 'lfs')
    if recipe.get('test') and identity in ('root', 'tester') and os.geteuid() != 0:
        raise RuntimeError(f'{identity}-owned tests require the guest root coordinator')


def phase2_authorization_guard(recipe):
    """Stability may run before its receipt, but never before OC/ABI approval."""
    if recipe.get('phase') not in ('stability', 'toolchain'):
        return
    paths = [INFRA / name for name in ('phase2-authorization.json', 'inputs.json')]
    if any(not path.is_file() or path.is_symlink() for path in paths):
        raise RuntimeError('Phase 2 current OC/ABI authorization missing')
    auth, inputs = [json.loads(path.read_text()) for path in paths]
    if not all(isinstance(inputs.get(k), str) and re.fullmatch(r'[0-9a-f]{64}', inputs[k])
               for k in ('inputs_sha256', 'sources_sha256')):
        raise RuntimeError('Phase 2 input hashes missing/invalid')
    source_manifest = REPO / 'manifests/infra-sources.json'
    selected = json.loads(source_manifest.read_text()).get('abi_selection', {}).get('mode')
    if (auth.get('oc_confirmed') is not True or auth.get('stage') != recipe['phase']
            or auth.get('sources_sha256') != inputs['sources_sha256']
            or selected not in ('x86_64', 'multilib-m32')
            or auth.get('mode') != selected or auth.get('inputs_sha256') != inputs['inputs_sha256']
            or sha(source_manifest) != inputs['sources_sha256']
            or recipe.get('abi', selected) != selected):
        raise RuntimeError('Phase 2 OC/ABI authorization/input mismatch')


def heavy_recipe_guard(recipe):
    if recipe.get('phase') == 'stability':
        phase2_authorization_guard(recipe)
        return
    if recipe.get('phase') == 'base':
        base_stage_authorization_guard(recipe)
        return
    if recipe.get('phase') != 'toolchain':
        return
    # No recipe-level shortcut around the host OC, DB and stability gates.
    auth_path = INFRA / 'phase2-authorization.json'
    receipt_path = INFRA / 'stability-acceptance.json'
    if (not auth_path.is_file() or not receipt_path.is_file()
            or auth_path.is_symlink() or receipt_path.is_symlink()):
        raise RuntimeError('Product package needs OC/ABI authorization and verified stability receipt')
    phase2_authorization_guard(recipe)
    auth = json.loads(auth_path.read_text())
    inputs = json.loads((INFRA / 'inputs.json').read_text())
    if not all(isinstance(inputs.get(k), str) and re.fullmatch(r'[0-9a-f]{64}', inputs[k])
               for k in ('inputs_sha256', 'sources_sha256')):
        raise RuntimeError('Toolchain receipt input hashes missing/invalid')
    source_manifest = REPO / 'manifests/infra-sources.json'
    selected = json.loads(source_manifest.read_text()).get('abi_selection', {}).get('mode')
    if sha(source_manifest) != inputs['sources_sha256'] or selected != recipe.get('abi'):
        raise RuntimeError('Product package source manifest/selected ABI changed')
    from handoff_binding import validate
    validate(receipt_path.read_bytes(), auth, inputs, BOOT.read_text().strip())


def base_stage_authorization_guard(recipe):
    """Require a fresh controller authorization bound to accepted toolchain bytes."""
    from package_install import guest_install_guard
    guest_install_guard(LFS, LFS / 'results/base')
    names = ('phase2-authorization.json', 'inputs.json', 'stability-acceptance.json',
             'toolchain-acceptance.json', 'base-authorization.json')
    paths = {name: INFRA / name for name in names}
    if any(not path.is_file() or path.is_symlink() for path in paths.values()):
        raise RuntimeError('Base packages need OC, stability, toolchain and base-stage acceptance')
    toolchain_auth_path = paths['phase2-authorization.json']
    stability_path = paths['stability-acceptance.json']
    inputs_path = paths['inputs.json']
    toolchain_path = paths['toolchain-acceptance.json']
    base_path = paths['base-authorization.json']
    phase2_authorization_guard({'phase': 'toolchain', 'abi': recipe.get('abi')})
    from handoff_binding import validate
    validate(paths['stability-acceptance.json'].read_bytes(),
             json.loads(paths['phase2-authorization.json'].read_bytes()),
             json.loads(paths['inputs.json'].read_bytes()), BOOT.read_text().strip())
    auth = json.loads(toolchain_auth_path.read_bytes())
    inputs = json.loads(inputs_path.read_bytes())
    toolchain = json.loads(toolchain_path.read_bytes())
    base = json.loads(base_path.read_bytes())
    source_manifest = REPO / 'manifests/infra-sources.json'
    selected = json.loads(source_manifest.read_bytes()).get('abi_selection', {}).get('mode')
    if (recipe.get('abi') != selected or sha(source_manifest) != inputs.get('sources_sha256')
            or toolchain.get('schema') != 'alpbahOS.toolchain-acceptance/v1'
            or toolchain.get('result') != 'PASS' or toolchain.get('stage') != 'toolchain'
            or toolchain.get('mode') != selected
            or toolchain.get('inputs_sha256') != inputs.get('inputs_sha256')
            or toolchain.get('sources_sha256') != inputs.get('sources_sha256')
            or not re.fullmatch(r'[0-9a-f]{32}', str(toolchain.get('run_id', '')))
            or not re.fullmatch(r'[0-9a-f]{32}', str(toolchain.get('after_audit_id', '')))
            or not re.fullmatch(r'[0-9a-f]{64}', str(toolchain.get('proof_sha256', '')))
            or not re.fullmatch(r'[0-9a-f]{64}', str(toolchain.get('checkpoint_sha256', '')))
            or base.get('schema') != 'alpbahOS.base-authorization/v1'
            or base.get('result') != 'AUTHORIZED' or base.get('stage') != 'base'
            or base.get('mode') != selected or base.get('oc_confirmed') is not True
            or base.get('inputs_sha256') != inputs.get('inputs_sha256')
            or base.get('sources_sha256') != inputs.get('sources_sha256')
            or base.get('phase2_authorization_sha256') != sha(toolchain_auth_path)
            or base.get('stability_acceptance_sha256') != sha(stability_path)
            or base.get('toolchain_acceptance_sha256') != sha(toolchain_path)
            or not re.fullmatch(r'[0-9a-f]{32}', str(base.get('run_id', '')))
            or not re.fullmatch(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
                                str(base.get('guest_boot_id', '')))
            or type(base.get('authorized_at_ns')) is not int or base['authorized_at_ns'] <= 0):
        raise RuntimeError('Base authorization/toolchain acceptance binding mismatch')


def build_staged(recipe, run_id, result, jobs=None):
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._+-]*', run_id):
        raise RuntimeError('Invalid run identity')
    jobs = recipe['jobs'] if jobs is None else jobs
    validate_recipe(recipe, jobs)
    test_identity_guard(recipe)
    heavy_recipe_guard(recipe)
    if recipe.get('kind') == 'layout':
        from filesystem_layout import build_layout
        return build_layout(recipe, run_id, result)
    manifest = json.loads((REPO / 'manifests/infra-sources.json').read_text())
    environment = {**os.environ, 'LC_ALL': 'C', 'LANG': 'C', 'TZ': 'UTC',
                   'SOURCE_DATE_EPOCH': str(manifest['source_date_epoch'])}
    item = source_pin(manifest, recipe['source'], REPO)
    if item.get('kind') == 'repository-file':
        raise RuntimeError('Local source requires its explicit generator, not archive extraction')
    if recipe.get('phase') == 'toolchain':
        from filesystem_layout import require_layout
        from package_install import guest_install_guard
        guest_install_guard(LFS, result)
        require_layout(LFS)
    source = LFS / 'sources' / item['filename']
    if source.is_symlink() or sha(source) != item['sha256']:
        raise RuntimeError('Source hash mismatch; stop')
    verified_prerequisites = []
    for prerequisite in recipe.get('prerequisites', []):
        dependency = next(s for s in manifest['sources'] if s['filename'] == prerequisite['source'])
        archive = LFS / 'sources' / dependency['filename']
        if archive.is_symlink() or sha(archive) != dependency['sha256']:
            raise RuntimeError('Prerequisite source hash mismatch; stop')
        verified_prerequisites.append((prerequisite, archive))
    verified_patches = []
    for patch in recipe.get('patches', []):
        dependency = next(s for s in manifest['sources'] if s['filename'] == patch['source'])
        archive = LFS / 'sources' / dependency['filename']
        if archive.is_symlink() or sha(archive) != dependency['sha256'] or patch['strip'] not in (0, 1, 2):
            raise RuntimeError('Patch source hash/strip mismatch; stop')
        verified_patches.append((patch, archive))
    build = LFS / 'build' / run_id
    stage = LFS / 'stage' / run_id
    if build.exists() or stage.exists() or build.is_symlink() or stage.is_symlink():
        raise RuntimeError('Existing build/stage refused; restore checkpoint for clean restart')
    build.mkdir(); stage.mkdir()
    subprocess.run(['chown', 'lfs:lfs', str(build), str(stage)], check=True)
    log = result / f'{run_id}.log'
    run([RUNUSER, '-u', 'lfs', '--', 'tar', '-xf', str(source),
         '--strip-components=1', '-C', str(build)], log)
    for prerequisite, archive in verified_prerequisites:
        target = relative_path(build, prerequisite['directory'])
        target.mkdir()
        subprocess.run(['chown', 'lfs:lfs', str(target)], check=True)
        run([RUNUSER, '-u', 'lfs', '--', 'tar', '-xf', str(archive),
             '--strip-components=1', '-C', str(target)], log)
    substitutions = {'stage': str(stage), 'jobs': jobs, 'source': str(build), 'lfs': str(LFS)}
    environment.update({key: value.format(**substitutions) for key, value in recipe.get('environment', {}).items()})
    for patch, archive in verified_patches:
        run([RUNUSER, '-u', 'lfs', '--', 'patch', f'-Np{patch["strip"]}', '-i', str(archive)],
            log, cwd=build, env=environment)
    for argv in recipe.get('pre', []):
        command = [arg.format(**substitutions) for arg in argv]
        run([RUNUSER, '-u', 'lfs', '--', *command], log, cwd=build, env=environment)
    work = build
    if recipe.get('separate_build'):
        work = build / 'build'; work.mkdir()
        subprocess.run(['chown', 'lfs:lfs', str(work)], check=True)
    for name, contents in recipe.get('build_files', {}).items():
        target = relative_path(work, name)
        target.write_text(contents)
        subprocess.run(['chown', 'lfs:lfs', str(target)], check=True)
    if recipe.get('configure_build_guess'):
        guess = relative_path(build, recipe['configure_build_guess'])
        process = subprocess.run([RUNUSER, '-u', 'lfs', '--', str(guess)],
                                 capture_output=True, text=True, check=True, env=environment)
        triplet = process.stdout.strip()
        if not re.fullmatch(r'[A-Za-z0-9_.+-]+', triplet):
            raise RuntimeError('Invalid configure build triplet')
        substitutions['build_triplet'] = triplet
        with log.open('a') as stream:
            stream.write('CONFIG_GUESS ' + triplet + '\n')
    flags = f'-O2 -g0 -ffile-prefix-map={build}=/usr/src/{recipe["name"]} -fdebug-prefix-map={build}=/usr/src/{recipe["name"]}'
    started = time.monotonic()
    for step in ('compile', 'test', 'stage', 'post_stage'):
        test_user = recipe.get('test_user', 'lfs') if step == 'test' else 'lfs'
        test_locale = recipe.get('test_locale', 'C') if step == 'test' else 'C'
        step_cwd = recipe_working_directory(work, recipe, step)
        for argv in recipe.get(step, []):
            command = [arg.format(**substitutions) for arg in argv]
            try:
                if test_user == 'tester':
                    run(['chown', '-hR', 'tester:tester', str(build)], log)
                run([RUNUSER, '-u', test_user, '--', 'env', f'LC_ALL={test_locale}',
                     f'LANG={test_locale}', 'TZ=UTC',
                     f'SOURCE_DATE_EPOCH={manifest["source_date_epoch"]}', f'CFLAGS={flags}',
                     f'CXXFLAGS={flags}', *command], log, cwd=step_cwd, env=environment)
            finally:
                if test_user in ('tester', 'root'):
                    run(['chown', '-hR', 'lfs:lfs', str(build)], log)
    for action in recipe.get('post_stage_concat', []):
        files = [relative_path(build, name) for name in action['sources']]
        destination = relative_path(stage, action['destination'])
        # GCC's limits.h assembly belongs to the staged package, never a
        # write to an already-installed toolchain outside ownership capture.
        if not destination.parent.is_dir():
            raise RuntimeError('Missing staged concatenation destination')
        destination.write_bytes(b''.join(path.read_bytes() for path in files))
    seconds = round(time.monotonic() - started, 3)
    if stage.is_symlink() or stage.resolve() != stage or build.resolve() != build:
        raise RuntimeError('Build/stage root changed during recipe')
    run(['chown', '-hR', '-P', '0:0', str(stage)], log)
    prefix = Path(recipe.get('strip_stage_prefix', ''))
    if prefix.is_absolute() or '..' in prefix.parts:
        raise RuntimeError('Invalid stage prefix')
    payload = stage / prefix
    if stage not in payload.resolve().parents and payload.resolve() != stage:
        raise RuntimeError('Stage payload escaped')
    return pack_staged(recipe, payload, result, run_id, item, environment, seconds)


def pack_staged(recipe, payload, result, run_id, item, environment, seconds):
    """Common manifest/archive path for compiled and generated DESTDIRs."""
    log = result / f'{run_id}.log'
    captured = result / f'{run_id}.json'
    archive = result / f'{run_id}.tar.gz'
    if any(p.exists() or p.is_symlink() for p in (captured, archive)):
        raise RuntimeError('Existing package artifacts refused; preserve evidence')
    run(['python3', str(REPO / 'scripts/capture-package-manifest.py'),
         '--stage', str(payload), '--name', recipe['name'], '--version', recipe['version'],
         '--source-url', item['url'], '--source-sha256', item['sha256'],
         '--output', str(captured)], log, env=environment)
    metadata = json.loads(captured.read_text())
    owner = payload.stat()
    if any(entry['uid'] != owner.st_uid or entry['gid'] != owner.st_gid for entry in metadata['entries']):
        raise RuntimeError('Staged ownership is not uniform; cannot normalize archive')
    # Constant reviewed shell code; paths/epoch/owners are quoted positional
    # arguments. One process group and pipefail cover both tar and gzip.
    pipeline = ('set -euo pipefail\n'
        'tar --sort=name --mtime="@${1}" --owner="${2}" --group="${3}" '
        '--numeric-owner --format=gnu -cf - -C "${4}" . | gzip -n -9 > "${5}"')
    run(['bash', '-c', pipeline, 'alp-pack', environment['SOURCE_DATE_EPOCH'],
         str(owner.st_uid), str(owner.st_gid), str(payload), str(archive)], log, env=environment)
    return {'source': item, 'archive': archive, 'manifest': captured, 'seconds': seconds,
            'archive_sha256': sha(archive), 'manifest_sha256': sha(captured)}
