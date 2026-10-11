#!/usr/bin/env python3
"""Guarded guest-only kernel source -> build -> DESTDIR -> candidate bundle.

Requires a future host controller's measured, root-owned accepted-Base handoff.
No authorization producer or host launcher is supplied here. Never installs a
kernel, edits Alp, mounts filesystems, boots a VM or emits stage acceptance.
Interrupted trees/markers are preserved; restore the accepted Base checkpoint.
"""
import hashlib
import importlib.util
import json
import os
import pwd
import re
import signal
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / 'scripts/infra'))
import base_plan
import buildctl
import guest_handoff
import package_install
import package_stage
from filesystem_layout import require_layout
from guest_process import run_logged

LFS = Path('/srv/lfs')
INFRA = Path('/srv/infra')
BOOT = Path('/proc/sys/kernel/random/boot_id')
VERSION = '6.16.1'
SOURCE = 'linux-6.16.1.tar.xz'
SOURCE_SHA = 'ea43491bc7ace1e414b3b2d957f8cf96e7049155123f0acce798accf8da1acba'
HELPERS = ('infra-kernel-build.py', 'infra-kernel-config.py', 'infra-kernel-payload.py')
SOURCE_RULES = {
    'Makefile': '803380a08254402342d4953c68845b4ed57183f527fd1d798249cbf10e71eaa1',
    'scripts/Makefile.modinst': 'd7f7efd72c780532b4d6ae481946bf32af7771954d359284d805088b2a7f47d1',
    'scripts/depmod.sh': '90723b3a92b8b86b8990c7a1a415e51a19d6e2e1c3b5c83edc6e1bcbe7425ee4',
    'arch/x86/boot/header.S': '285bf5bda95d48912b284529fcb5bcede1287780a95897cb95f6fe5a37000b2f',
}
CONTROLS = {'CONFIG_LOCALVERSION': '""', 'CONFIG_LOCALVERSION_AUTO': 'n',
            'CONFIG_MODULE_COMPRESS': 'n', 'CONFIG_MODULE_SIG': 'n',
            'CONFIG_RANDSTRUCT_NONE': 'y', 'CONFIG_BUILD_SALT': '"alpbahOS-6.16.1"'}


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


configuration = load('kernel_build_configuration', REPO / 'scripts/infra-kernel-config.py')
payload = load('kernel_build_payload', REPO / 'scripts/infra-kernel-payload.py')
compare = load('kernel_base_compare', REPO / 'scripts/compare-package-manifest.py')


def sha(path):
    return package_stage.sha(Path(path))


def read_record(path):
    guest_handoff.existing(path)
    if not path.is_file() or path.stat().st_size > 16 * 1024 * 1024:
        raise RuntimeError('Kernel handoff record missing or oversized')
    raw = path.read_bytes()
    return raw, json.loads(raw)


