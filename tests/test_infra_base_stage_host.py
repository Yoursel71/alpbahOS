import importlib.util
import hashlib
import json
import os
from pathlib import Path
import runpy
import sys
import tempfile
import types
import unittest
from unittest.mock import Mock, patch


SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/infra-base-stage.py'
SPEC = importlib.util.spec_from_file_location('infra_base_stage_host_test', SCRIPT)
base_stage = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(base_stage)
HELPER_PATH = Path(__file__).resolve().parents[1] / 'scripts/infra-base-authorize.py'
HELPER_SPEC = importlib.util.spec_from_file_location('infra_base_authorize_test', HELPER_PATH)
base_authorize = importlib.util.module_from_spec(HELPER_SPEC)
HELPER_SPEC.loader.exec_module(base_authorize)


class BaseStageHostAuthorizationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.proof = json.loads(base_stage.TOOLCHAIN_ACCEPTANCE.read_bytes())
        cls.parent_raw = (base_stage.stage_runs.RUNS / cls.proof['run_id'] / 'parent.json').read_bytes()
        run_artifacts = base_stage.stage_runs.ARTIFACTS / cls.proof['run_id']
        cls.old_authorization = (run_artifacts / 'authorization.json').read_bytes()
        cls.old_handoff = (run_artifacts / 'handoff.json').read_bytes()
        cls.inputs = base_stage.encoded({'inputs_sha256': cls.proof['inputs_sha256'],
                                         'sources_sha256': cls.proof['sources_sha256']})
        cls.plan = base_stage.base_plan.load(base_stage.REPO)

    def test_toolchain_parent_identities_follow_current_receipts(self):
        run_id, audit_id, parent_run_id = 'a' * 32, 'b' * 32, 'c' * 32
        proof = {'run_id': run_id, 'after_audit_id': audit_id}
        transaction = {'acceptance': {'run_id': run_id}}
        parent = {'run_id': run_id, 'parent_run_id': parent_run_id,
                  'stage': 'toolchain', 'mode': 'multilib-m32'}
        self.assertEqual(base_stage.toolchain_parent_ids(proof, transaction, parent),
                         (run_id, audit_id, parent_run_id))

    def test_toolchain_parent_identity_mismatch_is_rejected(self):
        proof = {'run_id': 'a' * 32, 'after_audit_id': 'b' * 32}
        transaction = {'acceptance': {'run_id': 'd' * 32}}
        parent = {'run_id': 'a' * 32, 'parent_run_id': 'c' * 32,
                  'stage': 'toolchain', 'mode': 'multilib-m32'}
        with self.assertRaisesRegex(RuntimeError, 'identities do not match'):
            base_stage.toolchain_parent_ids(proof, transaction, parent)

    def test_toolchain_parent_identity_must_use_stage_run_ids(self):
        proof = {'run_id': 'a' * 32, 'after_audit_id': 'bad-id'}
        transaction = {'acceptance': {'run_id': 'a' * 32}}
        parent = {'run_id': 'a' * 32, 'parent_run_id': 'c' * 32,
                  'stage': 'toolchain', 'mode': 'multilib-m32'}
        with self.assertRaisesRegex(RuntimeError, 'Invalid stage run identity'):
            base_stage.toolchain_parent_ids(proof, transaction, parent)

    def setUp(self):
        records = {
            'cat /srv/infra/phase2-authorization.json': self.old_authorization,
            'cat /srv/infra/stability-acceptance.json': self.old_handoff,
            'cat /srv/infra/inputs.json': self.inputs,
        }
        self.read = patch.object(base_stage, 'guest_read', side_effect=lambda cmd, limit=262144: records[cmd])
        self.read.start()
        self.addCleanup(self.read.stop)

    def test_parent_handoff_is_rebound_to_the_measured_current_guest_boot(self):
        guest_boot = '11111111-2222-4333-8444-555555555555'
        with patch.object(base_stage.buildctl, 'inputs_digest', return_value=self.proof['inputs_sha256']):
            payload, authorization, base_auth, receipt = base_stage.package_auth(
                self.plan, 'a' * 32, guest_boot, self.proof, self.parent_raw)

        handoff = json.loads(payload['handoff_raw'])
        self.assertNotEqual(handoff['guest_boot_id'], json.loads(self.old_handoff)['guest_boot_id'])
        self.assertEqual(handoff['guest_boot_id'], guest_boot)
        self.assertEqual(authorization['handoff_sha256'], base_stage.digest(payload['handoff_raw'].encode()))
        self.assertEqual(base_auth['guest_boot_id'], guest_boot)
        self.assertEqual(base_auth['guest_runner_sha256'], base_stage.sha(base_stage.GUEST_RUNNER))
        self.assertEqual(receipt['proof_sha256'], base_stage.digest(base_stage.TOOLCHAIN_ACCEPTANCE.read_bytes()))

    def test_old_guest_auth_pair_must_be_intact_before_rebinding(self):
        old = json.loads(self.old_authorization)
        old['handoff_sha256'] = '0' * 64
        base_stage.guest_read.side_effect = lambda cmd, limit=262144: {
            'cat /srv/infra/phase2-authorization.json': base_stage.encoded(old),
            'cat /srv/infra/stability-acceptance.json': self.old_handoff,
            'cat /srv/infra/inputs.json': self.inputs,
        }[cmd]
        with self.assertRaisesRegex(RuntimeError, 'stale inputs or unpaired evidence'):
            base_stage.package_auth(self.plan, 'b' * 32,
                '11111111-2222-4333-8444-555555555555', self.proof, self.parent_raw)

    def test_guest_installer_atomically_refreshes_the_pair_and_installs_base_token(self):
        guest_boot = '11111111-2222-4333-8444-555555555555'
        with patch.object(base_stage.buildctl, 'inputs_digest', return_value=self.proof['inputs_sha256']):
            payload, authorization, base_auth, receipt = base_stage.package_auth(
                self.plan, 'c' * 32, guest_boot, self.proof, self.parent_raw)
        with tempfile.TemporaryDirectory() as directory:
            infra = Path(directory) / 'infra'; infra.mkdir(mode=0o700)
            inputs = infra / 'inputs.json'
            inputs.write_bytes(self.inputs); inputs.chmod(0o600)
            for name, raw in (('phase2-authorization.json', self.old_authorization),
                              ('stability-acceptance.json', self.old_handoff)):
                path = infra / name; path.write_bytes(raw); path.chmod(0o600)
            sources = Path(directory) / 'infra-sources.json'
            sources.write_bytes((base_stage.REPO / 'manifests/infra-sources.json').read_bytes())
            guest_runner = Path(directory) / 'infra-base-guest-run.py'
            guest_runner.write_bytes(base_stage.GUEST_RUNNER.read_bytes())
            boot = Path(directory) / 'boot-id'; boot.write_text(guest_boot)
            with (patch.object(base_authorize, 'INFRA', infra),
                  patch.object(base_authorize, 'SOURCES', sources),
                  patch.object(base_authorize, 'GUEST_RUNNER', guest_runner),
                  patch.object(base_authorize, 'BOOT', boot),
                  patch.object(base_authorize, 'guest_install_guard'),
                  patch.object(base_authorize.os, 'geteuid', return_value=0)):
                installed = base_authorize.install(base_stage.encoded(payload))
            self.assertEqual(installed['result'], 'INSTALLED')
            self.assertEqual(installed['guest_runner_sha256'], base_stage.sha(guest_runner))
            self.assertEqual(json.loads((infra / 'phase2-authorization.json').read_bytes()), authorization)
            self.assertEqual((infra / 'stability-acceptance.json').read_bytes(), payload['handoff_raw'].encode())
            self.assertEqual(json.loads((infra / 'toolchain-acceptance.json').read_bytes()), receipt)
            self.assertEqual(json.loads((infra / 'base-authorization.json').read_bytes()), base_auth)
            self.assertEqual(installed['base_authorization_sha256'], base_stage.digest(
                (infra / 'base-authorization.json').read_bytes()))

    def test_guest_runner_resolves_separate_build_paths_from_source_root(self):
        import package_stage
        original = package_stage.recipe_working_directory
        original_run = package_stage.run
        with tempfile.TemporaryDirectory() as directory:
            build_root = Path(directory) / 'build'
            source = build_root / 'glibc-source'; source.mkdir(parents=True)
            (source / 'Makefile').write_text('')
            work = source / 'build'; work.mkdir()
            (work / 'config.make').write_text('')
            fake_guest = types.SimpleNamespace(main=lambda: None, install_staged=lambda *args, **kwargs: None)
            with (patch.dict(sys.modules, {'guest_base': fake_guest}),
                  patch.object(sys, 'argv', [str(base_stage.GUEST_RUNNER),
                                             base_stage.sha(base_stage.GUEST_RUNNER)])):
                runner = runpy.run_path(str(base_stage.GUEST_RUNNER), run_name='__main__')
            try:
                resolved = package_stage.recipe_working_directory(
                    work, {'separate_build': True, 'working_directories': {'compile': 'build'}},
                    'compile')
                self.assertEqual(resolved, work)
                self.assertEqual(runner['root_test_tree'](work, build_root), source)
                self.assertFalse(runner['uses_m32_uapi_build'](None))
                self.assertEqual(runner['disable_unavailable_m32_cxx'](['tar', '-xf', 'source'], None),
                                 ['tar', '-xf', 'source'])
                self.assertEqual(runner['prepare_m32_kernel_headers'](
                    ['env', 'CC=gcc -m32', 'CXX=g++ -m32', '../configure'],
                    '/custom/include'),
                    ['env',
                     'CC=/srv/lfs/tools/bin/x86_64-lfs-linux-gnu-gcc -m32 -I/custom/include',
                     'CXX=/srv/lfs/tools/bin/x86_64-lfs-linux-gnu-g++ -m32 -static-libgcc -I/custom/include',
                     '../configure'])
                cross_configure = ['env',
                    'CC=/srv/lfs/tools/bin/x86_64-lfs-linux-gnu-gcc -m32',
                    'CXX=/srv/lfs/tools/bin/x86_64-lfs-linux-gnu-g++ -m32 -static-libgcc',
                    '../configure']
                prepared_cross = runner['prepare_m32_kernel_headers'](
                    cross_configure, '/custom/include')
                self.assertEqual(prepared_cross, ['env',
                    'CC=/srv/lfs/tools/bin/x86_64-lfs-linux-gnu-gcc -m32 -I/custom/include',
                    'CXX=/srv/lfs/tools/bin/x86_64-lfs-linux-gnu-g++ -m32 -static-libgcc -I/custom/include',
                    '../configure'])
                self.assertTrue(runner['uses_m32_uapi_configure'](prepared_cross,
                                                                  '/custom/include'))
                self.assertEqual(runner['prepare_m32_kernel_headers'](
                    ['make', '-j4']), ['make', '-j4'])
                kernel_source = Path(directory) / 'kernel-source'
                kernel_include = Path(directory) / 'kernel-only-include'
                for name in ('asm', 'asm-generic', 'linux'):
                    (kernel_source / name).mkdir(parents=True)
                (kernel_source / 'asm/errno.h').write_text('/* pinned UAPI */\n')
                installed = runner['install_m32_kernel_headers'](
                    kernel_source, kernel_include)
                self.assertEqual(installed, kernel_include)
                self.assertEqual({path.name for path in kernel_include.iterdir()},
                                 {'asm', 'asm-generic', 'linux'})
                for name in ('asm', 'asm-generic', 'linux'):
                    self.assertTrue((kernel_include / name).is_symlink())
                    self.assertEqual((kernel_include / name).resolve(),
                                     (kernel_source / name).resolve())
                self.assertTrue((kernel_include / 'asm/errno.h').is_file())
                runner_globals = runner['run_with_root_owned_test_tree'].__globals__
                root_test_tree = runner_globals['root_test_tree']
                with patch.object(package_stage, 'run') as run, patch.dict(
                        runner_globals, {'_run': run, 'root_test_tree':
                                 lambda path: root_test_tree(path, build_root)}):
                    runner['run_with_root_owned_test_tree'](
                        [package_stage.RUNUSER, '-u', 'root', '--', 'env'],
                        Path(directory) / 'test.log', cwd=work)
                    self.assertEqual(run.call_args_list[0].args[0],
                                     ['chown', '-hR', 'root:root', str(source)])
                    self.assertEqual(run.call_args_list[1].args[0][0], package_stage.RUNUSER)
                with patch.object(package_stage, 'run') as run, patch.dict(
                        runner_globals, {'_run': run,
                            'install_m32_kernel_headers': lambda: kernel_include}):
                    runner['run_with_root_owned_test_tree'](
                        ['env', 'CC=gcc -m32', 'CXX=g++ -m32', '../configure'],
                        Path(directory) / 'm32-configure.log', cwd=work)
                    self.assertIn(
                        'CC=/srv/lfs/tools/bin/x86_64-lfs-linux-gnu-gcc -m32 '
                        '-I/srv/lfs/build/.m32-kernel-uapi/include',
                        run.call_args.args[0])
                    self.assertIn(
                        'CXX=/srv/lfs/tools/bin/x86_64-lfs-linux-gnu-g++ -m32 -static-libgcc '
                        '-I/srv/lfs/build/.m32-kernel-uapi/include',
                        run.call_args.args[0])
                with patch.object(package_stage, 'run') as run, patch.dict(
                        runner_globals, {'_run': run,
                            'install_m32_kernel_headers': lambda: kernel_include}):
                    runner['run_with_root_owned_test_tree'](
                        cross_configure, Path(directory) / 'm32-cross-configure.log', cwd=work)
                    self.assertIn(
                        'CC=/srv/lfs/tools/bin/x86_64-lfs-linux-gnu-gcc -m32 '
                        '-I/srv/lfs/build/.m32-kernel-uapi/include',
                        run.call_args.args[0])
                    self.assertIn(
                        'CXX=/srv/lfs/tools/bin/x86_64-lfs-linux-gnu-g++ -m32 -static-libgcc '
                        '-I/srv/lfs/build/.m32-kernel-uapi/include',
                        run.call_args.args[0])
                (work / 'config.make').write_text(
                    'CC = /srv/lfs/tools/bin/x86_64-lfs-linux-gnu-gcc -m32 '
                    '-I/srv/lfs/build/.m32-kernel-uapi/include\n')
                with patch.dict(runner_globals, {'_run': Mock()}) as patched:
                    runner['run_with_root_owned_test_tree'](
                        [package_stage.RUNUSER, '-u', 'lfs', '--', 'env', 'make', '-j4'],
                        Path(directory) / 'm32-build.log', cwd=work)
                    self.assertEqual(patched['_run'].call_args.args[0][-1], 'CXX=')
                with patch.dict(runner_globals, {'_run': Mock()}) as patched:
                    runner['run_with_root_owned_test_tree'](
                        [package_stage.RUNUSER, '-u', 'lfs', '--', 'env', 'make', '-j1',
                         'DESTDIR=/srv/lfs/stage/base-glibc/.m32', 'install'],
                        Path(directory) / 'm32-install.log', cwd=work)
                    self.assertEqual(patched['_run'].call_args.args[0][-1], 'CXX=')
                (work / 'config.make').write_text('CC = gcc\n')
                with patch.dict(runner_globals, {'_run': Mock()}) as patched:
                    runner['run_with_root_owned_test_tree'](
                        [package_stage.RUNUSER, '-u', 'lfs', '--', 'env', 'make', '-j4'],
                        Path(directory) / 'm64-build.log', cwd=work)
                    self.assertEqual(patched['_run'].call_args.args[0][-1], '-j4')
                with patch.dict(runner_globals, {'_run': Mock()}) as patched:
                    command = [package_stage.RUNUSER, '-u', 'lfs', '--', 'env', 'make', '-j1',
                               'DESTDIR=/srv/lfs/stage/base-glibc/.m32', 'install']
                    runner['run_with_root_owned_test_tree'](
                        command, Path(directory) / 'm64-install.log', cwd=work)
                    self.assertEqual(patched['_run'].call_args.args[0], command)
            finally:
                package_stage.recipe_working_directory = original
                package_stage.run = original_run

    def rpc_handoff_fixture(self, directory):
        import package_stage
        original_recipe_working_directory = package_stage.recipe_working_directory
        run_id = 'a' * 32
        root = Path(directory) / 'root'
        target = root / 'etc/rpc'
        target.parent.mkdir(parents=True)
        payload = b'100000\tportmapper\n'
        target.write_bytes(payload)
        target.chmod(0o644)
        db = root / 'var/lib/alp/db.json'
        db.parent.mkdir(parents=True)
        prior = {'schema_version': 1, 'packages': {
            'glibc-cross-m64': {'status': 'installed', 'files': ['/etc/rpc'], 'symlinks': []},
            'linux-headers': {'status': 'installed', 'files': ['/usr/include/linux/x.h'],
                              'symlinks': []}}}
        raw_db = (json.dumps(prior, sort_keys=True, indent=2) + '\n').encode()
        db.write_bytes(raw_db)
        result = Path(directory) / 'results' / run_id / 'glibc'
        result.mkdir(parents=True)
        entry = {'path': '/etc/rpc', 'type': 'file', 'mode': 0o644,
                 'uid': os.getuid(), 'gid': os.getgid(), 'size': len(payload),
                 'sha256': hashlib.sha256(payload).hexdigest()}
        fake_guest = types.SimpleNamespace(main=lambda: None, install_staged=lambda *args, **kwargs: None)
        with (patch.dict(sys.modules, {'guest_base': fake_guest}),
              patch.object(sys, 'argv', [str(base_stage.GUEST_RUNNER),
                                         base_stage.sha(base_stage.GUEST_RUNNER)])):
            runner = runpy.run_path(str(base_stage.GUEST_RUNNER), run_name='__main__')
        package_stage.recipe_working_directory = original_recipe_working_directory
        installer = Mock()

        def install(recipe, built, install_root, install_result):
            installed = install_root / 'etc/rpc'
            installed.write_bytes(payload)
            installed.chmod(0o644)
            database = json.loads((install_root / 'var/lib/alp/db.json').read_bytes())
            database['packages']['glibc'] = {'status': 'installed', 'files': ['/etc/rpc'],
                                             'symlinks': []}
            (install_root / 'var/lib/alp/db.json').write_text(
                json.dumps(database, sort_keys=True, indent=2) + '\n')
            return {'result': 'INSTALLED'}

        installer.side_effect = install
        built = {'manifest_sha256': 'b' * 64, 'manifest': 'unused'}
        recipe = {'name': 'glibc', 'phase': 'base'}
        package_install = types.SimpleNamespace(validate_bundle=lambda *_: {'entries': [entry]})
        return runner, package_stage, root, target, db, raw_db, result, payload, built, recipe, package_install, installer

    def test_glibc_rpc_bootstrap_owner_handoff_is_exact_and_receipted(self):
        with tempfile.TemporaryDirectory() as directory:
            (runner, _, root, target, db, raw_db, result, payload, built, recipe,
             package_install, installer) = self.rpc_handoff_fixture(directory)
            outcome = runner['handoff_glibc_rpc_bootstrap_owner'](
                recipe, built, root, result, installer, package_install)
            self.assertEqual(outcome, {'result': 'INSTALLED'})
            self.assertEqual(target.read_bytes(), payload)
            database = json.loads(db.read_bytes())
            self.assertNotIn('/etc/rpc', database['packages']['glibc-cross-m64']['files'])
            self.assertIn('/etc/rpc', database['packages']['glibc']['files'])
            self.assertEqual((result / 'glibc-rpc-ownership-transfer.json').exists(), True)
            self.assertEqual(list(target.parent.glob('.rpc.infra-transfer-*.bak')), [])
            self.assertNotEqual(db.read_bytes(), raw_db)

    def test_glibc_rpc_handoff_rolls_back_db_and_file_when_alp_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            (runner, _, root, target, db, raw_db, result, payload, built, recipe,
             package_install, installer) = self.rpc_handoff_fixture(directory)
            installer.side_effect = RuntimeError('simulated Alp failure')
            with self.assertRaisesRegex(RuntimeError, 'simulated Alp failure'):
                runner['handoff_glibc_rpc_bootstrap_owner'](
                    recipe, built, root, result, installer, package_install)
            self.assertEqual(target.read_bytes(), payload)
            self.assertEqual(db.read_bytes(), raw_db)
            self.assertEqual(list(target.parent.glob('.rpc.infra-transfer-*.bak')), [])
            self.assertFalse((result / 'glibc-rpc-ownership-transfer.json').exists())

    def test_glibc_rpc_handoff_rejects_changed_bootstrap_bytes_before_mutation(self):
        with tempfile.TemporaryDirectory() as directory:
            (runner, _, root, target, db, raw_db, result, _, built, recipe,
             package_install, installer) = self.rpc_handoff_fixture(directory)
            target.write_bytes(b'different bootstrap content\n')
            with self.assertRaisesRegex(RuntimeError, 'does not exactly match'):
                runner['handoff_glibc_rpc_bootstrap_owner'](
                    recipe, built, root, result, installer, package_install)
            installer.assert_not_called()
            self.assertEqual(db.read_bytes(), raw_db)


if __name__ == '__main__':
    unittest.main()
