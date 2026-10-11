import copy
import hashlib
import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('kernel_build', REPO / 'scripts/infra-kernel-build.py')
kernel = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(kernel)


class KernelBuild(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.inputs = {'inputs_sha256': '1' * 64, 'sources_sha256': '2' * 64}
        self.boot = '12345678-1234-1234-1234-123456789abc'
        self.hashes = {name: '3' * 64 for name in kernel.HELPERS}
        self.proof = {'schema': 'alpbahOS.base-acceptance/v1', 'stage': 'base', 'result': 'PASS',
                      'run_id': 'a' * 32, 'mode': 'multilib-m32', **self.inputs,
                      'checkpoint_sha256': '4' * 64, 'transaction_sha256': '5' * 64,
                      'guest': {'schema': 'alpbahOS.base-guest-evidence/v1',
                                'result': 'VERIFIED_GUEST_BYTES', 'run_id': 'a' * 32,
                                'package_count': 79, 'final_db_sha256': '6' * 64, **self.inputs}}
        self.parent = {'schema': 'alpbahOS.kernel-parent/v1', 'result': 'VERIFIED_PARENT',
                       'stage': 'kernel', 'mode': 'multilib-m32', 'run_id': 'b' * 32,
                       'parent_run_id': 'a' * 32, 'base_acceptance_sha256': '7' * 64,
                       'checkpoint_sha256': '4' * 64, 'transaction_sha256': '5' * 64,
                       'guest_boot_id': self.boot, 'host_boot_id': self.boot, **self.inputs}
        self.auth = {'schema': 'alpbahOS.kernel-build-authorization/v1', 'result': 'AUTHORIZED',
                     'stage': 'kernel', 'mode': 'multilib-m32', 'oc_confirmed': True,
                     'run_id': 'b' * 32, 'guest_boot_id': self.boot, 'host_boot_id': self.boot,
                     'base_acceptance_sha256': '7' * 64, 'parent_sha256': '8' * 64,
                     'helper_sha256': self.hashes, 'source_sha256': kernel.SOURCE_SHA,
                     'authorized_at_ns': 10, **self.inputs}

    def bind(self):
        return kernel.binding(self.auth, self.proof, self.parent, self.inputs, self.boot,
                              self.hashes, '7' * 64, '8' * 64)

    def test_binding_is_measured_and_includes_separate_helper_bytes(self):
        result = self.bind()
        self.assertEqual(result['base_acceptance_sha256'], '7' * 64)
        self.assertEqual(result['run_id'], 'b' * 32)
        self.assertEqual(set(result['helper_sha256']), set(kernel.HELPERS))
        self.assertNotIn('PASS', result.values())

    def test_partial_base_and_missing_checkpoint_are_rejected(self):
        original = copy.deepcopy(self.proof)
        for change in ('count', 'result', 'db', 'checkpoint', 'guest-input'):
            self.proof = copy.deepcopy(original)
            if change == 'count': self.proof['guest']['package_count'] = 78
            if change == 'result': self.proof['result'] = 'PENDING_PRIVILEGED_POST'
            if change == 'db': self.proof['guest']['final_db_sha256'] = ''
            if change == 'checkpoint': del self.proof['checkpoint_sha256']
            if change == 'guest-input': self.proof['guest']['inputs_sha256'] = '9' * 64
            with self.subTest(change=change), self.assertRaises(RuntimeError): self.bind()

    def test_stale_boot_parent_source_helper_and_authorization_fail(self):
        original = copy.deepcopy(self.auth)
        for key, value in [('guest_boot_id', 'other'), ('host_boot_id', 'bad'),
                           ('oc_confirmed', False), ('run_id', 'c' * 32),
                           ('source_sha256', '0' * 64), ('parent_sha256', '0' * 64),
                           ('helper_sha256', {}), ('authorized_at_ns', True),
                           ('inputs_sha256', '0' * 64)]:
            self.auth = copy.deepcopy(original); self.auth[key] = value
            with self.subTest(key=key), self.assertRaises(RuntimeError): self.bind()
        self.auth = original; self.parent['parent_run_id'] = 'c' * 32
        with self.assertRaisesRegex(RuntimeError, 'capsule'): self.bind()

    def test_unprivileged_host_execution_fails_before_any_write_or_command(self):
        with patch('os.geteuid', return_value=1000), patch.object(kernel, 'run_logged') as run:
            with self.assertRaisesRegex(RuntimeError, 'host invocation refused'): kernel.execute()
            run.assert_not_called()

    def test_target_compilation_has_clean_chroot_environment_and_numeric_user(self):
        with patch.dict(os.environ, {'CFLAGS': '-march=native', 'LD_LIBRARY_PATH': '/wrong'}):
            env = kernel.environment(1756684800)
        argv = kernel.chroot_command(['make', '-j4'], env)
        self.assertEqual(argv[:5], ['/usr/sbin/chroot', '--userspec=1001:1001', '/srv/lfs', '/usr/bin/env', '-i'])
        self.assertNotIn('CFLAGS', env); self.assertNotIn('LD_LIBRARY_PATH', env)
        with patch.dict(os.environ, {'TAR_OPTIONS': '--checkpoint-action=exec=bad', 'PATH': '/wrong'}):
            native = kernel.native_environment(1756684800)
        self.assertEqual(native['PATH'], '/usr/bin:/bin:/usr/sbin:/sbin')
        self.assertEqual(set(native), {'PATH', 'LC_ALL', 'LANG', 'TZ', 'SOURCE_DATE_EPOCH'})
        self.assertEqual(env['KBUILD_BUILD_VERSION'], '1')
        self.assertEqual(env['KBUILD_BUILD_TIMESTAMP'], 'Mon Sep 01 00:00:00 UTC 2025')
        self.assertEqual(argv[-2:], ['make', '-j4'])
        with self.assertRaises(RuntimeError): kernel.environment(0)

    def test_reproducibility_controls_fail_when_source_dependency_drops_them(self):
        path = self.root / '.config'
        text = '# Linux/x86_64 6.16.1 Kernel Configuration\n' + kernel.configuration.fragment()
        text += ''.join(k + '=' + v + '\n' for k, v in kernel.CONTROLS.items())
        path.write_text(text); kernel.controls(path)
        path.write_text(text.replace('CONFIG_RANDSTRUCT_NONE=y', 'CONFIG_RANDSTRUCT_NONE=n'))
        with self.assertRaisesRegex(RuntimeError, 'controls'): kernel.controls(path)

    def stage_fixture(self):
        stage, build = self.root / 'stage', self.root / 'build'
        source = stage / 'lib/modules/6.16.1'
        source.mkdir(parents=True); build.mkdir()
        (source / 'build').symlink_to('/build/kernel-6.16.1')
        (source / 'modules.dep').write_text('fixture')
        return stage, build, source

    def test_relocation_only_removes_exact_known_build_alias_and_preserves_module_bytes(self):
        stage, build, source = self.stage_fixture()
        kernel.relocate(stage, build)
        target = stage / 'usr/lib/modules/6.16.1'
        self.assertFalse(os.path.lexists(target / 'build'))
        self.assertEqual((target / 'modules.dep').read_text(), 'fixture')
        self.assertFalse((stage / 'lib').exists())

    def test_relocation_refuses_alias_drift_or_aliased_destination_before_mutation(self):
        stage, build, source = self.stage_fixture()
        alias = source / 'build'; alias.unlink(); alias.symlink_to('/other')
        with self.assertRaisesRegex(RuntimeError, 'alias drift'): kernel.relocate(stage, build)
        self.assertTrue(alias.is_symlink())
        alias.unlink(); alias.symlink_to('/build/kernel-6.16.1')
        (stage / 'usr').symlink_to(self.root)
        with self.assertRaisesRegex(RuntimeError, 'target preserved'): kernel.relocate(stage, build)
        self.assertTrue(alias.is_symlink()); self.assertTrue(source.is_dir())

    def test_raw_db_change_is_rejected_before_parent_manifest_processing(self):
        db = self.root / 'var/lib/alp/db.json'; db.parent.mkdir(parents=True); db.write_text('{}')
        with patch.object(kernel, 'LFS', self.root):
            with self.assertRaisesRegex(RuntimeError, 'raw DB changed'): kernel.base_payload(self.proof, [])

    def test_parent_rehash_rejects_installed_payload_drift_after_manifest_pin(self):
        plan = []
        installed = {name: {} for name in ('filesystem-layout', 'binutils-pass1', 'gcc-pass1',
                     'linux-headers', 'glibc-cross-m64', 'glibc-cross-m32', 'libstdcxx-cross')}
        artifacts = {}
        for i in range(79):
            name = 'fixture-' + str(i); path = self.root / ('usr/share/' + name)
            path.parent.mkdir(parents=True, exist_ok=True); path.write_text(name)
            entry = kernel.compare.record_path(path, 'usr/share/' + name)
            installed[name] = {'files': [entry['path']], 'symlinks': []}
            row = {'name': name, 'version': '1', 'source': {'url': 'https://example.invalid/source', 'sha256': '0' * 64}}
            manifest = {'schema': 'alpbahOS.package-files/v1', 'package': {'name': name, 'version': '1', 'source': row['source']}, 'entries': [entry]}
            out = self.root / 'results/base' / self.proof['run_id'] / name / ('base-' + name + '.json')
            out.parent.mkdir(parents=True); out.write_text(json.dumps(manifest))
            artifacts['guest-base/' + name + '/base-' + name + '.json'] = kernel.sha(out)
            plan.append(row)
        db = self.root / 'var/lib/alp/db.json'; db.parent.mkdir(parents=True)
        db.write_text(json.dumps({'schema_version': 1, 'packages': installed}))
        self.proof['guest']['final_db_sha256'] = kernel.sha(db); self.proof['artifact_sha256'] = artifacts
        with patch.object(kernel, 'LFS', self.root), patch.object(kernel.guest_handoff, 'existing'):
            kernel.base_payload(self.proof, plan)
            (self.root / 'usr/share/fixture-78').write_text('changed')
            with self.assertRaisesRegex(RuntimeError, 'installed payload changed'): kernel.base_payload(self.proof, plan)
        self.assertEqual(hashlib.sha256(db.read_bytes()).hexdigest(), self.proof['guest']['final_db_sha256'])