def binding(auth, proof, parent, inputs, boot_id, helper_hashes, proof_sha, parent_sha):
    for field in ('run_id', 'parent_run_id'):
        if not re.fullmatch('[0-9a-f]{32}', str(parent.get(field, ''))):
            raise RuntimeError('Kernel handoff run identity invalid')
    for field in ('inputs_sha256', 'sources_sha256'):
        if not re.fullmatch('[0-9a-f]{64}', str(inputs.get(field, ''))):
            raise RuntimeError('Kernel handoff input hash invalid')
    if (proof.get('schema') != 'alpbahOS.base-acceptance/v1'
            or proof.get('result') != 'PASS' or proof.get('stage') != 'base'
            or proof.get('mode') != 'multilib-m32'
            or proof.get('guest', {}).get('schema') != 'alpbahOS.base-guest-evidence/v1'
            or proof.get('guest', {}).get('result') != 'VERIFIED_GUEST_BYTES'
            or proof.get('guest', {}).get('package_count') != 79
            or proof.get('guest', {}).get('run_id') != proof.get('run_id')
            or any(proof.get(field) != inputs[field] or proof.get('guest', {}).get(field) != inputs[field]
                   for field in ('inputs_sha256', 'sources_sha256'))
            or not re.fullmatch('[0-9a-f]{64}', str(proof.get('guest', {}).get('final_db_sha256', '')))):
        raise RuntimeError('Kernel requires complete accepted Base guest proof')
    for field in ('checkpoint_sha256', 'transaction_sha256'):
        if not re.fullmatch('[0-9a-f]{64}', str(proof.get(field, ''))):
            raise RuntimeError('Kernel accepted Base checkpoint/transaction pin missing')
    if (parent.get('schema') != 'alpbahOS.kernel-parent/v1' or parent.get('result') != 'VERIFIED_PARENT'
            or parent.get('stage') != 'kernel' or parent.get('mode') != 'multilib-m32'
            or parent.get('parent_run_id') != proof.get('run_id')
            or parent.get('base_acceptance_sha256') != proof_sha
            or any(parent.get(field) != proof.get(field) for field in ('inputs_sha256', 'sources_sha256',
                   'checkpoint_sha256', 'transaction_sha256'))
            or parent.get('guest_boot_id') != boot_id):
        raise RuntimeError('Kernel measured parent capsule differs from accepted Base')
    if (auth.get('schema') != 'alpbahOS.kernel-build-authorization/v1'
            or auth.get('result') != 'AUTHORIZED' or auth.get('stage') != 'kernel'
            or auth.get('mode') != 'multilib-m32' or auth.get('oc_confirmed') is not True
            or auth.get('run_id') != parent['run_id'] or auth.get('guest_boot_id') != boot_id
            or auth.get('host_boot_id') != parent.get('host_boot_id')
            or not re.fullmatch(r'[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}', str(auth.get('host_boot_id', '')))
            or any(auth.get(field) != inputs[field] for field in ('inputs_sha256', 'sources_sha256'))
            or auth.get('base_acceptance_sha256') != proof_sha or auth.get('parent_sha256') != parent_sha
            or auth.get('source_sha256') != SOURCE_SHA or auth.get('helper_sha256') != helper_hashes
            or type(auth.get('authorized_at_ns')) is not int or auth['authorized_at_ns'] <= 0):
        raise RuntimeError('Kernel guest boot/auth/helper/source pins disagree')
    return {'schema': 'alpbahOS.kernel-build-binding/v1', 'run_id': parent['run_id'],
            'guest_boot_id': boot_id, 'host_boot_id': auth['host_boot_id'],
            'base_acceptance_sha256': proof_sha, 'parent_sha256': parent_sha,
            'inputs_sha256': inputs['inputs_sha256'], 'sources_sha256': inputs['sources_sha256'],
            'helper_sha256': helper_hashes, 'source_sha256': SOURCE_SHA}


def base_payload(proof, plan):
    db = LFS / 'var/lib/alp/db.json'
    if sha(db) != proof['guest']['final_db_sha256']:
        raise RuntimeError('Accepted Base raw DB changed before kernel build')
    installed = package_install.packages(LFS)
    initial = {'filesystem-layout', 'binutils-pass1', 'gcc-pass1', 'linux-headers',
               'glibc-cross-m64', 'glibc-cross-m32', 'libstdcxx-cross'}
    if len(plan) != 79 or set(installed) != initial | {row['name'] for row in plan}:
        raise RuntimeError('Kernel parent is not the exact accepted Base package set')
    for row in plan:
        name = row['name']
        path = LFS / 'results/base' / proof['run_id'] / name / ('base-' + name + '.json')
        raw, manifest = read_record(path)
        key = 'guest-base/' + name + '/base-' + name + '.json'
        if hashlib.sha256(raw).hexdigest() != proof.get('artifact_sha256', {}).get(key):
            raise RuntimeError('Kernel parent package manifest differs from accepted exported bytes')
        expected = {'name': name, 'version': row['version'],
                    'source': {'url': row['source']['url'], 'sha256': row['source']['sha256']}}
        if manifest.get('schema') != 'alpbahOS.package-files/v1' or manifest.get('package') != expected:
            raise RuntimeError('Kernel Base package/source identity differs')
        package_install.ownership_check(LFS, manifest, installed, name)
        for entry in manifest['entries']:
            relative = package_install.member_path(entry['path'].lstrip('/'))
            package_install.canonical_key(LFS, relative)
            if compare.record_path(LFS / relative, relative) != entry:
                raise RuntimeError('Accepted Base installed payload changed: ' + entry['path'])
    if sha(db) != proof['guest']['final_db_sha256']:
        raise RuntimeError('Accepted Base DB drift during kernel preflight')


