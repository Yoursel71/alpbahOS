import importlib.util
import json
import shlex
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[1]
PRODUCT = REPO / 'scripts/product-stages'
SPEC = importlib.util.spec_from_file_location(
    'infra_product_kernel_stage_test', PRODUCT / 'infra-product-stage.py')
kernel_stage = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(kernel_stage)
GUEST_SPEC = importlib.util.spec_from_file_location(
    'kernel_guest_cleanup_test', PRODUCT / 'kernel-guest-run.py')
kernel_guest = importlib.util.module_from_spec(GUEST_SPEC)
GUEST_SPEC.loader.exec_module(kernel_guest)


class KernelProductStageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipe = json.loads((PRODUCT / 'kernel.recipe.json').read_bytes())
        cls.verifier = PRODUCT / 'verify-kernel-config.py'
        cls.required = REPO / 'configs/kernel/infra-required.config'

    def test_kernel_recipe_matches_pinned_sources_and_installed_base_plan(self):
        import base_plan
        import package_stage

        package_stage.validate_recipe(self.recipe, self.recipe['jobs'])
        substitutions = {'stage': '/srv/lfs/stage/test', 'source': '/srv/lfs/build/test',
                         'lfs': '/srv/lfs', 'jobs': 4, 'build_triplet': 'x86_64-linux-gnu'}
        for step in ('pre', 'compile', 'test', 'stage', 'post_stage'):
            for command in self.recipe.get(step, []):
                for argument in command:
                    argument.format(**substitutions)
        plan = base_plan.load(REPO)
        self.assertEqual(len(plan), 79)
        self.assertFalse(set(self.recipe['requires']) - {row['name'] for row in plan})
        manifest = json.loads((REPO / 'manifests/infra-sources.json').read_bytes())
        sources = [row for row in manifest['sources'] if row['filename'] == self.recipe['source']]
        self.assertEqual(len(sources), 1)
        self.assertEqual(sources[0]['sha256'],
                         'ea43491bc7ace1e414b3b2d957f8cf96e7049155123f0acce798accf8da1acba')
        self.assertEqual(self.recipe['version'], '6.16.1-alpbahOS')

    def test_kernel_config_gate_accepts_required_config_and_rejects_missing_abi_or_modules(self):
        with tempfile.TemporaryDirectory() as temp:
            config = Path(temp) / '.config'
            config.write_bytes(self.required.read_bytes() +
                               b'CONFIG_MODULES=y\nCONFIG_LOCALVERSION="-alpbahOS"\n'
                               b'# CONFIG_LOCALVERSION_AUTO is not set\n')
            valid = subprocess.run(['python3', str(self.verifier), '--config', str(config),
                                    '--required', str(self.required)], capture_output=True, text=True)
            self.assertEqual(valid.returncode, 0, valid.stderr + valid.stdout)

            config.write_text(config.read_text().replace(
                'CONFIG_IA32_EMULATION=y', '# CONFIG_IA32_EMULATION is not set'))
            invalid_abi = subprocess.run(['python3', str(self.verifier), '--config', str(config),
                '--required', str(self.required)], capture_output=True, text=True)
            self.assertNotEqual(invalid_abi.returncode, 0)
            self.assertIn('CONFIG_MISMATCH CONFIG_IA32_EMULATION', invalid_abi.stdout)

            config.write_bytes(self.required.read_bytes() +
                               b'# CONFIG_MODULES is not set\nCONFIG_LOCALVERSION="-alpbahOS"\n'
                               b'# CONFIG_LOCALVERSION_AUTO is not set\n')
            invalid_modules = subprocess.run(['python3', str(self.verifier), '--config', str(config),
                '--required', str(self.required)], capture_output=True, text=True)
            self.assertNotEqual(invalid_modules.returncode, 0)
            self.assertIn('CONFIG_MISMATCH CONFIG_MODULES', invalid_modules.stderr)

    def test_guest_kernel_service_is_guarded_detached_and_waits_for_summary(self):
        command = shlex.split(kernel_stage.kernel_service_command('a' * 32, 'b' * 64))
        self.assertEqual(command[:2], ['bash', '-c'])
        script = command[2]
        syntax = subprocess.run(['bash', '-n', '-c', script], capture_output=True, text=True)
        self.assertEqual(syntax.returncode, 0, syntax.stderr)
        self.assertIn('source /opt/alp-infra/scripts/infra/guest-guard.sh', script)
        self.assertIn('guest_guard', script)
        self.assertIn('systemd-run --unit="$unit" --no-block', script)
        self.assertIn('/opt/alp-infra/scripts/product-stages/kernel-guest-run.py', script)
        self.assertIn('mkdir -m 0755 /srv/lfs/results/kernel', script)
        self.assertLess(script.index('flock -u 9'), script.index('systemd-run --unit="$unit"'))
        self.assertLess(script.index('exec 9<&-'), script.index('systemd-run --unit="$unit"'))
        self.assertIn('"$result_state" == success', script)
        self.assertIn('-f "$summary" && ! -L "$summary"', script)

    def test_product_runner_loads_original_base_verifier_without_changing_frozen_inputs(self):
        base = kernel_stage.load_base_controller()
        self.assertEqual(Path(base.REPO), Path('/home/yrslf/alpbahOS-infra-rebuild'))
        self.assertEqual(kernel_stage.buildctl.inputs_digest(), base.buildctl.inputs_digest())

    def test_lfs_overlay_growth_is_limited_to_fresh_accepted_base_child(self):
        with tempfile.TemporaryDirectory() as temp:
            vm = Path(temp)
            checkpoint = vm / 'checkpoint-base'
            checkpoint.mkdir()
            (checkpoint / 'lfs.qcow2').write_bytes(b'accepted-base')
            active = vm / 'lfs-active.qcow2'
            active.write_bytes(b'fresh-child')
            responses = [
                {'format': 'qcow2', 'virtual-size': 40 * 1024**3},
                None,
                {'format': 'qcow2', 'virtual-size': 96 * 1024**3},
            ]

            def run(argv, **kwargs):
                if argv[1:3] == ['info', '--output=json']:
                    value = responses.pop(0)
                    if value is None:
                        return subprocess.CompletedProcess(argv, 0, json.dumps([
                            {'filename': str(active), 'format': 'qcow2'},
                            {'filename': str(checkpoint / 'lfs.qcow2'), 'format': 'qcow2'}]), '')
                    return subprocess.CompletedProcess(argv, 0, json.dumps(value), '')
                self.assertEqual(argv, ['qemu-img', 'resize', active, str(96 * 1024**3)])
                return subprocess.CompletedProcess(argv, 0, '', '')

            with (patch.object(kernel_stage.buildctl, 'VM', vm),
                  patch.object(kernel_stage.buildctl, 'space_guard'),
                  patch.object(kernel_stage, 'assert_stopped'),
                  patch.object(kernel_stage.subprocess, 'run', side_effect=run)):
                proof = kernel_stage.grow_lfs_disk()
            self.assertEqual(proof['bytes'], 96 * 1024**3)
            self.assertEqual(proof['backing_checkpoint'], str(checkpoint / 'lfs.qcow2'))
            self.assertEqual(responses, [])

    def test_lfs_guest_filesystem_capacity_must_be_verified_after_growth(self):
        with patch.object(kernel_stage, 'guest_read', side_effect=[b'resized',
                b'Filesystem 1B-blocks Available\n/dev/vdb 103079215104 85899345920\n']) as read:
            proof = kernel_stage.grow_lfs_filesystem()
        self.assertEqual(proof['result'], 'PASS')
        self.assertGreaterEqual(proof['available_bytes'], 70 * 1024**3)
        self.assertEqual(read.call_count, 2)
        with patch.object(kernel_stage, 'guest_read', side_effect=[b'resized',
                b'Filesystem 1B-blocks Available\n/dev/vdb 42949672960 26843545600\n']):
            with self.assertRaisesRegex(RuntimeError, 'did not grow enough'):
                kernel_stage.grow_lfs_filesystem()

    def test_guest_cleanup_removes_only_a_direct_per_run_build_or_stage_directory(self):
        with tempfile.TemporaryDirectory() as temp:
            lfs = Path(temp)
            build = lfs / 'build'
            stage = lfs / 'stage'
            build.mkdir(); stage.mkdir()
            run_id = 'a' * 32
            target = build / run_id
            target.mkdir()
            (target / 'temporary.o').write_bytes(b'object')
            sibling = build / ('b' * 32)
            sibling.mkdir()
            with patch.object(kernel_guest, 'LFS', lfs), patch.object(kernel_guest.os, 'geteuid', return_value=0):
                kernel_guest.remove_transient(target, build)
                self.assertFalse(target.exists())
                self.assertTrue(sibling.is_dir())
                with self.assertRaisesRegex(RuntimeError, 'direct private LFS run directory'):
                    kernel_guest.remove_transient(sibling, lfs)
                with self.assertRaisesRegex(RuntimeError, 'direct private LFS run directory'):
                    kernel_guest.remove_transient(lfs / 'outside', lfs / 'outside')


if __name__ == '__main__':
    unittest.main()
