"""Guarded Chapter 4/5 sequence with verified artifacts and package resume.

No automatic reinstall after a partial Alp transaction. No host/whole LFS
acceptance or checkpoint is emitted by this guest-side package runner.
"""
import json
import os
from pathlib import Path
from package_stage import build_staged, heavy_recipe_guard, sha, source_pin, validate_recipe
from package_install import install_staged, verify_installed, validate_bundle, guest_install_guard, packages, fingerprint
from toolchain_sanity import probe
from handoff_binding import validate as validate_handoff
from package_stage import BOOT
from toolchain_plan import ORDER, load as canonical_plan

REPO = Path('/opt/alp-infra')
LFS = Path('/srv/lfs')
INFRA = Path('/srv/infra')


def load_plan():
    return canonical_plan(REPO)


def safe_json(path, value=None):
    if path.is_symlink() or path.resolve() != path:
        raise RuntimeError('Unsafe toolchain state path')
    if value is None:
        return json.loads(path.read_text())
    if path.exists():
        raise RuntimeError('Existing toolchain evidence preserved: ' + str(path))
    with path.open('x') as stream:
        stream.write(json.dumps(value, indent=2, sort_keys=True) + '\n')


def saved_bundle(recipe, directory, binding):
    record = safe_json(directory / 'built.json')
    if record.get('binding') != binding or record.get('result') != 'BUILT':
        raise RuntimeError('Toolchain build inputs changed; restore checkpoint')
    built = record['built']
    run_id = 'toolchain-' + recipe['name']
    for field, suffix in (('archive', '.tar.gz'), ('manifest', '.json')):
        expected = directory / (run_id + suffix)
        if built.get(field) != str(expected):
            raise RuntimeError('Toolchain bundle path changed')
        built[field] = expected
    validate_bundle(recipe, built)
    return built


def run_sequence(plan, root, result):
    guest_install_guard(root, result)
    if root != LFS or tuple(r['name'] for r in plan) != ORDER:
        raise RuntimeError('Toolchain root/sequence not allowlisted')
    if fingerprint(plan) != fingerprint(load_plan()):
        raise RuntimeError('Toolchain sequence differs from canonical recipe files')
    for recipe in plan:
        heavy_recipe_guard(recipe)
    inputs = safe_json(INFRA / 'inputs.json')
    authorization = safe_json(INFRA / 'phase2-authorization.json')
    capsule = validate_handoff((INFRA / 'stability-acceptance.json').read_bytes(), authorization,
                               inputs, BOOT.read_text().strip())
    binding = {'inputs_sha256': inputs['inputs_sha256'],
               'sources_sha256': sha(REPO / 'manifests/infra-sources.json'),
               'plan_sha256': fingerprint(plan), 'run_id': capsule['run_id'],
               'guest_boot_id': capsule['guest_boot_id'], 'handoff_sha256': authorization['handoff_sha256']}
    if binding['sources_sha256'] != inputs['sources_sha256']:
        raise RuntimeError('Toolchain canonical sources changed')
    if not set(packages(root)) <= set(ORDER):
        raise RuntimeError('Unexpected installed packages; start from the stability checkpoint')
    if result.is_symlink() or result.resolve() != result:
        raise RuntimeError('Unsafe toolchain evidence directory')
    result.mkdir(exist_ok=True)
    header = result / 'inputs.json'
    if header.exists():
        if safe_json(header) != binding:
            raise RuntimeError('Toolchain sequence inputs changed; restore checkpoint')
    else:
        safe_json(header, binding)
    previous = []
    actions, sanity = [], []

    def verify_prefix():
        for recipe, built, directory in previous:
            verify_installed(recipe, built, root, directory)

    # Validate all installed artifacts before any new package build/install.
    gap = False
    for recipe in plan:
        directory = result / recipe['name']
        installed = recipe['name'] in packages(root)
        receipt = directory / (recipe['name'] + '.installed.json')
        attempt = directory / 'install-started.json'
        if not installed and (attempt.exists() or attempt.is_symlink()):
            raise RuntimeError('Interrupted Alp attempt needs checkpoint recovery, never automatic retry')
        if installed or receipt.exists() or receipt.is_symlink():
            if gap or not installed or not receipt.is_file():
                raise RuntimeError('Partial/non-prefix Alp install; restore checkpoint, never silently reinstall')
            built = saved_bundle(recipe, directory, binding)
            verify_installed(recipe, built, root, directory)
            previous.append((recipe, built, directory))
        else:
            gap = True
    previous = []
    for recipe in plan:
        verify_prefix()  # Dependencies/current payloads before building their consumer.
        name = recipe['name']; directory = result / name
        if directory.is_symlink() or directory.resolve() != directory:
            raise RuntimeError('Aliased package evidence directory')
        directory.mkdir(exist_ok=True)
        state = directory / 'built.json'
        if state.is_symlink():
            raise RuntimeError('Aliased toolchain bundle record')
        if state.exists():
            built = saved_bundle(recipe, directory, binding)
        else:
            marker = directory / 'build-started.json'
            if marker.exists() or marker.is_symlink():
                raise RuntimeError('Interrupted build has no verified bundle; restore checkpoint')
            safe_json(marker, binding)
            built = build_staged(recipe, 'toolchain-' + name, directory)
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
        if name in ('glibc-cross-m64', 'glibc-cross-m32', 'libstdcxx-cross'):
            sanity.append(probe(name, root, result))  # Fresh compile/link proof, also on resume.
        actions.append({'package': name, 'action': action, 'archive_sha256': built['archive_sha256'],
                        'manifest_sha256': built['manifest_sha256']})
    verify_prefix()
    sources = safe_json(REPO / 'manifests/infra-sources.json')
    summary = {'schema': 'alpbahOS.toolchain-guest/v1', 'result': 'PASS', **binding,
               'mode': sources['abi_selection']['mode'], 'alp_sha256': sources['alp']['sha256'],
               'source_date_epoch': sources['source_date_epoch'], 'packages': actions, 'sanity': sanity,
               'scope': 'guest Chapter 4/5 only; host/stage checkpoint and full system acceptance required'}
    # Preserve every run's evidence; diagnostics are not product rootfs files.
    import time
    safe_json(result / f'summary-{time.time_ns()}.json', summary)
    return summary


def main():
    os.umask(0o022)
    base = LFS / 'results/toolchain'
    guest_install_guard(LFS, base)
    plan = load_plan()
    heavy_recipe_guard(plan[0])
    authorization = safe_json(INFRA / 'phase2-authorization.json')
    run_id = authorization['run_id']  # Strict nonce already checked by heavy guard.
    if base.resolve() != base or base.is_symlink():
        raise RuntimeError('Unsafe toolchain results parent')
    base.mkdir(exist_ok=True)
    result = base / run_id
    summary = run_sequence(plan, LFS, result)
    from toolchain_artifacts import export_guest
    export_guest(plan, LFS, result, summary)


if __name__ == '__main__':
    main()