def environment(epoch):
    if epoch != 1756684800:
        raise RuntimeError('Kernel source date epoch changed')
    return {'PATH': '/usr/bin:/bin:/usr/sbin:/sbin', 'LC_ALL': 'C', 'LANG': 'C', 'TZ': 'UTC',
            'HOME': '/build/kernel-6.16.1', 'TMPDIR': '/build/kernel-6.16.1/.tmp',
            'SOURCE_DATE_EPOCH': str(epoch), 'KBUILD_BUILD_TIMESTAMP': datetime.fromtimestamp(epoch, timezone.utc).strftime('%a %b %d %H:%M:%S UTC %Y'),
            'KBUILD_BUILD_USER': 'alp', 'KBUILD_BUILD_HOST': 'builder', 'KBUILD_BUILD_VERSION': '1',
            'KCONFIG_NOTIMESTAMP': '1', 'ARCH': 'x86_64',
            'KCFLAGS': '-fdebug-prefix-map=/build/kernel-6.16.1=/usr/src/linux-6.16.1'}


def native_environment(epoch):
    target = environment(epoch)
    return {key: target[key] for key in ('PATH', 'LC_ALL', 'LANG', 'TZ', 'SOURCE_DATE_EPOCH')}


def chroot_command(argv, env):
    return ['/usr/sbin/chroot', '--userspec=1001:1001', str(LFS), '/usr/bin/env', '-i',
            *[key + '=' + value for key, value in sorted(env.items())], *argv]


def controls(path):
    configuration.verify(path)
    actual = configuration.parse(path.read_bytes())
    if any(actual.get(key) != value for key, value in CONTROLS.items()):
        raise RuntimeError('Kernel reproducibility controls did not resolve')


def relocate(stage, build):
    """Only exact staged module tree/known upstream build alias can be changed."""
    if stage.resolve() != stage or stage.is_symlink() or build.resolve() != build:
        raise RuntimeError('Kernel staging tree is aliased')
    source = stage / 'lib/modules' / VERSION
    if source.resolve() != source or source.is_symlink() or not source.is_dir():
        raise RuntimeError('Upstream staged module directory missing or aliased')
    alias = source / 'build'
    if not alias.is_symlink() or os.readlink(alias) != '/build/kernel-6.16.1':
        raise RuntimeError('Upstream module build alias drift; preserve stage')
    target = stage / 'usr/lib/modules' / VERSION
    if target.exists() or target.is_symlink() or target.resolve() != target:
        raise RuntimeError('Existing usr-merge module target preserved')
    target.parent.mkdir(parents=True)
    alias.unlink()  # Exact checked alias only; never recursive deletion.
    source.rename(target)
    (stage / 'lib/modules').rmdir()
    (stage / 'lib').rmdir()


