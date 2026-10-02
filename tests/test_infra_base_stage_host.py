import importlib.util
import json
from pathlib import Path
import runpy
import sys
import tempfile
import types
import unittest
from unittest.mock import patch


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
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'glibc-source'; source.mkdir()
            work = source / 'build'; work.mkdir()
            fake_guest = types.SimpleNamespace(main=lambda: None)
            with (patch.dict(sys.modules, {'guest_base': fake_guest}),
                  patch.object(sys, 'argv', [str(base_stage.GUEST_RUNNER),
                                             base_stage.sha(base_stage.GUEST_RUNNER)])):
                runpy.run_path(str(base_stage.GUEST_RUNNER), run_name='__main__')
            try:
                resolved = package_stage.recipe_working_directory(
                    work, {'separate_build': True, 'working_directories': {'compile': 'build'}},
                    'compile')
                self.assertEqual(resolved, work)
            finally:
                package_stage.recipe_working_directory = original


if __name__ == '__main__':
    unittest.main()