def execute():
    result_parent = LFS / 'results/kernel'
    package_install.guest_install_guard(LFS, result_parent)  # Before writes/commands, host invocation fails.
    if REPO != Path('/opt/alp-infra'):
        raise RuntimeError('Kernel producer requires the guarded Builder repository')
    os.umask(0o022)
    require_layout(LFS)
    inputs_raw, inputs = read_record(INFRA / 'inputs.json')
    auth_raw, auth = read_record(INFRA / 'kernel-build-authorization.json')
    proof_raw, proof = read_record(INFRA / 'kernel-base-acceptance.json')
    parent_raw, parent = read_record(INFRA / 'kernel-parent.json')
    sources_raw, sources = read_record(REPO / 'manifests/infra-sources.json')
    hashes = {}
    for name in HELPERS:
        path = REPO / 'scripts' / name
        guest_handoff.existing(path)
        hashes[name] = sha(path)
    current = binding(auth, proof, parent, inputs, BOOT.read_text().strip(), hashes,
                      hashlib.sha256(proof_raw).hexdigest(), hashlib.sha256(parent_raw).hexdigest())
    if (inputs['inputs_sha256'] != buildctl.inputs_digest()
            or inputs['sources_sha256'] != hashlib.sha256(sources_raw).hexdigest()
            or sources.get('abi_selection', {}).get('mode') != 'multilib-m32'):
        raise RuntimeError('Current kernel/Base source and canonical inputs changed')
    item = package_stage.source_pin(sources, SOURCE, REPO)
    source = LFS / 'sources' / SOURCE
    guest_handoff.existing(source)
    if item['sha256'] != SOURCE_SHA or item['url'] != payload.SOURCE_URL or sha(source) != SOURCE_SHA:
        raise RuntimeError('Pinned kernel source bytes changed')
    plan = base_plan.load(REPO)
    base_payload(proof, plan)
    user = pwd.getpwnam('lfs')
    if (user.pw_uid, user.pw_gid) != (1001, 1001):
        raise RuntimeError('Kernel unprivileged Builder identity changed')
    env = environment(sources['source_date_epoch'])
    native = native_environment(sources['source_date_epoch'])
    build, stage = LFS / 'build/kernel-6.16.1', LFS / 'stage/kernel-6.16.1'
    result = result_parent / current['run_id']
    for path in (build, stage, result):
        if path.exists() or path.is_symlink() or path.resolve() != path:
            raise RuntimeError('Existing/interrupted kernel attempt preserved; restore accepted Base')
    for path in (build.parent, stage.parent, result_parent, INFRA):
        guest_handoff.directory(path)
    attempts = INFRA / 'kernel-attempts'
    if not attempts.exists(): attempts.mkdir(mode=0o700)
    guest_handoff.directory(attempts)
    guest_handoff.exclusive(attempts / (current['run_id'] + '.json'), guest_handoff.encoded(current))
    result.mkdir(mode=0o700)
    guest_handoff.exclusive(result / 'inputs.json', guest_handoff.encoded(current))
    log = result / 'kernel-build.log'
    def run(argv):
        run_logged(argv, log, env=native)
    def interrupted(signum, frame):
        raise RuntimeError('Kernel build interrupted; preserve evidence and restore accepted Base')
    old_handlers = {sig: signal.signal(sig, interrupted) for sig in (signal.SIGTERM, signal.SIGINT)}
    started = time.monotonic()
    try:
        build.mkdir(); stage.mkdir()
        run(['chown', '1001:1001', str(build), str(stage)])
        run(['/usr/sbin/runuser', '-u', 'lfs', '--', 'tar', '--no-same-owner',
                    '-xf', str(source), '--strip-components=1', '-C', str(build)])
        for name, expected in SOURCE_RULES.items():
            path = build / name
            if path.resolve() != path or path.is_symlink() or sha(path) != expected:
                raise RuntimeError('Actual kernel source hook changed: ' + name)
        run(chroot_command(['/bin/bash', '-c', 'test "$(/usr/bin/gcc -dumpfullversion)" = 15.2.0'], env))
        run(chroot_command(['make', '-C', '/build/kernel-6.16.1', 'mrproper'], env))
        (build / '.tmp').mkdir(); os.chown(build / '.tmp', 1001, 1001)
        run(chroot_command(['make', '-C', '/build/kernel-6.16.1', 'x86_64_defconfig'], env))
        fragment = build / '.alp-required.config'
        fragment.write_text(configuration.fragment() + ''.join(key + '=' + value + '\n' for key, value in CONTROLS.items()))
        os.chown(fragment, 1001, 1001)
        run(chroot_command(['bash', '-c', 'cd /build/kernel-6.16.1 && bash scripts/kconfig/merge_config.sh -m .config .alp-required.config'], env))
        run(chroot_command(['make', '-C', '/build/kernel-6.16.1', 'olddefconfig'], env))
        controls(build / '.config')
        run(chroot_command(['make', '-C', '/build/kernel-6.16.1', '-j4', 'bzImage', 'modules'], env))
        if (build / 'include/config/kernel.release').read_text() != VERSION + '\n':
            raise RuntimeError('Built kernel release drift')
        run(chroot_command(['make', '-C', '/build/kernel-6.16.1', 'INSTALL_MOD_PATH=/stage/kernel-6.16.1', 'modules_install'], env))
        relocate(stage, build)
        (stage / 'boot').mkdir()
        for original, installed in [('arch/x86/boot/bzImage', 'vmlinuz-6.16.1-alpbahOS'),
                                    ('System.map', 'System.map-6.16.1'), ('.config', 'config-6.16.1')]:
            run(['install', '-m644', str(build / original), str(stage / 'boot' / installed)])
        docs = stage / 'usr/share/doc/linux-6.16.1'
        docs.parent.mkdir(parents=True)
        run(['cp', '-a', str(build / 'Documentation'), str(docs)])
        run(['chown', '-hR', '-P', '0:0', str(stage)])
        recipe = {'name': 'linux-kernel', 'version': VERSION, 'source': SOURCE, 'phase': 'kernel'}
        built = package_stage.pack_staged(recipe, stage, result, 'kernel', item, native,
                                         round(time.monotonic() - started, 3))
        candidate = payload.verify(stage, built['manifest'])
        if candidate['numeric_owner'] != {'uid': 0, 'gid': 0}:
            raise RuntimeError('Kernel candidate numeric ownership was not normalized')
        package_install.validate_bundle(recipe, built)
        base_payload(proof, plan)
        if ({name: sha(REPO / 'scripts' / name) for name in HELPERS} != hashes
                or (INFRA / 'inputs.json').read_bytes() != inputs_raw
                or (INFRA / 'kernel-build-authorization.json').read_bytes() != auth_raw
                or (INFRA / 'kernel-base-acceptance.json').read_bytes() != proof_raw
                or (INFRA / 'kernel-parent.json').read_bytes() != parent_raw
                or sha(source) != SOURCE_SHA or buildctl.inputs_digest() != current['inputs_sha256']):
            raise RuntimeError('Kernel build input/auth/parent drift; preserve evidence')
        summary = {'schema': 'alpbahOS.kernel-build/v1', 'result': 'BUILT_CANDIDATE',
                   'binding': current, 'candidate': candidate,
                   'built': {k: str(v) if isinstance(v, Path) else v for k, v in built.items()},
                   'scope': 'guest kernel candidate bundle only; Alp install, host audits/checkpoint, boot and stage acceptance required'}
        guest_handoff.exclusive(result / 'summary.json', guest_handoff.encoded(summary))
        return summary
    finally:
        for sig, handler in old_handlers.items(): signal.signal(sig, handler)


if __name__ == '__main__':
    try:
        if len(sys.argv) != 1: raise RuntimeError('No kernel bypass/resume/job flags accepted')
        print(json.dumps(execute(), sort_keys=True))
    except (RuntimeError, OSError, ValueError, KeyError) as error:
        raise SystemExit('STOP: ' + str(error))
