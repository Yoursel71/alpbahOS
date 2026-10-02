"""Critical host/VM boundary and input-invalidation checks; no host root."""
import importlib.util
import json
import os
import subprocess
import sys
import io
import hashlib
import shutil
import tarfile
import stat
import struct
import tempfile
import time
import unittest
from contextlib import contextmanager, ExitStack
from pathlib import Path
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / 'scripts/infra'))
import host_monitor
import package_stage
import package_install
import stability_evidence
import filesystem_layout
import guest_toolchain
import toolchain_sanity
import guest_process
import guest_tests
import checkpoint_store
import host_stage_audit
import stage_runs
import stage_acceptance
import toolchain_handoff
import handoff_binding
import guest_handoff
import toolchain_artifacts
guest_stability_spec = importlib.util.spec_from_file_location('guest_stability', REPO / 'scripts/infra/guest-stability.py')
guest_stability = importlib.util.module_from_spec(guest_stability_spec)
guest_stability_spec.loader.exec_module(guest_stability)
spec = importlib.util.spec_from_file_location('buildctl', REPO / 'scripts/infra/buildctl.py')
ctl = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ctl)
policy_spec = importlib.util.spec_from_file_location('test_policy', REPO / 'scripts/infra/test-policy.py')
test_policy = importlib.util.module_from_spec(policy_spec)
policy_spec.loader.exec_module(test_policy)
POLICIES = json.loads((REPO / 'manifests/infra-test-policy.json').read_text())
host_spec = importlib.util.spec_from_file_location('host_integrity', REPO / 'scripts/infra/host-integrity.py')
host_integrity = importlib.util.module_from_spec(host_spec)
host_spec.loader.exec_module(host_integrity)


def handoff_fixture(infra, inputs):
    """Synthetic transport only, never a root/stability acceptance certificate."""
    receipt = {'schema': handoff_binding.SCHEMA, 'result': 'VERIFIED_PARENT', 'stage': 'toolchain',
               'mode': 'multilib-m32', 'run_id': 'a' * 32, 'parent_run_id': 'b' * 32,
               'host_boot_id': '11111111-1111-4111-8111-111111111111',
               'guest_boot_id': package_stage.BOOT.read_text().strip(), **inputs,
               **{k: 'c' * 64 for k in ('parent_receipt_sha256', 'parent_proof_sha256',
                                       'checkpoint_sha256', 'transaction_sha256')},
               'active_overlay_sha256': {'builder': 'd' * 64, 'lfs': 'e' * 64}}
    raw = (json.dumps(receipt, sort_keys=True) + '\n').encode()
    auth = {**inputs, 'oc_confirmed': True, 'mode': receipt['mode'], 'stage': 'toolchain',
            'run_id': receipt['run_id'], 'boot_id': receipt['host_boot_id'],
            'guest_boot_id': receipt['guest_boot_id'], 'handoff_sha256': hashlib.sha256(raw).hexdigest()}
    (infra / 'stability-acceptance.json').write_bytes(raw)
    (infra / 'phase2-authorization.json').write_text(json.dumps(auth))
    return receipt, auth


@contextmanager
def stage_job_fixture(directory, started=True, audited=True, sources_sha256='2' * 64):
    """Real private requests/state/files; privileged audit transport simulated."""
    root = Path(directory)
    with ExitStack() as stack:
        for module, name, value in ((stage_runs, 'RUNS', root / 'jobs'),
                                    (stage_runs, 'ARTIFACTS', root / 'artifacts'),
                                    (host_stage_audit, 'REQUESTS', root / 'requests')):
            stack.enter_context(patch.object(module, name, value))
        if audited:
            stack.enter_context(patch.object(host_stage_audit, 'verify', return_value={'pristine_rpm': True, 'fixture_only': True}))
        result = stage_runs.prepare('stability', 'multilib-m32', '1' * 64, sources_sha256, '3' * 64)
        value, run_sha256, request_raw = stage_runs.load(result['run_id'], 'multilib-m32', '1' * 64, sources_sha256, '3' * 64)
        if started:
            stage_runs.begin(value, run_sha256, request_raw)
        yield value, run_sha256, request_raw


class BoundaryTests(unittest.TestCase):
    def test_input_digest_tracks_kernel_config_and_local_patches(self):
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            (repo / 'scripts').mkdir()
            (repo / 'scripts/capture-package-manifest.py').write_text('a')
            (repo / 'scripts/compare-package-manifest.py').write_text('b')
            for path in ('scripts/infra', 'manifests', 'recipes/toolchain', 'configs/kernel', 'packaging', 'live'):
                (repo / path).mkdir(parents=True, exist_ok=True)
            config = repo / 'configs/kernel/infra-required.config'
            config.write_text('CONFIG_IA32_EMULATION=y\n')
            patch_file = repo / 'recipes/toolchain/local-fix.patch'
            patch_file.write_text('patch-a')
            with patch.object(ctl, 'REPO', repo):
                first = ctl.inputs_digest()
                config.write_text('CONFIG_IA32_EMULATION=n\n')
                second = ctl.inputs_digest()
                self.assertNotEqual(first, second)
                patch_file.write_text('patch-b')
                self.assertNotEqual(second, ctl.inputs_digest())

    def test_host_root_rejected_before_writes(self):
        with patch.object(ctl.os, 'geteuid', return_value=0):
            with self.assertRaisesRegex(RuntimeError, 'root execution forbidden'):
                ctl.initialize_dirs()

    def test_unlisted_host_path_rejected(self):
        with self.assertRaisesRegex(RuntimeError, 'not allowlisted'):
            ctl.safe_parent(Path('/usr/lib/systemd/user'), Path('/mnt/alpbahOS-data'))

    def test_symlinked_target_rejected(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            link = Path(directory) / 'escape'
            link.symlink_to('/usr')
            with self.assertRaisesRegex(RuntimeError, 'Symlink path forbidden'):
                ctl.safe_parent(link, ctl.DATA_MOUNT)

    def test_source_mismatch_preserved_and_rejected(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            source = Path(directory) / 'original'
            source.write_bytes(b'reviewed source')
            dest = Path(directory) / 'cached'
            with self.assertRaisesRegex(RuntimeError, 'checksum mismatch'):
                ctl.fetch('https://example.invalid/source', dest, '0' * 64, local=source)
            self.assertFalse(dest.exists())
            self.assertEqual(source.read_bytes(), b'reviewed source')
            self.assertTrue(dest.with_suffix('.partial').exists())

    def test_disk_space_15_percent_gate(self):
        with patch.object(ctl.shutil, 'disk_usage', return_value=type('Usage', (), {'free': 14, 'total': 100})()):
            with self.assertRaisesRegex(RuntimeError, 'below 15%'):
                ctl.space_guard()

    def test_phase2_needs_both_authorizations(self):
        for mode, oc in ((None, False), ('x86_64', False), (None, True)):
            with self.assertRaisesRegex(RuntimeError, 'OC-complete/start authorization'):
                ctl.phase2(mode, oc)

    def test_phase2_cannot_run_without_db_acceptance(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, patch.object(ctl, 'ARTIFACTS', Path(directory)), \
                patch.object(ctl, 'launch') as launch:
            with self.assertRaisesRegex(RuntimeError, 'resolve Alp DB reproducibility'):
                ctl.phase2('multilib-m32', True)
            launch.assert_not_called()

    def test_phase1_rejects_db_difference_and_changed_inputs(self):
        expected = {'inputs_sha256': '1' * 64, 'alp_sha256': '2' * 64, 'source_date_epoch': 1756684800}
        summary = {**expected, 'result': 'PASS', 'db_repeatable': True, 'install_remove_restore': 'PASS',
                   'alp_reproducible_build_mode': True,
                   'archive_sha256': ['a' * 64] * 2, 'manifest_sha256': ['b' * 64] * 2, 'db_sha256': ['c' * 64] * 2}
        evidence = {**expected, 'equal': True, 'alp_reproducible_build_mode': True,
                    'records': [{'db_sha256': 'c' * 64}] * 2}
        with patch.object(ctl, 'manifest', return_value={'source_date_epoch': 1756684800, 'alp': {'sha256': '2' * 64}}), \
                patch.object(ctl, 'inputs_digest', return_value='1' * 64):
            ctl.verify_smoke_report(summary, evidence)
            bad = {**summary, 'db_sha256': ['c' * 64, 'd' * 64]}
            with self.assertRaisesRegex(RuntimeError, 'unequal/invalid hashes'):
                ctl.verify_smoke_report(bad, evidence)
            with self.assertRaisesRegex(RuntimeError, 'different inputs'):
                ctl.verify_smoke_report({**summary, 'inputs_sha256': 'f' * 64}, evidence)
            with self.assertRaisesRegex(RuntimeError, 'explicit reproducible-build mode'):
                ctl.verify_smoke_report({**summary, 'alp_reproducible_build_mode': False}, evidence)

    def test_user_owned_empty_file_is_not_a_privileged_audit(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, patch.object(host_integrity, 'DATA', Path(directory)):
            logs = Path(directory) / 'logs'; logs.mkdir()
            (logs / 'root-host-audit-after.json').write_text('{}')
            with self.assertRaisesRegex(RuntimeError, 'Verified root audit metadata missing'):
                host_integrity.validate_privileged_audit()

    def test_root_audit_rejects_missing_usr_changes_and_permission_gaps(self):
        self.assertTrue(host_integrity.classify_privileged('', 0, 0)['pristine_rpm'])
        for text in ('missing /usr/lib/systemd/user/plasma-kwin_wayland.service',
                     '..5...... /usr/bin/tool', 'missing /private (Permission denied)'):
            self.assertFalse(host_integrity.classify_privileged(text, 1, 0)['accepted'])
        self.assertFalse(host_integrity.classify_privileged('', 0, 1)['accepted'])

    def test_guest_entrypoint_refuses_host(self):
        p = subprocess.run(['bash', REPO / 'scripts/infra/guest-package.sh', 'zlib-smoke'],
                           capture_output=True, text=True)
        self.assertNotEqual(p.returncode, 0)
        # On a host it fails before formatting/mounting/building any path.
        self.assertIn('No such file', p.stderr)  # /opt/alp-infra exists only in guest

    def test_capture_epoch_is_byte_repeatable(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory)
            stage = root / 'stage'; stage.mkdir()
            (stage / 'file').write_bytes(b'payload')
            outputs = []
            for i in (1, 2):
                dest = root / f'{i}.json'
                subprocess.run(['python3', REPO / 'scripts/capture-package-manifest.py',
                    '--stage', stage, '--name', 'fixture', '--version', '1',
                    '--source-url', 'https://example.invalid/fixture',
                    '--source-sha256', '0' * 64, '--output', dest],
                    env={**os.environ, 'SOURCE_DATE_EPOCH': '1756684800'},
                    capture_output=True, check=True)
                outputs.append(dest.read_bytes())
            self.assertEqual(outputs[0], outputs[1])
            self.assertEqual(json.loads(outputs[0])['captured_at'], '2025-09-01T00:00:00+00:00')


class PackageInstallationTests(unittest.TestCase):
    def fixture(self, root):
        stage = root / 'stage'; (stage / 'usr/bin').mkdir(parents=True)
        (stage / 'usr/bin/tool').write_bytes(b'fixture executable payload')
        (stage / 'usr/bin/tool').chmod(0o755)
        (stage / 'usr/bin/alias').symlink_to('tool')
        source = {'filename': 'fixture.tar', 'url': 'https://example.invalid/fixture', 'sha256': '0' * 64}
        recipe = {'name': 'fixture', 'version': '1', 'source': 'fixture.tar', 'phase': 'smoke'}
        capture = root / 'manifest.json'
        subprocess.run(['python3', REPO / 'scripts/capture-package-manifest.py', '--stage', stage,
            '--name', 'fixture', '--version', '1', '--source-url', source['url'],
            '--source-sha256', source['sha256'], '--output', capture],
            env={**os.environ, 'SOURCE_DATE_EPOCH': '1756684800'}, check=True, capture_output=True)
        archive = root / 'payload.tar.gz'
        with tarfile.open(archive, 'w:gz') as stream:
            stream.add(stage, arcname='.', recursive=True)
        built = {'source': source, 'archive': archive, 'manifest': capture,
                 'archive_sha256': package_install.sha(archive), 'manifest_sha256': package_install.sha(capture)}
        return recipe, built, stage

    def test_bundle_bytes_or_unmanifested_entry_cannot_reach_installer(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory); recipe, built, stage = self.fixture(root)
            package_install.validate_bundle(recipe, built)
            (stage / 'extra').write_bytes(b'not captured')
            with tarfile.open(built['archive'], 'w:gz') as stream: stream.add(stage, arcname='.')
            with self.assertRaisesRegex(RuntimeError, 'bundle bytes changed'):
                package_install.validate_bundle(recipe, built)
            built['archive_sha256'] = package_install.sha(built['archive'])
            with self.assertRaisesRegex(RuntimeError, 'unmanifested'):
                package_install.validate_bundle(recipe, built)

    def test_archive_traversal_and_duplicate_manifest_rejected(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory); recipe, built, stage = self.fixture(root)
            with tarfile.open(built['archive'], 'w:gz') as stream:
                entry = tarfile.TarInfo('../escape'); entry.size = 1
                stream.addfile(entry, io.BytesIO(b'x'))
            built['archive_sha256'] = package_install.sha(built['archive'])
            with self.assertRaisesRegex(RuntimeError, 'Unsafe archive path'):
                package_install.validate_bundle(recipe, built)
            value = json.loads(built['manifest'].read_text())
            value['entries'].append(value['entries'][0])
            built['manifest'].write_text(json.dumps(value)); built['manifest_sha256'] = package_install.sha(built['manifest'])
            with self.assertRaisesRegex(RuntimeError, 'Duplicate'):
                package_install.validate_bundle(recipe, built)

    def test_symlink_alias_double_ownership_is_rejected(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory); (root / 'usr/lib').mkdir(parents=True)
            (root / 'lib').symlink_to('usr/lib'); (root / 'usr/lib/tool').write_bytes(b'payload')
            value = {'entries': [{'path': '/usr/lib/tool', 'type': 'file'}]}
            installed = {'foreign': {'files': ['/lib/tool']}}
            with self.assertRaisesRegex(RuntimeError, 'ownership missing/conflicting'):
                package_install.ownership_check(root, value, installed, 'fixture', before=True)

    def test_unprivileged_host_install_stops_before_bundle_or_engine(self):
        with patch.object(package_install.os, 'geteuid', return_value=1000), \
                patch.object(package_install, 'run') as run:
            with self.assertRaisesRegex(RuntimeError, 'host invocation refused'):
                package_install.install_staged({}, {}, Path('/srv/lfs'), Path('/srv/lfs/results/fixture'))
            run.assert_not_called()

    def test_install_and_resume_check_actual_fixture_payload(self):
        # Only the Alp CLI is simulated. Real archive, capture and installed
        # payload comparison run unprivileged on isolated fixture directories.
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory); recipe, built, stage = self.fixture(root)
            repo, infra, lfs = root / 'repo', root / 'infra', root / 'lfs'
            for path in [repo / 'scripts', repo / 'runtime', repo / 'manifests', infra, lfs]: path.mkdir(parents=True)
            (repo / 'scripts/compare-package-manifest.py').symlink_to(REPO / 'scripts/compare-package-manifest.py')
            alp = repo / 'runtime/alp.py'; alp.write_bytes(b'fixture engine, never executed')
            sources = {'alp': {'sha256': package_install.sha(alp)}, 'sources': [built['source']], 'source_date_epoch': 1756684800}
            source_manifest = repo / 'manifests/infra-sources.json'; source_manifest.write_text(json.dumps(sources))
            inputs = {'inputs_sha256': '1' * 64, 'sources_sha256': package_install.sha(source_manifest)}
            (infra / 'inputs.json').write_text(json.dumps(inputs))
            target = lfs / 'smoke-root'; target.mkdir()
            result = lfs / 'results/fixture'; result.mkdir(parents=True)
            invocations = []

            def execute(argv, log, env=None):
                if argv[0] == package_install.PYTHON:
                    invocations.append(argv)
                    if 'install' in argv:
                        index = json.loads(Path(argv[argv.index('--index') + 1]).read_text())
                        entry = index['entries']['fixture']
                        shutil.copytree(stage, target, symlinks=True, dirs_exist_ok=True)
                        db_path = target / 'var/lib/alp/db.json'; db_path.parent.mkdir(parents=True, exist_ok=True)
                        db = {'schema_version': 1, 'packages': {'fixture': {'name': 'fixture', 'version': '1',
                            'status': 'installed', 'method': 'core', 'source': {'url': entry['url'], 'sha256': entry['sha256']},
                            'files': ['/usr/bin/tool', '/usr/bin/alias'], 'symlinks': ['/usr/bin/alias']}}}
                        db_path.write_text(json.dumps(db))
                        self.assertEqual(env['SOURCE_DATE_EPOCH'], '1756684800')
                        self.assertEqual(env['ALP_REPRODUCIBLE_BUILD'], '1')
                else:
                    subprocess.run(argv, env=env, check=True, capture_output=True)

            with patch.object(package_install, 'REPO', repo), patch.object(package_install, 'INFRA', infra), \
                    patch.object(package_install, 'LFS', lfs), patch.object(package_install, 'guest_install_guard'), \
                    patch.object(package_install, 'run', side_effect=execute):
                receipt = package_install.install_staged(recipe, built, target, result)
                self.assertEqual(receipt['result'], 'PASS')
                package_install.verify_installed(recipe, built, target, result)
                self.assertEqual(len(invocations), 2)  # install/check; resume never reinstalls
                index = json.loads((result / 'fixture.index.json').read_text())
                self.assertEqual(index['entries']['fixture']['url'], (lfs / 'packages' / ('fixture-1-' + built['archive_sha256'] + '.tar.gz')).as_uri())
                (target / 'usr/bin/tool').write_bytes(b'corrupted after receipt')
                with self.assertRaises(subprocess.CalledProcessError):
                    package_install.verify_installed(recipe, built, target, result)


class ToolchainSequenceTests(unittest.TestCase):
    def test_pinned_plan_has_ordered_ownership_and_staged_limits(self):
        with patch.object(guest_toolchain, 'REPO', REPO):
            plan = guest_toolchain.load_plan()
        self.assertEqual(tuple(r['name'] for r in plan), guest_toolchain.ORDER)
        gcc = next(r for r in plan if r['name'] == 'gcc-pass1')
        self.assertEqual(gcc['post_stage_concat'][0]['sources'], ['gcc/limitx.h', 'gcc/glimits.h', 'gcc/limity.h'])
        for recipe in plan:
            for field in ('pre', 'compile', 'test', 'stage', 'post_stage'):
                self.assertFalse(any('mkheaders' in token for argv in recipe.get(field, []) for token in argv))

    def test_host_cannot_start_sequence_or_abi_probe(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, \
                patch.object(package_install.os, 'geteuid', return_value=1000), \
                patch.object(guest_toolchain, 'build_staged') as build:
            root = Path(directory)
            with self.assertRaisesRegex(RuntimeError, 'host invocation refused'):
                guest_toolchain.run_sequence([], root, root / 'result')
            build.assert_not_called(); self.assertFalse((root / 'result').exists())
            with patch.object(toolchain_sanity, 'LFS', root), patch.object(toolchain_sanity.subprocess, 'run') as run:
                with self.assertRaisesRegex(RuntimeError, 'host invocation refused'):
                    toolchain_sanity.probe('glibc-cross-m64', root, root / 'result')
                run.assert_not_called()

    def simulated(self, directory):
        # Test orchestration; builder/install/guest guards and probes simulated.
        root = Path(directory); lfs = root / 'lfs'; lfs.mkdir()
        result = lfs / 'results/toolchain'; result.parent.mkdir()
        infra = root / 'infra'; infra.mkdir()
        inputs = {'inputs_sha256': '1' * 64, 'sources_sha256': package_stage.sha(REPO / 'manifests/infra-sources.json')}
        (infra / 'inputs.json').write_text(json.dumps(inputs))
        handoff_fixture(infra, inputs)
        with patch.object(guest_toolchain, 'REPO', REPO): plan = guest_toolchain.load_plan()
        installed, calls = {}, []

        def build(recipe, run_id, target):
            calls.append('build:' + recipe['name'])
            scratch = target / 'fixture'; scratch.mkdir()
            _, built, stage = PackageInstallationTests().fixture(scratch)
            manifest = json.loads(built['manifest'].read_text())
            item = package_stage.source_pin(ctl.manifest(), recipe['source'], REPO)
            manifest['package'] = {'name': recipe['name'], 'version': recipe['version'],
                                   'source': {'url': item['url'], 'sha256': item['sha256']}}
            built['manifest'].write_text(json.dumps(manifest))
            archive, captured = target / (run_id + '.tar.gz'), target / (run_id + '.json')
            built['archive'].rename(archive); built['manifest'].rename(captured)
            return {**built, 'source': item, 'archive': archive, 'manifest': captured,
                    'manifest_sha256': package_stage.sha(captured)}

        def install(recipe, built, target, evidence):
            calls.append('install:' + recipe['name'])
            installed[recipe['name']] = {'status': 'installed'}
            (evidence / (recipe['name'] + '.installed.json')).write_text('{}')

        def verify(recipe, built, target, evidence): calls.append('verify:' + recipe['name'])
        return lfs, result, infra, plan, installed, calls, build, install, verify

    def test_sequence_and_resume_revalidate_without_rebuild_or_reinstall(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            lfs, result, infra, plan, installed, calls, build, install, verify = self.simulated(directory)
            with patch.object(guest_toolchain, 'REPO', REPO), patch.object(guest_toolchain, 'LFS', lfs), \
                    patch.object(guest_toolchain, 'INFRA', infra), patch.object(guest_toolchain, 'guest_install_guard'), \
                    patch.object(guest_toolchain, 'heavy_recipe_guard'), patch.object(guest_toolchain, 'packages', return_value=installed), \
                    patch.object(guest_toolchain, 'build_staged', side_effect=build) as builder, \
                    patch.object(guest_toolchain, 'install_staged', side_effect=install) as installer, \
                    patch.object(guest_toolchain, 'verify_installed', side_effect=verify), \
                    patch.object(guest_toolchain, 'probe', return_value={'simulated': True}) as probe:
                guest_toolchain.run_sequence(plan, lfs, result)
                self.assertEqual([c for c in calls if c.startswith('build:')], ['build:' + n for n in guest_toolchain.ORDER])
                self.assertEqual([c.args[0] for c in probe.call_args_list], ['glibc-cross-m64', 'glibc-cross-m32', 'libstdcxx-cross'])
                receipt = guest_toolchain.run_sequence(plan, lfs, result)
                self.assertEqual(builder.call_count, 7); self.assertEqual(installer.call_count, 7)
                self.assertEqual(probe.call_count, 6)  # Fresh sanity on resume, no stamp acceptance.
                self.assertTrue(all('no rebuild/reinstall' in row['action'] for row in receipt['packages']))
                (result / 'gcc-pass1/toolchain-gcc-pass1.tar.gz').write_bytes(b'corrupted')
                with self.assertRaisesRegex(RuntimeError, 'bundle bytes changed'):
                    guest_toolchain.run_sequence(plan, lfs, result)
                self.assertEqual(builder.call_count, 7); self.assertEqual(installer.call_count, 7)

    def test_interrupted_alp_attempt_is_not_automatically_retried(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            lfs, result, infra, plan, installed, calls, build, install, verify = self.simulated(directory)
            with patch.object(guest_toolchain, 'REPO', REPO), patch.object(guest_toolchain, 'LFS', lfs), \
                    patch.object(guest_toolchain, 'INFRA', infra), patch.object(guest_toolchain, 'guest_install_guard'), \
                    patch.object(guest_toolchain, 'heavy_recipe_guard'), patch.object(guest_toolchain, 'packages', return_value=installed), \
                    patch.object(guest_toolchain, 'build_staged', side_effect=build) as builder, \
                    patch.object(guest_toolchain, 'install_staged', side_effect=RuntimeError('interrupted transaction')) as installer:
                with self.assertRaisesRegex(RuntimeError, 'interrupted transaction'):
                    guest_toolchain.run_sequence(plan, lfs, result)
                with self.assertRaisesRegex(RuntimeError, 'never automatic retry'):
                    guest_toolchain.run_sequence(plan, lfs, result)
                self.assertEqual(builder.call_count, 1); self.assertEqual(installer.call_count, 1)

    def test_changed_plan_binding_stops_before_new_build(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            lfs, result, infra, plan, installed, calls, build, install, verify = self.simulated(directory)
            result.mkdir(); (result / 'inputs.json').write_text('{}')
            with patch.object(guest_toolchain, 'REPO', REPO), patch.object(guest_toolchain, 'LFS', lfs), \
                    patch.object(guest_toolchain, 'INFRA', infra), patch.object(guest_toolchain, 'guest_install_guard'), \
                    patch.object(guest_toolchain, 'heavy_recipe_guard'), patch.object(guest_toolchain, 'packages', return_value=installed), \
                    patch.object(guest_toolchain, 'build_staged') as builder:
                with self.assertRaisesRegex(RuntimeError, 'sequence inputs changed'):
                    guest_toolchain.run_sequence(plan, lfs, result)
                builder.assert_not_called()

    def test_library_cannot_replace_toolchain_phase_with_smoke(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            lfs, result, infra, plan, installed, calls, build, install, verify = self.simulated(directory)
            plan[2]['phase'] = 'smoke'
            with patch.object(guest_toolchain, 'REPO', REPO), patch.object(guest_toolchain, 'LFS', lfs), \
                    patch.object(guest_toolchain, 'guest_install_guard'), \
                    patch.object(guest_toolchain, 'build_staged') as builder:
                with self.assertRaisesRegex(RuntimeError, 'canonical recipe files'):
                    guest_toolchain.run_sequence(plan, lfs, result)
                builder.assert_not_called(); self.assertFalse(result.exists())


class AbiSanityTests(unittest.TestCase):
    def elf(self, path, abi, machine=None, interpreter=None):
        cls, expected_machine, expected_interpreter, _, _ = toolchain_sanity.ABIS[abi]
        header, entry = (64, 56) if cls == 2 else (52, 32)
        text = (interpreter or expected_interpreter).encode() + b'\0'
        raw = bytearray(header + entry + len(text))
        raw[:7] = b'\x7fELF' + bytes((cls, 1, 1))
        struct.pack_into('<HHI', raw, 16, 3, machine or expected_machine, 1)
        if cls == 2:
            struct.pack_into('<Q', raw, 32, header); struct.pack_into('<HHH', raw, 52, header, entry, 1)
            struct.pack_into('<I', raw, header, 3); struct.pack_into('<Q', raw, header + 8, header + entry)
            struct.pack_into('<Q', raw, header + 32, len(text))
        else:
            struct.pack_into('<I', raw, 28, header); struct.pack_into('<HHH', raw, 40, header, entry, 1)
            struct.pack_into('<I', raw, header, 3); struct.pack_into('<I', raw, header + 4, header + entry)
            struct.pack_into('<I', raw, header + 16, len(text))
        raw[header + entry:] = text; path.write_bytes(raw)

    def test_actual_elf_bytes_reject_x32_wrong_interpreter_and_truncation(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            path = Path(directory) / 'probe'
            for abi in ('m64', 'm32'):
                self.elf(path, abi); toolchain_sanity.elf_identity(path, abi)
            self.elf(path, 'm32', machine=62)
            with self.assertRaisesRegex(RuntimeError, 'x32 forbidden'): toolchain_sanity.elf_identity(path, 'm32')
            self.elf(path, 'm64', interpreter='/srv/lfs/lib64/ld-linux-x86-64.so.2')
            with self.assertRaisesRegex(RuntimeError, 'interpreter differs'): toolchain_sanity.elf_identity(path, 'm64')
            path.write_bytes(path.read_bytes()[:64])
            with self.assertRaises(RuntimeError): toolchain_sanity.elf_identity(path, 'm64')

    def test_link_trace_rejects_host_headers_libraries_and_non_sysroot_search(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory); (root / 'usr/include').mkdir(parents=True)
            (root / 'usr/lib').mkdir(); libc = root / 'usr/lib/libc.so.6'; libc.write_bytes(b'fixture libc')
            db = root / 'var/lib/alp/db.json'; db.parent.mkdir(parents=True)
            db.write_text(json.dumps({'schema_version': 1, 'packages': {'glibc-cross-m64': {
                'status': 'installed', 'files': ['usr/lib/libc.so.6']}}}))
            stderr = '#include <...> search starts here:\n ' + str(root / 'usr/include') + '\nEnd of search list.\n'
            stdout = 'SEARCH_DIR("=/usr/lib");\nattempt to open ' + str(libc) + ' succeeded\n'
            toolchain_sanity.validate_trace(root, stdout, stderr)
            for out, err in ((stdout, stderr.replace(str(root / 'usr/include'), '/usr/include')),
                             (stdout.replace('=/usr/lib', '/usr/lib'), stderr),
                             (stdout.replace(str(libc), '/usr/lib/libc.so.6'), stderr)):
                with self.assertRaises(RuntimeError): toolchain_sanity.validate_trace(root, out, err)
            data = json.loads(db.read_text()); data['packages']['foreign'] = {'status': 'installed', 'files': ['/usr/lib/libc.so.6']}
            db.write_text(json.dumps(data))
            with self.assertRaisesRegex(RuntimeError, 'owner missing/conflicting'):
                toolchain_sanity.validate_trace(root, stdout, stderr)


class FilesystemLayoutTests(unittest.TestCase):
    def recipe(self):
        return json.loads((REPO / 'recipes/toolchain/filesystem-layout.json').read_text())

    def pin(self):
        return ctl.manifest()['local_sources'][0]

    def test_local_pin_rejects_modified_source_alias_and_ambiguous_name(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory); item = self.pin()
            path = root / item['path']; path.parent.mkdir(parents=True)
            shutil.copyfile(REPO / item['path'], path)
            package_stage.local_source_guard(item, root)
            manifest = {'sources': [], 'local_sources': [item]}
            manifest['sources'].append({**item})
            with self.assertRaisesRegex(RuntimeError, 'ambiguous'):
                package_stage.source_pin(manifest, item['filename'], root)
            path.write_bytes(path.read_bytes() + b' ')
            with self.assertRaisesRegex(RuntimeError, 'bytes changed'):
                package_stage.local_source_guard(item, root)
            path.unlink(); path.symlink_to(REPO / item['path'])
            with self.assertRaisesRegex(RuntimeError, 'bytes changed'):
                package_stage.local_source_guard(item, root)

    def test_two_layout_stages_have_identical_real_bundle_bytes(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, patch.object(package_stage, 'REPO', REPO):
            root = Path(directory); recipe = self.recipe(); hashes = []
            for label in ('a', 'b'):
                stage = filesystem_layout.render_layout(recipe, root / ('stage-' + label))
                built = package_stage.pack_staged(recipe, stage, root, 'layout-' + label, self.pin(),
                    {**os.environ, 'SOURCE_DATE_EPOCH': '1756684800', 'LC_ALL': 'C', 'LANG': 'C', 'TZ': 'UTC'}, 0.1)
                manifest = package_install.validate_bundle(recipe, built)
                self.assertEqual(len(manifest['entries']), 13)
                self.assertEqual(os.readlink(stage / 'lib32'), 'usr/lib32')
                self.assertFalse(os.path.lexists(stage / 'usr/lib64'))
                hashes.append((built['archive_sha256'], built['manifest_sha256']))
                with self.assertRaisesRegex(RuntimeError, 'new directory'):
                    filesystem_layout.render_layout(recipe, stage)
            self.assertEqual(hashes[0], hashes[1])

    def test_layout_cannot_smuggle_paths_or_follow_staging_parent_alias(self):
        recipe = self.recipe()
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory); (root / 'parent').mkdir(); (root / 'alias').symlink_to(root / 'parent')
            with self.assertRaisesRegex(RuntimeError, 'resolved parent'):
                filesystem_layout.render_layout(recipe, root / 'alias/stage')
            recipe['symlinks']['escape'] = '../../usr'
            with self.assertRaisesRegex(RuntimeError, 'path whitelist'):
                filesystem_layout.render_layout(recipe, root / 'bad')
            self.assertFalse((root / 'bad').exists())

    def test_host_cannot_invoke_production_layout_generator(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, \
                patch.object(filesystem_layout, 'LFS', Path(directory)), \
                patch.object(package_install.os, 'geteuid', return_value=1000), \
                patch.object(filesystem_layout, 'pack_staged') as pack:
            with self.assertRaisesRegex(RuntimeError, 'host invocation refused'):
                filesystem_layout.build_layout(self.recipe(), 'layout', Path(directory))
            pack.assert_not_called(); self.assertEqual(list(Path(directory).iterdir()), [])

    def test_actual_layout_requires_exact_aliases_and_single_alp_owner(self):
        changes = ('none', 'foreign-owner', 'wrong-link', 'forbidden-dir', 'wrong-mode')
        for change in changes:
            with self.subTest(change=change), tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, \
                    patch.object(filesystem_layout, 'REPO', REPO):
                root = Path(directory) / 'target'
                filesystem_layout.render_layout(self.recipe(), root)
                db = root / 'var/lib/alp/db.json'; db.parent.mkdir(parents=True)
                record = {'status': 'installed', 'version': filesystem_layout.VERSION, 'method': 'core',
                          'protected': True, 'files': list(filesystem_layout.LINKS),
                          'symlinks': list(filesystem_layout.LINKS)}
                data = {'schema_version': 1, 'packages': {filesystem_layout.NAME: record}}
                if change == 'foreign-owner': data['packages']['foreign'] = {'files': ['/lib32']}
                db.write_text(json.dumps(data))
                if change == 'wrong-link':
                    (root / 'lib').unlink(); (root / 'lib').symlink_to('usr/lib32')
                if change == 'forbidden-dir': (root / 'usr/lib64').mkdir()
                if change == 'wrong-mode': (root / 'usr/bin').chmod(0o777)
                if change == 'none': filesystem_layout.require_layout(root)
                else:
                    with self.assertRaises(RuntimeError): filesystem_layout.require_layout(root)

    def test_layout_install_and_resume_use_pinned_core_adapter(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory); recipe, item = self.recipe(), self.pin()
            repo, infra, lfs = root / 'repo', root / 'infra', root / 'lfs'
            for path in (repo / 'scripts', repo / 'runtime', repo / 'manifests', repo / 'recipes/toolchain', infra, lfs):
                path.mkdir(parents=True)
            shutil.copyfile(REPO / item['path'], repo / item['path'])
            (repo / 'scripts/capture-package-manifest.py').symlink_to(REPO / 'scripts/capture-package-manifest.py')
            (repo / 'scripts/compare-package-manifest.py').symlink_to(REPO / 'scripts/compare-package-manifest.py')
            alp = repo / 'runtime/alp.py'; alp.write_bytes(b'simulated CLI only')
            sources = {'sources': [], 'local_sources': [item], 'alp': {'sha256': package_install.sha(alp)},
                       'source_date_epoch': 1756684800, 'abi_selection': {'mode': 'multilib-m32'}}
            source_file = repo / 'manifests/infra-sources.json'; source_file.write_text(json.dumps(sources))
            inputs = {'inputs_sha256': '1' * 64, 'sources_sha256': package_stage.sha(source_file)}
            (infra / 'inputs.json').write_text(json.dumps(inputs))
            handoff_fixture(infra, inputs)
            stage = filesystem_layout.render_layout(recipe, root / 'stage')
            result = lfs / 'results/layout'; result.mkdir(parents=True)
            invocations = []

            def execute(argv, log, env=None):
                if argv[0] == package_install.PYTHON:
                    invocations.append(argv)
                    if 'install' in argv:
                        index = json.loads(Path(argv[argv.index('--index') + 1]).read_text())
                        entry = index['entries'][filesystem_layout.NAME]
                        shutil.copytree(stage, lfs, symlinks=True, dirs_exist_ok=True)
                        db = lfs / 'var/lib/alp/db.json'; db.parent.mkdir(parents=True)
                        manifest = json.loads(built['manifest'].read_text())
                        db.write_text(json.dumps({'schema_version': 1, 'packages': {filesystem_layout.NAME: {
                            'version': recipe['version'], 'status': 'installed', 'method': 'core', 'protected': entry['protected'],
                            'source': {'url': entry['url'], 'sha256': entry['sha256']},
                            'files': [e['path'] for e in manifest['entries']], 'symlinks': list(filesystem_layout.LINKS)}}}))
                else: subprocess.run(argv, env=env, check=True, capture_output=True)

            with patch.object(package_stage, 'REPO', repo), patch.object(package_stage, 'INFRA', infra), \
                    patch.object(package_install, 'REPO', repo), patch.object(package_install, 'INFRA', infra), \
                    patch.object(package_install, 'LFS', lfs), patch.object(package_install, 'guest_install_guard'), \
                    patch.object(filesystem_layout, 'REPO', repo), patch.object(package_install, 'run', side_effect=execute):
                built = package_stage.pack_staged(recipe, stage, result, 'layout', item,
                    {**os.environ, 'SOURCE_DATE_EPOCH': '1756684800'}, 0.1)
                receipt = package_install.install_staged(recipe, built, lfs, result)
                self.assertEqual(receipt['result'], 'PASS')
                snapshot = result / (recipe['name'] + '.db.json')
                snapshot_raw = snapshot.read_bytes()
                self.assertEqual(package_stage.sha(snapshot), receipt['db_sha256'])
                snapshot.write_bytes(b'changed raw installation DB')
                with self.assertRaisesRegex(RuntimeError, 'raw DB snapshot changed'):
                    package_install.verify_installed(recipe, built, lfs, result)
                snapshot.write_bytes(snapshot_raw)  # Fixture bytes only; no production normalization.
                package_install.verify_installed(recipe, built, lfs, result)
                self.assertEqual(len(invocations), 2)  # install/check; no reinstall on resume
                (lfs / 'lib32').unlink(); (lfs / 'lib32').symlink_to('usr/lib')
                with self.assertRaisesRegex(RuntimeError, 'alias missing/changed'):
                    package_install.verify_installed(recipe, built, lfs, result)


class ToolchainArtifactExportTests(unittest.TestCase):
    def test_host_cannot_export_installed_payload_or_create_artifacts(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory)
            with self.assertRaisesRegex(RuntimeError, 'host invocation refused'):
                toolchain_artifacts.export_guest([], root, root / 'result', {'result': 'PASS'})
            self.assertEqual(list(root.iterdir()), [])


class StabilityEvidenceTests(unittest.TestCase):
    def fixture(self, root):
        # Real tar/manifest bytes; simulated Alp records, no engine/CPU load.
        recipe, built, stage = PackageInstallationTests().fixture(root)
        recipe['phase'] = 'stability'
        sources = {'sources': [built['source']], 'alp': {'sha256': '2' * 64},
                   'source_date_epoch': 1756684800, 'abi_selection': {'mode': 'multilib-m32'}}
        pins = {'inputs_sha256': '1' * 64, 'sources_sha256': '3' * 64,
                'alp_sha256': '2' * 64, 'source_date_epoch': 1756684800}
        url = f'file:///srv/lfs/packages/fixture-1-{built["archive_sha256"]}.tar.gz'
        entries = json.loads(built['manifest'].read_text())['entries']
        record = {'status': 'installed', 'version': '1', 'method': 'core',
                  'source': {'url': url, 'sha256': built['archive_sha256']},
                  'files': [e['path'] for e in entries if e['type'] != 'directory'],
                  'symlinks': ['/usr/bin/alias']}
        database = {'schema_version': 1, 'packages': {'fixture': record}}

        def proof(run_id, directory, target, db_name, jobs=None):
            archive, captured = root / (run_id + '.tar.gz'), root / (run_id + '.json')
            shutil.copyfile(built['archive'], archive); shutil.copyfile(built['manifest'], captured)
            dest = root / directory; dest.mkdir()
            db_path = root / db_name; db_path.write_text(json.dumps(database))
            index = dest / 'fixture.index.json'
            index.write_text(json.dumps({'schema_version': 1, 'entries': {'fixture': {
                'method': 'core', 'name': 'fixture', 'version': '1', 'url': url,
                'sha256': built['archive_sha256'], 'depends': [], 'protected': False}}}))
            receipt = {**pins, 'result': 'PASS', 'package': 'fixture', 'version': '1', 'root': target,
                       'recipe_sha256': package_install.fingerprint(recipe),
                       'archive_sha256': built['archive_sha256'], 'manifest_sha256': built['manifest_sha256'],
                       'db_sha256': package_install.sha(db_path),
                       'package_record_sha256': package_install.fingerprint(record),
                       'index_sha256': package_install.sha(index),
                       'index': '/srv/lfs/results/stability/' + directory + '/fixture.index.json'}
            receipt_path = dest / 'fixture.installed.json'; receipt_path.write_text(json.dumps(receipt))
            row = {**guest_stability.bundle_record({**built, 'archive': archive, 'manifest': captured, 'seconds': 10}, jobs),
                   'receipt': directory + '/fixture.installed.json', 'db': db_name,
                   'receipt_sha256': package_install.sha(receipt_path), 'db_sha256': package_install.sha(db_path),
                   'root': target}
            return row

        sbu = [proof(f'binutils-sbu-j{jobs}', f'sbu-j{jobs}', '/srv/lfs/sbu-root', f'sbu-j{jobs}/db.json', jobs)
               for jobs in (1, 16)]
        pairs = [proof(f'zlib-oc-{i}', f'zlib-{label}', f'/srv/lfs/stability-db-{label}', f'db-repro-{label}.json')
                 for i, label in ((1, 'a'), (2, 'b'))]
        evidence = {'equal': True, 'records': pairs}
        (root / 'db-repro-evidence.json').write_text(json.dumps(evidence))
        summary = {**pins, 'result': 'PASS', 'mode': 'multilib-m32', 'seconds': 1220,
                   'sbu': sbu, 'zlib': pairs, 'db_sha256': [r['db_sha256'] for r in pairs],
                   'stress': [{'ok': True, 'loops': 1}] * 16}
        (root / 'summary.json').write_text(json.dumps(summary))
        return sources, {'sbu': recipe, 'zlib': recipe}, summary

    def test_saved_bundle_install_db_and_current_pins_are_verified(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory); sources, recipes, summary = self.fixture(root)
            value = stability_evidence.verify_stability_artifacts(root, sources, '1' * 64, '3' * 64, recipes)
            self.assertEqual(value['db_sha256'][0], value['db_sha256'][1])
            self.assertIn('db-repro-b.json', value['artifact_sha256'])
            with self.assertRaisesRegex(RuntimeError, 'pins changed'):
                stability_evidence.verify_stability_artifacts(root, sources, 'f' * 64, '3' * 64, recipes)

    def test_pass_string_cannot_hide_changed_raw_db_or_archive(self):
        for name, payload in (('db-repro-b.json', b'changed raw DB'), ('zlib-oc-2.tar.gz', b'changed archive')):
            with self.subTest(name=name), tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
                root = Path(directory); sources, recipes, summary = self.fixture(root)
                (root / name).write_bytes(payload)
                with self.assertRaises(RuntimeError):
                    stability_evidence.verify_stability_artifacts(root, sources, '1' * 64, '3' * 64, recipes)

    def test_timestamp_only_db_difference_cannot_be_normalized_away(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory); sources, recipes, summary = self.fixture(root)
            db_path = root / 'db-repro-b.json'; db = json.loads(db_path.read_text())
            db['packages']['fixture']['updated_at'] = '2026-10-01T12:00:01Z'
            db_path.write_text(json.dumps(db)); new_hash = package_install.sha(db_path)
            receipt_path = root / 'zlib-b/fixture.installed.json'
            receipt = json.loads(receipt_path.read_text())
            receipt.update(db_sha256=new_hash, package_record_sha256=package_install.fingerprint(db['packages']['fixture']))
            receipt_path.write_text(json.dumps(receipt))
            evidence_path = root / 'db-repro-evidence.json'; evidence = json.loads(evidence_path.read_text())
            evidence['records'][1].update(db_sha256=new_hash, receipt_sha256=package_install.sha(receipt_path))
            evidence_path.write_text(json.dumps(evidence))  # Even with the claimed equal flag still true.
            summary['db_sha256'][1] = new_hash
            (root / 'summary.json').write_text(json.dumps(summary))
            with self.assertRaisesRegex(RuntimeError, 'raw DB hashes differ'):
                stability_evidence.verify_stability_artifacts(root, sources, '1' * 64, '3' * 64, recipes)

    def test_incomplete_compute_time_or_alias_roots_are_rejected(self):
        mutations = [lambda s: s.update(seconds=1199), lambda s: s['stress'][0].update(loops=0),
                     lambda s: s['zlib'][1].update(archive=s['zlib'][0]['archive'])]
        for mutate in mutations:
            with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
                root = Path(directory); sources, recipes, summary = self.fixture(root)
                mutate(summary); (root / 'summary.json').write_text(json.dumps(summary))
                with self.assertRaises(RuntimeError):
                    stability_evidence.verify_stability_artifacts(root, sources, '1' * 64, '3' * 64, recipes)

    def test_pair_keeps_unequal_raw_databases_across_clock_tick(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory); lfs = root / 'lfs'; lfs.mkdir(); result = root / 'results'; result.mkdir()

            def install(recipe, built, target, evidence):
                db = target / 'var/lib/alp/db.json'; db.parent.mkdir(parents=True)
                db.write_text(json.dumps({'updated_at': target.name}))
                (evidence / 'zlib.installed.json').write_text('{}')

            with patch.object(guest_stability, 'LFS', lfs), \
                    patch.object(guest_stability, 'install_staged', side_effect=install), \
                    patch.object(guest_stability.time, 'sleep') as sleep:
                evidence = guest_stability.install_pair({'name': 'zlib'}, ({}, {}), result)
                self.assertFalse(evidence['equal'])
                sleep.assert_called_once_with(1.2)
                self.assertNotEqual((result / 'db-repro-a.json').read_bytes(), (result / 'db-repro-b.json').read_bytes())
                self.assertEqual(json.loads((result / 'db-repro-evidence.json').read_text()), evidence)

    def test_invalid_collected_artifacts_shut_down_without_checkpoint(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, stage_job_fixture(directory) as context, \
                patch.object(ctl, 'LOGS', Path(directory)), patch.object(ctl, 'ARTIFACTS', Path(directory)), \
                patch.object(ctl, 'run_monitored', return_value={'fixture_command': True}), patch.object(ctl, 'run'), patch.object(ctl, 'stop') as stop, \
                patch.object(ctl, 'pid', return_value=None), patch.object(ctl, 'checkpoint') as checkpoint:
            with self.assertRaisesRegex(RuntimeError, 'no checkpoint'):
                ctl.stability_run(context[:2])
            stop.assert_called_once(); checkpoint.assert_not_called()
            record = json.loads((stage_runs.RUNS / context[0]['run_id'] / 'outcome.json').read_text())
            self.assertEqual(record['result'], 'FAIL')
            self.assertIsNone(record['guest_artifact_evidence'])

    def test_stability_recipe_cannot_build_without_current_oc_inputs(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, \
                patch.object(package_stage, 'INFRA', Path(directory)), patch.object(package_stage, 'REPO', REPO), \
                patch.object(package_stage, 'run') as run:
            root = Path(directory)
            recipe = json.loads((REPO / 'recipes/bootstrap/binutils-sbu.json').read_text())
            with self.assertRaisesRegex(RuntimeError, 'authorization missing'):
                package_stage.build_staged(recipe, 'binutils-sbu-j1', root)
            run.assert_not_called()
            inputs = {'inputs_sha256': '1' * 64, 'sources_sha256': package_stage.sha(REPO / 'manifests/infra-sources.json')}
            (root / 'inputs.json').write_text(json.dumps(inputs))
            auth = {**inputs, 'stage': 'stability', 'mode': 'multilib-m32', 'oc_confirmed': True}
            (root / 'phase2-authorization.json').write_text(json.dumps(auth))
            package_stage.heavy_recipe_guard(recipe)  # Only validates the guard; no build.
            auth['inputs_sha256'] = 'f' * 64
            (root / 'phase2-authorization.json').write_text(json.dumps(auth))
            with self.assertRaisesRegex(RuntimeError, 'input mismatch'):
                package_stage.build_staged(recipe, 'binutils-sbu-j1', root)
            run.assert_not_called()


class ToolchainPreparationTests(unittest.TestCase):
    def test_heavy_recipe_needs_current_oc_abi_and_stability(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, \
                patch.object(package_stage, 'INFRA', Path(directory)), \
                patch.object(package_stage, 'REPO', REPO), \
                patch.object(package_stage, 'run') as run:
            recipe = json.loads((REPO / 'recipes/toolchain/gcc-pass1.json').read_text())
            with self.assertRaisesRegex(RuntimeError, 'verified stability receipt'):
                package_stage.build_staged(recipe, 'gcc-pass1', Path(directory))
            run.assert_not_called()
            root = Path(directory)
            inputs = {'inputs_sha256': '1' * 64,
                      'sources_sha256': package_stage.sha(REPO / 'manifests/infra-sources.json')}
            (root / 'inputs.json').write_text(json.dumps(inputs))
            receipt, auth = handoff_fixture(root, inputs)
            package_stage.heavy_recipe_guard(recipe)
            for bad in ({**receipt, 'mode': 'x86_64'}, {**receipt, 'result': 'FAIL'},
                        {**receipt, 'inputs_sha256': 'f' * 64}):
                (root / 'stability-acceptance.json').write_text(json.dumps(bad))
                with self.assertRaises(RuntimeError):
                    package_stage.heavy_recipe_guard(recipe)

    def test_prerequisite_mismatch_stops_before_build_or_extraction(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory); repo, lfs = root / 'repo', root / 'lfs'
            (repo / 'manifests').mkdir(parents=True)
            (lfs / 'sources').mkdir(parents=True)
            source = lfs / 'sources/main.tar'; source.write_bytes(b'main')
            dependency = lfs / 'sources/dependency.tar'; dependency.write_bytes(b'wrong bytes')
            manifest = {'source_date_epoch': 1756684800, 'sources': [
                {'filename': 'main.tar', 'sha256': package_stage.sha(source)},
                {'filename': 'dependency.tar', 'sha256': '0' * 64}]}
            (repo / 'manifests/infra-sources.json').write_text(json.dumps(manifest))
            recipe = {'source': 'main.tar', 'jobs': 1, 'prerequisites': [
                      {'source': 'dependency.tar', 'directory': 'dependency'}]}
            with patch.object(package_stage, 'REPO', repo), patch.object(package_stage, 'LFS', lfs), \
                    patch.object(package_stage, 'run') as run:
                with self.assertRaisesRegex(RuntimeError, 'Prerequisite source hash mismatch'):
                    package_stage.build_staged(recipe, 'fixture', root)
                run.assert_not_called()
                self.assertFalse((lfs / 'build').exists())

    def test_staged_relative_path_cannot_follow_escape(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory); (root / 'escape').symlink_to('/usr')
            for name in ('/usr/include/limits.h', '../limits.h', 'escape/include/limits.h'):
                with self.assertRaises(RuntimeError):
                    package_stage.relative_path(root, name)

    def test_pass1_recipes_use_m32_and_pinned_prerequisites(self):
        manifest = ctl.manifest()
        sources = {s['filename'] for s in [*manifest['sources'], *manifest.get('local_sources', [])]}
        for path in (REPO / 'recipes/toolchain').glob('*.json'):
            recipe = json.loads(path.read_text())
            package_stage.validate_recipe(recipe, recipe['jobs'])
            self.assertEqual(recipe['abi'], 'multilib-m32')
            self.assertIn(recipe['source'], sources)
            for prerequisite in recipe.get('prerequisites', []):
                self.assertIn(prerequisite['source'], sources)
            for patch in recipe.get('patches', []):
                self.assertIn(patch['source'], sources)
            for argv in recipe['stage']:
                if argv[0] == 'make' and 'install' in argv:
                    self.assertTrue(any(a in ('DESTDIR={stage}', 'DESTDIR={source}/build/DESTDIR') for a in argv))
        gcc = json.loads((REPO / 'recipes/toolchain/gcc-pass1.json').read_text())
        self.assertIn('--with-multilib-list=m64,m32', gcc['compile'][0])
        self.assertNotIn('--disable-multilib', gcc['compile'][0])
        self.assertNotIn('mx32', json.dumps(gcc))


class HostMonitorTests(unittest.TestCase):
    def snapshot(self, errors=None, boot='same-boot', throttle=None):
        return {'errors': errors or [], 'boot_id': boot, 'journal_cursor': 'cursor',
                'throttle_counters': throttle or {}}

    def test_journal_warning_or_bad_cursor_cannot_pass(self):
        for record in ({'exit': 0, 'stderr': 'Journal file corrupted, ignoring file.', 'stdout': ''},
                       {'exit': 1, 'stderr': '', 'stdout': ''},
                       {'exit': 0, 'stderr': '', 'stdout': '{"MESSAGE":"text"}'}):
            with self.assertRaises(RuntimeError):
                host_monitor.kernel_records(record)
        self.assertEqual(len(host_monitor.kernel_records({'exit': 0, 'stderr': '',
                         'stdout': '{"MESSAGE":"text","__CURSOR":"cursor"}'})), 1)

    def test_machine_errors_are_fatal_but_feature_not_supported_is_not(self):
        for text in ('mce: [Hardware Error]: Machine check events logged',
                     'BTRFS error (device nvme0n1p3): corruption',
                     'Out of memory: Killed process 12 (cc1)', 'I/O error, dev sda'):
            self.assertIsNotNone(host_monitor.FAULT.search(text))
        self.assertIsNone(host_monitor.FAULT.search('TDX not supported by BIOS'))

    def test_boot_and_throttle_changes_veto_stage(self):
        baseline = self.snapshot(throttle={'cpu0': 2})
        for current in (self.snapshot(boot='new-boot', throttle={'cpu0': 2}),
                        self.snapshot(throttle={'cpu0': 3}), self.snapshot()):
            with self.assertRaises(RuntimeError):
                host_monitor.check_progress(baseline, current)

    def test_bad_baseline_does_not_launch_command_and_preserves_sample(self):
        telemetry = io.StringIO()
        with patch.object(host_monitor.subprocess, 'Popen') as start:
            with self.assertRaisesRegex(RuntimeError, 'coverage'):
                host_monitor.run_monitored(['unreachable'], io.BytesIO(), telemetry, lambda: None,
                    sampler=lambda cursor: self.snapshot(['coverage missing']))
            start.assert_not_called()
        self.assertIn('coverage missing', telemetry.getvalue())

    def test_new_fault_stops_local_command_group(self):
        from unittest.mock import Mock
        process = Mock()
        process.wait.side_effect = [subprocess.TimeoutExpired('ssh', 10), 0]
        process.poll.return_value = None
        snapshots = iter([self.snapshot(), self.snapshot(['new hardware error'])])
        with patch.object(host_monitor.subprocess, 'Popen', return_value=process), \
                patch.object(host_monitor.os, 'killpg') as kill:
            with self.assertRaisesRegex(RuntimeError, 'hardware error'):
                host_monitor.run_monitored(['ssh'], io.BytesIO(), io.StringIO(), lambda: None,
                    sampler=lambda cursor: next(snapshots))
            kill.assert_called_once_with(process.pid, host_monitor.signal.SIGTERM)

    def test_guest_failure_collects_evidence_and_shuts_down(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, stage_job_fixture(directory) as context, \
                patch.object(ctl, 'LOGS', Path(directory)), patch.object(ctl, 'sync'), \
                patch.object(ctl, 'run_monitored', side_effect=RuntimeError('guest fault')), \
                patch.object(ctl, 'run') as collect, patch.object(ctl, 'stop') as stop, \
                patch.object(ctl, 'pid', return_value=None), patch.object(ctl, 'checkpoint') as checkpoint:
            with self.assertRaisesRegex(RuntimeError, 'no checkpoint'):
                ctl.stability_run(context[:2])
            collect.assert_called_once()
            self.assertEqual(collect.call_args.args[0][0], 'rsync')
            stop.assert_called_once()
            checkpoint.assert_not_called()
            outcome = json.loads((stage_runs.RUNS / context[0]['run_id'] / 'outcome.json').read_text())
            self.assertEqual(outcome['result'], 'FAIL')
            self.assertIn('guest fault', outcome['errors'][0])

    def test_staged_manifest_gets_pinned_epoch_without_caller_environment(self):
        # Run the real manifest/archive tools on fixture payloads. Build,
        # extraction and chown are replaced: no host root or compilation.
        original_run = subprocess.run
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory)
            repo, lfs = root / 'repo', root / 'lfs'
            (repo / 'manifests').mkdir(parents=True)
            (repo / 'scripts').mkdir()
            (repo / 'scripts/capture-package-manifest.py').symlink_to(REPO / 'scripts/capture-package-manifest.py')
            for name in ('sources', 'build', 'stage', 'results'):
                (lfs / name).mkdir(parents=True, exist_ok=True)
            source = lfs / 'sources/fixture.tar'
            source.write_bytes(b'fixture source; extraction is mocked')
            item = {'filename': source.name, 'sha256': package_stage.sha(source),
                    'url': 'https://example.invalid/fixture'}
            (repo / 'manifests/infra-sources.json').write_text(json.dumps(
                {'sources': [item], 'source_date_epoch': 1756684800}))
            recipe = {'name': 'fixture', 'version': '1', 'source': source.name,
                      'jobs': 1, 'compile': [], 'test': [], 'stage': []}

            def fake_recipe(argv, log, cwd=None, env=None):
                if argv[0] in ('python3', 'bash'):
                    original_run(argv, cwd=cwd, env=env, check=True, capture_output=True)
                elif 'tar' in argv:
                    (lfs / 'stage' / Path(argv[-1]).name / 'payload').write_bytes(b'fixed payload')

            def safe_subprocess(argv, **kwargs):
                if argv[0] == 'chown':
                    return subprocess.CompletedProcess(argv, 0)
                return original_run(argv, **kwargs)

            with patch.object(package_stage, 'REPO', repo), patch.object(package_stage, 'LFS', lfs), \
                    patch.object(package_stage, 'run', side_effect=fake_recipe), \
                    patch.object(package_stage.subprocess, 'run', side_effect=safe_subprocess), \
                    patch.dict(os.environ, {'SOURCE_DATE_EPOCH': '1'}):
                first = package_stage.build_staged(recipe, 'fixture-a', lfs / 'results')
                second = package_stage.build_staged(recipe, 'fixture-b', lfs / 'results')
            captured = json.loads(first['manifest'].read_text())
            self.assertEqual(captured['captured_at'], '2025-09-01T00:00:00+00:00')
            self.assertEqual(first['manifest_sha256'], second['manifest_sha256'])
            self.assertEqual(first['archive_sha256'], second['archive_sha256'])


class GuestProcessTests(unittest.TestCase):
    @staticmethod
    def sample(free=30):
        return {'time_ns': 1, 'volumes': {path: {'total': 100, 'available': free,
                'device': 1, 'inode': inode} for path, inode in (('/', 10), ('/srv/lfs', 20))}}

    def test_low_baseline_preserves_evidence_without_launch(self):
        telemetry = io.StringIO()
        with patch.object(guest_process.subprocess, 'Popen') as start:
            with self.assertRaisesRegex(RuntimeError, 'below 15%'):
                guest_process.monitor_command(['unreachable'], io.BytesIO(), subprocess.STDOUT,
                                              telemetry, sampler=lambda: self.sample(14))
            start.assert_not_called()
        record = json.loads(telemetry.getvalue())
        self.assertEqual(record['event'], 'before-command')
        self.assertEqual(record['volumes']['/']['available'], 14)

    def test_boundary_identity_and_invalid_values(self):
        baseline = self.sample(15)
        guest_process.check_space(None, baseline)
        guest_process.check_space(baseline, self.sample(20))
        for field in ('device', 'inode'):
            current = self.sample(); current['volumes']['/srv/lfs'][field] += 1
            with self.assertRaisesRegex(RuntimeError, 'identity changed'):
                guest_process.check_space(baseline, current)
        bad_samples = [self.sample() for _ in range(6)]
        bad_samples[0]['volumes'].pop('/srv/lfs')
        bad_samples[1]['volumes']['/']['available'] = True
        bad_samples[2]['volumes']['/']['total'] = 0
        bad_samples[3]['volumes']['/']['available'] = 101
        bad_samples[4]['volumes']['/'] = None
        bad_samples[5]['volumes']['/']['inode'] = -1
        for current in bad_samples:
            with self.assertRaises(RuntimeError):
                guest_process.check_space(None, current)

    def test_final_sample_vetoes_success_and_cleans_group(self):
        from unittest.mock import Mock
        process = Mock(); process.pid = 123; process.wait.return_value = 0
        samples = iter((self.sample(), self.sample(14)))
        telemetry = io.StringIO()
        with patch.object(guest_process.subprocess, 'Popen', return_value=process), \
                patch.object(guest_process, 'stop_group') as stop:
            with self.assertRaisesRegex(RuntimeError, 'below 15%'):
                guest_process.monitor_command(['fixture'], io.BytesIO(), subprocess.STDOUT,
                                              telemetry, sampler=lambda: next(samples))
            stop.assert_called_once_with(process)
        self.assertEqual(json.loads(telemetry.getvalue().splitlines()[-1])['event'], 'after-command')

    def test_sampling_failure_is_preserved_and_stops_child(self):
        from unittest.mock import Mock
        process = Mock(); process.pid = 123; process.wait.side_effect = subprocess.TimeoutExpired('fixture', .01)
        telemetry = io.StringIO(); samples = iter((self.sample(), OSError('disk unavailable')))
        def sample():
            value = next(samples)
            if isinstance(value, Exception):
                raise value
            return value
        with patch.object(guest_process.subprocess, 'Popen', return_value=process), \
                patch.object(guest_process, 'stop_group') as stop:
            with self.assertRaisesRegex(RuntimeError, 'telemetry failed'):
                guest_process.monitor_command(['fixture'], io.BytesIO(), subprocess.STDOUT,
                                              telemetry, interval=.01, sampler=sample)
            stop.assert_called_once_with(process)
        self.assertIn('disk unavailable', telemetry.getvalue())

    def test_telemetry_write_failure_after_launch_stops_child(self):
        from unittest.mock import Mock
        telemetry = Mock(); telemetry.write.side_effect = [None, OSError('log full')]
        process = Mock(); process.pid = 123
        with patch.object(guest_process.subprocess, 'Popen', return_value=process), \
                patch.object(guest_process, 'stop_group') as stop:
            with self.assertRaisesRegex(OSError, 'log full'):
                guest_process.monitor_command(['fixture'], io.BytesIO(), subprocess.STDOUT,
                                              telemetry, sampler=self.sample)
            stop.assert_called_once_with(process)

    def test_short_real_command_and_nonzero_exit(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            output = Path(directory) / 'output'
            with output.open('wb') as stream:
                guest_process.monitor_command([sys.executable, '-c',
                    'import sys; print(sys.stdin.read().upper(), end="")'], stream,
                    subprocess.STDOUT, io.StringIO(), input='small compiler fixture\n',
                    text=True, sampler=self.sample)
            self.assertEqual(output.read_text(), 'SMALL COMPILER FIXTURE\n')
            with output.open('wb') as stream:
                with self.assertRaises(subprocess.CalledProcessError) as error:
                    guest_process.monitor_command([sys.executable, '-c', 'raise SystemExit(7)'],
                        stream, subprocess.STDOUT, io.StringIO(), sampler=self.sample)
                self.assertEqual(error.exception.returncode, 7)

    def test_actual_space_fault_stops_parent_and_descendant(self):
        # No compiler/root/VM: one sleeping process and its own child only.
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory); marker = root / 'pids.json'
            code = ('import json, os, subprocess, sys, time; '
                    'child=subprocess.Popen([sys.executable,"-c","import time; time.sleep(60)"]); '
                    'open(sys.argv[1],"w").write(json.dumps([os.getpid(),child.pid])); '
                    'time.sleep(60)')
            telemetry = io.StringIO()
            with (root / 'output').open('wb') as stream:
                with self.assertRaisesRegex(RuntimeError, 'below 15%'):
                    guest_process.monitor_command([sys.executable, '-c', code, str(marker)],
                        stream, subprocess.STDOUT, telemetry, interval=.02,
                        sampler=lambda: self.sample(14 if marker.exists() else 30))
            parent, child = json.loads(marker.read_text())
            self.assertFalse(Path(f'/proc/{parent}').exists())
            child_stat = Path(f'/proc/{child}/stat')
            if child_stat.exists():
                self.assertEqual(child_stat.read_text().rpartition(') ')[2].split()[0], 'Z')
            self.assertEqual(json.loads(telemetry.getvalue().splitlines()[-1])['event'], 'command-running')

    def test_host_root_refused_before_log_or_command(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            log = Path(directory) / 'uncreated.log'
            with patch.object(package_stage.os, 'geteuid', return_value=0), \
                    patch.object(guest_process.subprocess, 'Popen') as start:
                with self.assertRaises(RuntimeError):
                    package_stage.run(['unreachable'], log)
                start.assert_not_called()
            self.assertFalse(log.exists())
            self.assertFalse(log.with_name(log.name + '.space.jsonl').exists())

    def test_exited_leader_does_not_skip_descendant_kill(self):
        from unittest.mock import Mock, call
        process = Mock(); process.pid = 123; process.poll.return_value = 0
        with patch.object(guest_process.os, 'killpg') as kill, \
                patch.object(guest_process.time, 'monotonic', side_effect=(0, 6)):
            guest_process.stop_group(process)
        self.assertEqual(kill.call_args_list, [call(123, guest_process.signal.SIGTERM),
                                               call(123, guest_process.signal.SIGKILL)])
        process.wait.assert_called_once_with(timeout=5)


class PackageArchiveProcessTests(unittest.TestCase):
    def fixture(self, root):
        stage = root / "payload ' $literal"; stage.mkdir()
        (stage / 'fixture').write_bytes(b'fixed payload\n')
        result = root / "results ' $literal"; result.mkdir()
        recipe = {'name': 'fixture', 'version': '1'}
        item = {'url': 'https://example.invalid/source', 'sha256': '0' * 64}
        env = {**os.environ, 'SOURCE_DATE_EPOCH': '1756684800', 'LC_ALL': 'C', 'TZ': 'UTC'}
        return stage, result, recipe, item, env

    def test_quoted_paths_produce_equal_real_archives(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            stage, result, recipe, item, env = self.fixture(Path(directory))
            with patch.object(package_stage, 'REPO', REPO):
                bundles = [package_stage.pack_staged(recipe, stage, result, name, item, env, 0)
                           for name in ('first', 'second')]
            for bundle in bundles:
                package_install.validate_bundle(recipe, bundle)
            self.assertEqual(bundles[0]['archive_sha256'], bundles[1]['archive_sha256'])
            self.assertEqual(bundles[0]['manifest_sha256'], bundles[1]['manifest_sha256'])

    def test_tar_failure_is_not_hidden_by_successful_gzip(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory)
            stage, result, recipe, item, env = self.fixture(root)
            commands = root / 'commands'; commands.mkdir()
            for name, code in (('tar', 'exit 7'), ('gzip', '/bin/cat')):
                path = commands / name; path.write_text('#!/bin/bash\n' + code + '\n'); path.chmod(0o755)
            env['PATH'] = str(commands) + ':/usr/bin:/bin'
            with patch.object(package_stage, 'REPO', REPO):
                with self.assertRaises(subprocess.CalledProcessError) as error:
                    package_stage.pack_staged(recipe, stage, result, 'failed', item, env, 0)
                self.assertEqual(error.exception.returncode, 7)
            self.assertTrue((result / 'failed.json').is_file())
            self.assertTrue((result / 'failed.tar.gz').is_file())
            self.assertTrue((result / 'failed.log').is_file())


class BackgroundSuiteTests(unittest.TestCase):
    def fixture(self, directory):
        root = Path(directory); lfs = root / 'lfs'; infra = root / 'infra'
        infra.mkdir(); build = lfs / 'build/gcc'; build.mkdir(parents=True)
        (build / 'Makefile').write_text('# fixture only; never a compiler build\n')
        (lfs / 'results').mkdir()
        inputs = {'inputs_sha256': '1' * 64,
                  'sources_sha256': package_stage.sha(REPO / 'manifests/infra-sources.json')}
        (infra / 'inputs.json').write_text(json.dumps(inputs))
        return root, lfs, infra, build

    def guards(self, lfs, infra):
        import contextlib
        stack = contextlib.ExitStack()
        stack.enter_context(patch.object(guest_tests, 'LFS', lfs))
        stack.enter_context(patch.object(guest_tests, 'INFRA', infra))
        stack.enter_context(patch.object(guest_tests, 'REPO', REPO))
        stack.enter_context(patch.object(guest_tests, 'guest_install_guard'))
        stack.enter_context(patch.object(guest_tests, 'heavy_recipe_guard'))
        return stack

    def emit(self, build, failure=None, unfinished=False):
        for i, name in enumerate(('gcc.sum', 'g++.sum', 'libstdc++.sum')):
            text = 'PASS: fixture\n' * (50000 if i == 0 else 1)
            if i == 0 and failure:
                text += failure
            if not unfinished or i != 0:
                text += '\t=== fixture Summary ===\n'
            (build / name).write_text(text)

    def test_direct_host_invocation_fails_before_evidence_or_child(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root, lfs, infra, build = self.fixture(directory)
            with patch.object(guest_tests, 'LFS', lfs), patch.object(guest_tests, 'run_logged') as run:
                with self.assertRaisesRegex(RuntimeError, 'guarded guest root'):
                    guest_tests.run_suite('gcc', build)
                run.assert_not_called()
            self.assertFalse((lfs / 'results/toolchain-tests').exists())

    def test_oc_gate_or_stale_summaries_prevent_launch_and_new_logs(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root, lfs, infra, build = self.fixture(directory)
            with self.guards(lfs, infra), patch.object(guest_tests, 'run_logged') as run:
                with patch.object(guest_tests, 'heavy_recipe_guard', side_effect=RuntimeError('OC gate closed')):
                    with self.assertRaisesRegex(RuntimeError, 'OC gate closed'):
                        guest_tests.run_suite('gcc', build)
                stale = build / 'gcc.sum'; stale.write_text('old evidence')
                with self.assertRaisesRegex(RuntimeError, 'Existing suite summaries'):
                    guest_tests.run_suite('gcc', build)
                run.assert_not_called()
            self.assertEqual(stale.read_text(), 'old evidence')
            self.assertFalse((lfs / 'results/toolchain-tests').exists())

    def test_unlisted_build_or_aliased_summary_cannot_start(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root, lfs, infra, build = self.fixture(directory)
            outside = root / 'outside'; outside.mkdir(); (outside / 'Makefile').write_text('outside fixture')
            target = root / 'old.sum'; target.write_text('preserved summary')
            with self.guards(lfs, infra), patch.object(guest_tests, 'run_logged') as run:
                with self.assertRaisesRegex(RuntimeError, 'not allowlisted'):
                    guest_tests.run_suite('gcc', outside)
                (build / 'gcc.sum').symlink_to(target)
                with self.assertRaisesRegex(RuntimeError, 'Unsafe suite summary path'):
                    guest_tests.run_suite('gcc', build)
                run.assert_not_called()
            self.assertEqual(target.read_text(), 'preserved summary')
            self.assertFalse((lfs / 'results/toolchain-tests').exists())

    def test_completed_known_failure_saves_raw_evidence_and_exit(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root, lfs, infra, build = self.fixture(directory)
            def make(argv, log, cwd=None, env=None):
                self.assertEqual(argv[-4:], ['make', '-j2', '-k', 'check'])
                self.assertEqual(argv[:4], ['runuser', '-u', 'lfs', '--'])
                self.assertIn('env', argv); self.assertIn('-i', argv)
                self.assertEqual(env['LC_ALL'], 'C')
                # Real safe child/monitor/exit path; the child writes synthetic
                # summaries, never invokes make, runuser or a compiler.
                code = ('from pathlib import Path; '
                        'names=("gcc.sum","g++.sum","libstdc++.sum"); '
                        '[(Path(name).write_text("PASS: fixture\\n"*(50000 if i==0 else 1)'
                        '+("FAIL: gcc.target/i386/pr90579.c scan-assembler fixture\\n"*4 if i==0 else "")'
                        '+"\\t=== fixture Summary ===\\n")) for i,name in enumerate(names)]; '
                        'print("fixture make log"); raise SystemExit(2)')
                with log.open('wb') as output, log.with_name(log.name + '.space.jsonl').open('w') as telemetry:
                    guest_process.monitor_command([sys.executable, '-c', code], output, subprocess.STDOUT,
                        telemetry, cwd=cwd, env=env, sampler=GuestProcessTests.sample)
            with self.guards(lfs, infra), patch.object(guest_tests, 'run_logged', side_effect=make):
                dest, outcome = guest_tests.run_suite('gcc', build)
            self.assertEqual(outcome['result'], 'PASS'); self.assertEqual(outcome['make_exit'], 2)
            self.assertEqual((dest / 'make-exit').read_text(), '2\n')
            result = json.loads((dest / 'policy.json').read_text())
            self.assertTrue(result['accepted']); self.assertEqual(result['pass_count'], 50002)
            for name in ('gcc.sum', 'g++.sum', 'libstdc++.sum'):
                self.assertEqual((dest / 'summaries' / name).read_bytes(), (build / name).read_bytes())
                self.assertEqual(outcome['artifacts_sha256']['summaries/' + name], package_stage.sha(build / name))
            self.assertIn('native/chroot/host acceptance required', outcome['scope'])

    def test_guard_fault_does_not_use_even_complete_pass_summaries(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root, lfs, infra, build = self.fixture(directory)
            def interrupted(argv, log, cwd=None, env=None):
                self.emit(build); log.write_text('space stop')
                raise RuntimeError('Guest free space below 15%')
            with self.guards(lfs, infra), patch.object(guest_tests, 'run_logged', side_effect=interrupted):
                dest, outcome = guest_tests.run_suite('gcc', build)
            self.assertEqual(outcome['result'], 'FAIL'); self.assertIsNone(outcome['make_exit'])
            self.assertIn('below 15%', outcome['errors'][0])
            self.assertFalse((dest / 'policy.json').exists())
            self.assertEqual((dest / 'make-check.log').read_text(), 'space stop')

    def test_new_failure_or_incomplete_suite_cannot_pass(self):
        for failure, unfinished in (('FAIL: new-regression\n', False), (None, True)):
            with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
                root, lfs, infra, build = self.fixture(directory)
                def failed(argv, log, cwd=None, env=None):
                    self.emit(build, failure, unfinished); log.write_text('make exit fixture')
                    raise subprocess.CalledProcessError(2, argv)
                with self.guards(lfs, infra), patch.object(guest_tests, 'run_logged', side_effect=failed):
                    dest, outcome = guest_tests.run_suite('gcc', build)
                self.assertEqual(outcome['result'], 'FAIL')
                self.assertFalse(json.loads((dest / 'policy.json').read_text())['accepted'])

    def test_input_change_vetoes_success_and_keeps_log(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root, lfs, infra, build = self.fixture(directory)
            def changed(argv, log, cwd=None, env=None):
                self.emit(build); log.write_text('completed')
                (build / 'Makefile').write_text('changed during run')
            with self.guards(lfs, infra), patch.object(guest_tests, 'run_logged', side_effect=changed):
                dest, outcome = guest_tests.run_suite('gcc', build)
            self.assertEqual(outcome['result'], 'FAIL')
            self.assertIn('changed during command', outcome['errors'][0])
            self.assertEqual((dest / 'make-check.log').read_text(), 'completed')


class CheckpointTransactionTests(unittest.TestCase):
    def disks(self, root):
        for disk in checkpoint_store.DISKS:
            raw = root / (disk + '.fixture.raw')
            with raw.open('xb') as stream:
                stream.write(('nonzero checkpoint fixture: ' + disk + '\n').encode())
                stream.truncate(2 * 1024**2)
            subprocess.run(['qemu-img', 'convert', '-f', 'raw', '-O', 'qcow2', raw, root / (disk + '-active.qcow2')],
                           check=True, capture_output=True)
        return {disk: package_stage.sha(root / (disk + '-active.qcow2')) for disk in checkpoint_store.DISKS}

    def create(self, root):
        return checkpoint_store.create(root, 'prepared', '1' * 64, '2' * 64, None, lambda: None, lambda: None)

    def test_product_stage_and_smoke_names_cannot_bypass_acceptance(self):
        with patch.object(ctl, 'pid', return_value=None), patch.object(checkpoint_store, 'create') as create:
            for name in ctl.STAGES:
                with self.assertRaisesRegex(RuntimeError, 'verified guest artifacts'):
                    ctl.checkpoint(name)
            with patch.object(ctl, 'phase1_acceptance_guard', side_effect=RuntimeError('DB gate closed')):
                with self.assertRaisesRegex(RuntimeError, 'DB gate closed'):
                    ctl.checkpoint('smoke')
            create.assert_not_called()

    def test_both_images_are_checked_before_first_mutation(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory); original = self.disks(root)
            lfs = root / 'lfs-active.qcow2'; lfs.write_bytes(b'not a qcow2')
            original['lfs'] = package_stage.sha(lfs)
            with self.assertRaises((RuntimeError, subprocess.CalledProcessError)):
                self.create(root)
            self.assertFalse((root / 'checkpoint-prepared').exists())
            self.assertEqual(original, {disk: package_stage.sha(root / (disk + '-active.qcow2')) for disk in original})

    def test_real_two_disk_backing_checkpoint_and_no_overwrite(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory); original = self.disks(root)
            dest = self.create(root)
            record = json.loads((dest / 'checkpoint.json').read_text())
            self.assertEqual(json.loads((dest / 'transaction.json').read_text())['status'], 'COMPLETE')
            for disk in original:
                saved, active = dest / (disk + '.qcow2'), root / (disk + '-active.qcow2')
                self.assertEqual(package_stage.sha(saved), original[disk])
                self.assertEqual(saved.stat().st_nlink, 1)
                self.assertEqual(stat.S_IMODE(saved.stat().st_mode), 0o400)
                self.assertEqual(record['backing_chains'][disk][0], {'path': str(saved), 'sha256': original[disk]})
                info = json.loads(subprocess.check_output(['qemu-img', 'info', '--output=json', active], text=True))
                self.assertEqual(info['full-backing-filename'], str(saved))
                subprocess.run(['qemu-img', 'check', active], check=True, capture_output=True)
                decoded = root / (disk + '.decoded.raw')
                subprocess.run(['qemu-img', 'convert', '-f', 'qcow2', '-O', 'raw', active, decoded],
                               check=True, capture_output=True)
                self.assertEqual(package_stage.sha(decoded), package_stage.sha(root / (disk + '.fixture.raw')))
            with self.assertRaisesRegex(RuntimeError, 'exists'):
                self.create(root)

    def test_second_overlay_failure_rolls_back_original_pair(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory); original = self.disks(root); real = checkpoint_store.command
            def fail_second(argv):
                if argv[:2] == ['qemu-img', 'create'] and str(argv[-1]).endswith('lfs.overlay.qcow2'):
                    raise OSError('fixture second overlay creation failure')
                return real(argv)
            with patch.object(checkpoint_store, 'command', side_effect=fail_second):
                with self.assertRaisesRegex(OSError, 'second overlay'):
                    self.create(root)
            self.assertFalse((root / 'checkpoint-prepared').exists())
            self.assertEqual(original, {disk: package_stage.sha(root / (disk + '-active.qcow2')) for disk in original})
            for disk in original:
                self.assertEqual((root / (disk + '-active.qcow2')).stat().st_nlink, 1)
            failed = next(root.glob('failed-checkpoint-prepared-*'))
            self.assertEqual(json.loads((failed / 'transaction.json').read_text())['status'], 'ROLLED_BACK')
            checkpoint_store.unfinished(root)

    def test_failure_between_commits_restores_both_original_bytes(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory); original = self.disks(root); real = checkpoint_store.save
            def fail_after_first(path, value):
                if value.get('committed') == ['builder'] and value['status'] == 'COMMITTING':
                    raise OSError('fixture interrupted first commit')
                return real(path, value)
            with patch.object(checkpoint_store, 'save', side_effect=fail_after_first):
                with self.assertRaisesRegex(OSError, 'first commit'):
                    self.create(root)
            self.assertEqual(original, {disk: package_stage.sha(root / (disk + '-active.qcow2')) for disk in original})
            self.assertEqual(json.loads(next(root.glob('failed-checkpoint-*/transaction.json')).read_text())['status'], 'ROLLED_BACK')

    def test_original_hash_drift_preserves_files_and_blocks_launch(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory); self.disks(root); real = checkpoint_store.command
            def drift(argv):
                answer = real(argv)
                if argv[:2] == ['qemu-img', 'create'] and str(argv[-1]).endswith('lfs.overlay.qcow2'):
                    with (root / 'checkpoint-prepared/builder.qcow2').open('ab') as stream:
                        stream.write(b'fixture unexpected hash change')
                return answer
            with patch.object(checkpoint_store, 'command', side_effect=drift):
                with self.assertRaisesRegex(RuntimeError, 'original bytes changed'):
                    self.create(root)
            self.assertEqual(json.loads((root / 'checkpoint-prepared/transaction.json').read_text())['status'], 'FAILED')
            self.assertTrue((root / 'checkpoint-prepared/builder.qcow2').is_file())
            with self.assertRaisesRegex(RuntimeError, 'Incomplete checkpoint'):
                checkpoint_store.unfinished(root)
            with patch.object(ctl, 'VM', root), patch.object(ctl, 'pid', return_value=None), \
                    patch.object(ctl, 'verify_cache') as cache:
                with self.assertRaisesRegex(RuntimeError, 'Incomplete checkpoint'):
                    ctl.launch()
                cache.assert_not_called()

    def test_space_budget_counts_temporary_hardlink_once(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory); data, vm = root / 'data', root / 'vm'; data.mkdir(); vm.mkdir()
            source = data / 'actual'; source.write_bytes(b'allocated fixture\n' * 10000)
            os.link(source, vm / 'temporary-snapshot-alias')
            with patch.object(ctl, 'DATA', data), patch.object(ctl, 'VM', vm):
                self.assertEqual(ctl.space_guard(), source.stat().st_blocks * 512)

    def test_missing_commit_record_is_not_a_legacy_checkpoint(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory); dest = root / 'checkpoint-prepared'; dest.mkdir()
            with self.assertRaisesRegex(RuntimeError, 'without commit record'):
                checkpoint_store.unfinished(root)
            (dest / 'transaction.json').write_text(json.dumps({'status': 'COMPLETE'}))
            with self.assertRaisesRegex(RuntimeError, 'without commit record'):
                checkpoint_store.unfinished(root)


def host_sample_fixture(epoch, monotonic, binding=None, incremental=False):
    args = ['journalctl', '-k', '-b', '--no-pager', '-o', 'json']
    if incremental: args += ['--after-cursor', 'fixture-cursor']
    record = {'time_ns': epoch, 'completed_at_ns': epoch + 10**9,
              'monotonic_ns': monotonic, 'completed_monotonic_ns': monotonic + 10**9,
              'boot_id': host_stage_audit.BOOT.read_text().strip(),
              'errors': [], 'cpufreq_khz': {'policy0': 3600000},
              'throttle_counters': {}, 'throttle_coverage': 'unavailable',
              'meminfo_kib': {'MemAvailable': 16000000, 'MemTotal': 24000000, 'SwapFree': 0},
              'volumes': {path: {'device': i, 'inode': 1, 'free_bytes': 30, 'total_bytes': 100}
                          for i, path in enumerate(('/', '/mnt/alpbahOS-ssd', '/mnt/alpbahOS-data'), 1)},
              'sensors': {'argv': ['sensors', '-j'], 'exit': 0, 'stderr': '',
                          'stdout': json.dumps({'k10temp-pci-fixture': {'Tctl': {'temp1_input': 41.5}}})},
              'cpu_temperatures_c': {'k10temp-pci-fixture/Tctl': 41.5},
              'kernel': {'argv': args, 'exit': 0, 'stderr': '',
                         'stdout': '' if incremental else '{"__CURSOR":"fixture-cursor","MESSAGE":"ordinary"}\n'},
              'kernel_faults': [], 'journal_cursor': 'fixture-cursor'}
    if binding is not None: record['binding'] = binding
    return record


class StabilityAcceptanceTests(unittest.TestCase):
    @contextmanager
    def fixture(self, directory, layered=False):
        base = time.time_ns() - 1300 * 10**9
        with ExitStack() as stack:
            with patch.object(stage_runs.time, 'time_ns', return_value=base):
                context = stack.enter_context(stage_job_fixture(directory, sources_sha256='3' * 64))
            value, run_sha, _ = context
            root = stage_runs.ARTIFACTS / value['run_id']; state = stage_runs.RUNS / value['run_id']
            guest = root / 'guest'; guest.mkdir()
            sources, recipes, summary = StabilityEvidenceTests().fixture(guest)
            shutil.rmtree(guest / 'stage')  # New fixture scratch tree only, not collected evidence.
            summary['run_id'] = value['run_id']; (guest / 'summary.json').write_text(json.dumps(summary))
            binding = {k: value[k] for k in ('run_id', 'stage', 'inputs_sha256', 'sources_sha256', 'boot_id')}
            mono = 10**15
            rows = [host_sample_fixture(base + i * 10**9, mono + i * 10**9, binding, n > 0)
                    for n, i in enumerate([*range(8, 1229, 10), 1231])]
            argv = ['fixture-ssh', 'canonical-stability']
            command = {'argv': argv, 'exit': 0, 'binding': binding, 'sample_interval_seconds': 10,
                       'started_at_ns': base + 10 * 10**9, 'ended_at_ns': base + 1230 * 10**9,
                       'started_monotonic_ns': mono + 10 * 10**9, 'ended_monotonic_ns': mono + 1230 * 10**9}
            stage_runs.write(root / 'command.json', command)
            stage_runs.write(root / 'host-baseline.json', host_sample_fixture(base - 3 * 10**9, mono - 3 * 10**9))
            stage_runs.write(root / 'authorization.json', {**{k: value[k] for k in ('stage', 'mode', 'run_id', 'inputs_sha256', 'sources_sha256', 'boot_id')},
                                                          'oc_confirmed': True, 'authorized_at_ns': base + 2 * 10**9})
            (root / 'stability.log').write_bytes(b'fixture raw command log, no compiler executed')
            (root / 'stability.host.jsonl').write_text(''.join(json.dumps(row) + '\n' for row in rows))
            for phase, offset in (('before', 1), ('after', 1235)):
                with patch.object(stage_runs.time, 'time_ns', return_value=base + offset * 10**9):
                    stage_runs.repository_snapshot(value, phase)
            vm = Path(directory) / 'vm'; vm.mkdir(mode=0o700)
            CheckpointTransactionTests().disks(vm)
            if layered:
                checkpoint_store.create(vm, 'prepared', '1' * 64, '3' * 64, None, lambda: None, lambda: None)
            chains = checkpoint_store.inspect_disks(vm, lambda: None, lambda: None)
            stage_runs.write(root / 'disks-closed.json', {'run_id': value['run_id'], 'time_ns': base + 1234 * 10**9, 'chains': chains})
            proof = stability_evidence.verify_stability_artifacts(guest, sources, '1' * 64, '3' * 64, recipes)
            stage_runs.finish(value, run_sha, [], proof, lambda: None)
            post = stage_runs.after_request(value, run_sha)
            stack.enter_context(patch.object(host_stage_audit, 'verify_pair', return_value={
                'before': {'pristine_rpm': True, 'fixture_only': True}, 'after': {'pristine_rpm': True, 'fixture_only': True}}))
            yield {'value': value, 'run_sha': run_sha, 'root': root, 'state': state,
                   'sources': sources, 'recipes': recipes, 'vm': vm, 'audit_id': post['audit_id'],
                   'argv': argv, 'rows': rows, 'command': command, 'base': base, 'mono': mono}

    def verify(self, fixture):
        return stage_acceptance.verify(fixture['value'], fixture['run_sha'], fixture['audit_id'],
            fixture['sources'], fixture['recipes'], fixture['vm'], fixture['argv'], lambda: None, lambda: None)

    def test_raw_telemetry_guest_packages_and_real_tiny_disks_accept_together(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, self.fixture(directory) as f:
            proof = self.verify(f)
            self.assertEqual(proof['result'], 'PASS')
            self.assertEqual(proof['telemetry']['throttle_coverage'], 'unavailable')
            self.assertGreater(proof['telemetry']['samples'], 100)
            self.assertEqual(proof['guest']['db_sha256'][0], proof['guest']['db_sha256'][1])
            self.assertEqual(set(proof['closed_disk_chains']), {'builder', 'lfs'})
            self.assertFalse((f['state'] / 'acceptance.json').exists())  # Verifier itself writes nothing.

    def test_raw_faults_cannot_be_hidden_by_empty_errors(self):
        for change in ('kernel', 'sensor', 'disk', 'cursor', 'clock', 'throttle'):
            row = host_sample_fixture(10**12, 10**12)
            if change == 'kernel': row['kernel']['stdout'] = '{"__CURSOR":"fixture-cursor","MESSAGE":"I/O error"}\n'
            elif change == 'sensor': row['sensors']['exit'] = 1
            elif change == 'disk': row['volumes']['/']['free_bytes'] = 14
            elif change == 'cursor': row['journal_cursor'] = 'wrong cursor'
            elif change == 'clock': row['completed_monotonic_ns'] = row['monotonic_ns'] - 1
            elif change == 'throttle': row['throttle_coverage'] = 'counters present'
            with self.assertRaises(RuntimeError): host_monitor.validate_sample(row)

    def test_missing_interval_other_run_or_unbracketed_command_rejects(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, self.fixture(directory) as f:
            binding = f['command']['binding']
            for change in ('gap', 'run', 'bracket'):
                rows = json.loads(json.dumps(f['rows']))
                if change == 'gap': del rows[10:20]
                elif change == 'run': rows[5]['binding']['run_id'] = 'f' * 32
                elif change == 'bracket': rows.pop()
                raw = '\n'.join(json.dumps(row) for row in rows)
                with self.assertRaises(RuntimeError):
                    host_monitor.verify_recording(raw, f['command'], binding, f['base'], time.time_ns())

    def test_changed_closed_disk_or_wrong_post_id_has_no_acceptance(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, self.fixture(directory) as f:
            with self.assertRaises(FileNotFoundError):
                stage_acceptance.verify(f['value'], f['run_sha'], 'f' * 32, f['sources'], f['recipes'],
                    f['vm'], f['argv'], lambda: None, lambda: None)
            subprocess.run(['qemu-io', '-f', 'qcow2', '-c', 'write -P 17 65536 512', f['vm'] / 'lfs-active.qcow2'],
                           check=True, capture_output=True)
            with self.assertRaisesRegex(RuntimeError, 'qcow2/backing bytes differ'):
                self.verify(f)
            self.assertFalse((f['state'] / 'acceptance.json').exists())

    def test_root_post_must_bind_terminal_outcome_bytes(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, self.fixture(directory) as f:
            outcome = f['state'] / 'outcome.json'; value = json.loads(outcome.read_text())
            value['scope'] = 'changed after root post request'; outcome.write_text(json.dumps(value))
            post_path = f['state'] / ('after-' + f['audit_id'] + '.json'); post = json.loads(post_path.read_text())
            post['outcome_sha256'] = host_stage_audit.digest(outcome.read_bytes()); post_path.write_text(json.dumps(post))
            with self.assertRaisesRegex(RuntimeError, 'Root post audit identity changed'): self.verify(f)

    def test_live_writers_or_raw_artifact_change_stop_before_receipt(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, self.fixture(directory) as f:
            with self.assertRaisesRegex(RuntimeError, 'live writer'):
                stage_acceptance.verify(f['value'], f['run_sha'], f['audit_id'], f['sources'], f['recipes'],
                    f['vm'], f['argv'], lambda: (_ for _ in ()).throw(RuntimeError('live writer')), lambda: None)
            (f['root'] / 'guest/db-repro-b.json').write_bytes(b'changed raw DB')
            with self.assertRaisesRegex(RuntimeError, 'collected bytes changed'): self.verify(f)

    def test_controller_checkpoint_revalidates_proof_and_actual_preflight_disk_hashes(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, self.fixture(directory) as f, \
                patch.object(ctl, 'VM', f['vm']), patch.object(ctl, 'pid', return_value=None), \
                patch.object(ctl, 'space_guard'), patch.object(ctl, 'stability_proof', side_effect=lambda *args: self.verify(f)):
            proof = self.verify(f)
            stage_runs.write(f['state'] / 'acceptance.json', {'evidence': proof, 'accepted_at_ns': time.time_ns()})
            saved = ctl.checkpoint('stability', f['value']['run_id'], f['audit_id'])
            record = json.loads((saved / 'checkpoint.json').read_text())
            self.assertEqual(record['acceptance'], proof)
            for disk in ('builder', 'lfs'):
                self.assertEqual(checkpoint_store.sha(saved / (disk + '.qcow2')), proof['closed_disk_chains'][disk][0]['sha256'])

    def test_generic_pass_receipt_or_drift_after_acceptance_cannot_mutate_disks(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, self.fixture(directory) as f, \
                patch.object(ctl, 'VM', f['vm']), patch.object(ctl, 'pid', return_value=None), \
                patch.object(ctl, 'space_guard'), patch.object(ctl, 'stability_proof', side_effect=lambda *args: self.verify(f)):
            stage_runs.write(f['state'] / 'acceptance.json', {'result': 'PASS'})
            with self.assertRaisesRegex(RuntimeError, 'receipt differs'):
                ctl.checkpoint('stability', f['value']['run_id'], f['audit_id'])
            proof = self.verify(f)
            proof['closed_disk_chains']['lfs'][0]['sha256'] = 'f' * 64
            before = {disk: checkpoint_store.sha(f['vm'] / (disk + '-active.qcow2')) for disk in ('builder', 'lfs')}
            with self.assertRaisesRegex(RuntimeError, 'accepted stage'):
                checkpoint_store.create(f['vm'], 'stability', '1' * 64, '3' * 64, proof, lambda: None, lambda: None)
            self.assertFalse((f['vm'] / 'checkpoint-stability').exists())
            self.assertEqual(before, {disk: checkpoint_store.sha(f['vm'] / (disk + '-active.qcow2')) for disk in ('builder', 'lfs')})


class ToolchainHandoffTests(unittest.TestCase):
    @contextmanager
    def fixture(self, directory, layered=False):
        helper = StabilityAcceptanceTests()
        with helper.fixture(directory, layered=layered) as f:
            proof = helper.verify(f)
            stage_runs.write(f['state'] / 'acceptance.json', {'evidence': proof, 'accepted_at_ns': time.time_ns()})
            saved = checkpoint_store.create(f['vm'], 'stability', '1' * 64, '3' * 64,
                                             proof, lambda: None, lambda: None)
            f.update(proof=proof, saved=saved)
            yield f

    def prepare(self, f):
        return toolchain_handoff.prepare(f['value'], f['run_sha'], f['audit_id'], f['sources'],
            f['recipes'], f['vm'], f['argv'], lambda: None, lambda: None, 'a' * 32)

    def test_relocated_snapshot_revalidates_full_proof_and_binds_transport(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, self.fixture(directory, layered=True) as f:
            original = f['proof']['closed_disk_chains']
            proof = stage_acceptance.verify(f['value'], f['run_sha'], f['audit_id'], f['sources'],
                f['recipes'], f['vm'], f['argv'], lambda: None, lambda: None, checkpointed=True)
            self.assertEqual(proof, f['proof'])
            inspected = checkpoint_store.inspect_accepted_checkpoint(f['vm'], lambda: None, lambda: None)
            self.assertEqual(inspected['closed_disk_chains'], original)
            for disk in checkpoint_store.DISKS:
                self.assertEqual(inspected['saved_disk_chains'][disk][0]['path'], str(f['saved'] / (disk + '.qcow2')))
            before = {disk: checkpoint_store.sha(f['vm'] / (disk + '-active.qcow2')) for disk in checkpoint_store.DISKS}
            parent = self.prepare(f)
            guest_boot = '22222222-2222-4222-8222-222222222222'
            job = 'a' * 32
            raw = toolchain_handoff.bind_guest(parent, hashlib.sha256(parent).hexdigest(), job, guest_boot)
            inputs = {k: f['value'][k] for k in ('inputs_sha256', 'sources_sha256')}
            auth = {**inputs, 'oc_confirmed': True, 'mode': 'multilib-m32', 'stage': 'toolchain',
                    'run_id': job, 'boot_id': f['value']['boot_id'], 'guest_boot_id': guest_boot,
                    'handoff_sha256': hashlib.sha256(raw).hexdigest()}
            capsule = handoff_binding.validate(raw, auth, inputs, guest_boot)
            self.assertEqual(capsule['parent_run_id'], f['value']['run_id'])
            self.assertEqual(capsule['parent_receipt_sha256'], checkpoint_store.sha(f['state'] / 'acceptance.json'))
            self.assertEqual(before, {disk: checkpoint_store.sha(f['vm'] / (disk + '-active.qcow2')) for disk in checkpoint_store.DISKS})

    def test_any_new_child_writes_block_stale_parent_handoff(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, self.fixture(directory) as f:
            subprocess.run(['qemu-io', '-f', 'qcow2', '-c', 'write -P 17 65536 512', f['vm'] / 'lfs-active.qcow2'],
                           check=True, capture_output=True)
            with self.assertRaisesRegex(RuntimeError, 'Fresh active overlay changed'): self.prepare(f)
            self.assertTrue((f['saved'] / 'checkpoint.json').is_file())

    def test_saved_disk_byte_change_is_not_a_filename_relocation(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, self.fixture(directory) as f:
            saved = f['saved'] / 'lfs.qcow2'; saved.chmod(0o600)
            subprocess.run(['qemu-io', '-f', 'qcow2', '-c', 'write -P 19 65536 512', saved], check=True, capture_output=True)
            saved.chmod(0o400)
            with self.assertRaisesRegex(RuntimeError, 'saved/backing disk bytes differ'): self.prepare(f)

    def test_older_backing_bytes_are_also_rehashed(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, self.fixture(directory, layered=True) as f:
            older = f['vm'] / 'checkpoint-prepared/builder.qcow2'; older.chmod(0o600)
            subprocess.run(['qemu-io', '-f', 'qcow2', '-c', 'write -P 23 65536 512', older], check=True, capture_output=True)
            older.chmod(0o400)
            with self.assertRaisesRegex(RuntimeError, 'saved/backing disk bytes differ'): self.prepare(f)

    def test_missing_fresh_pins_or_transaction_have_no_legacy_shortcut(self):
        for missing in ('fresh-pins', 'transaction'):
            with self.subTest(missing=missing), tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, self.fixture(directory) as f:
                if missing == 'transaction': (f['saved'] / 'transaction.json').unlink()
                else:
                    for name in ('checkpoint.json', 'transaction.json'):
                        path = f['saved'] / name; record = json.loads(path.read_text()); record.pop('active_overlays')
                        path.write_text(json.dumps(record))
                with self.assertRaises((RuntimeError, FileNotFoundError)): self.prepare(f)

    def test_generic_receipt_changed_guest_artifacts_or_current_boot_block_parent(self):
        for change in ('generic', 'artifacts', 'boot'):
            with self.subTest(change=change), tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, self.fixture(directory) as f:
                if change == 'generic': (f['state'] / 'acceptance.json').write_text('{"result":"PASS"}')
                elif change == 'artifacts': (f['root'] / 'guest/db-repro-b.json').write_bytes(b'changed')
                boot = Path(directory) / 'other-boot'; boot.write_text('33333333-3333-4333-8333-333333333333')
                with patch.object(host_stage_audit, 'BOOT', boot) if change == 'boot' else ExitStack():
                    with self.assertRaises(RuntimeError): self.prepare(f)

    def test_parent_binding_rejects_host_reboot_same_job_or_host_as_guest(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, self.fixture(directory) as f:
            parent = self.prepare(f)
            for job, guest in ((f['value']['run_id'], '22222222-2222-4222-8222-222222222222'),
                               ('a' * 32, f['value']['boot_id'])):
                with self.assertRaises(RuntimeError):
                    toolchain_handoff.bind_guest(parent, hashlib.sha256(parent).hexdigest(), job, guest)
            with self.assertRaises(RuntimeError):
                toolchain_handoff.bind_guest(parent + b' ', hashlib.sha256(parent).hexdigest(), 'a' * 32,
                                              '22222222-2222-4222-8222-222222222222')
            boot = Path(directory) / 'other-boot'; boot.write_text('33333333-3333-4333-8333-333333333333')
            with patch.object(host_stage_audit, 'BOOT', boot):
                with self.assertRaises(RuntimeError):
                    toolchain_handoff.bind_guest(parent, hashlib.sha256(parent).hexdigest(), 'a' * 32,
                                                  '22222222-2222-4222-8222-222222222222')

    def test_guest_guard_rejects_generic_pass_raw_drift_and_replay_bindings(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, patch.object(package_stage, 'INFRA', Path(directory)), \
                patch.object(package_stage, 'REPO', REPO), \
                patch.object(package_stage, 'run') as run:
            root = Path(directory)
            inputs = {'inputs_sha256': '1' * 64, 'sources_sha256': package_stage.sha(REPO / 'manifests/infra-sources.json')}
            (root / 'inputs.json').write_text(json.dumps(inputs))
            receipt, auth = handoff_fixture(root, inputs)
            recipe = json.loads((REPO / 'recipes/toolchain/gcc-pass1.json').read_text())
            package_stage.heavy_recipe_guard(recipe)
            good = (root / 'stability-acceptance.json').read_bytes()
            for change in ('generic', 'raw', 'run', 'host', 'guest', 'source', 'disk'):
                with self.subTest(change=change):
                    bad_auth = dict(auth); bad_receipt = json.loads(good)
                    if change == 'generic': bad_receipt = {**inputs, 'mode': 'multilib-m32', 'result': 'PASS'}
                    elif change == 'run': bad_auth['run_id'] = 'f' * 32
                    elif change == 'host': bad_auth['boot_id'] = '33333333-3333-4333-8333-333333333333'
                    elif change == 'guest': bad_receipt['guest_boot_id'] = '22222222-2222-4222-8222-222222222222'
                    elif change == 'source': bad_auth['sources_sha256'] = 'f' * 64
                    elif change == 'disk': bad_receipt['active_overlay_sha256'] = {'builder': 'd' * 64}
                    raw = json.dumps(bad_receipt).encode() if change != 'raw' else good + b' '
                    if change != 'raw': bad_auth['handoff_sha256'] = hashlib.sha256(raw).hexdigest()
                    (root / 'stability-acceptance.json').write_bytes(raw)
                    (root / 'phase2-authorization.json').write_text(json.dumps(bad_auth))
                    with self.assertRaises(RuntimeError): package_stage.build_staged(recipe, 'fixture', root)
                    run.assert_not_called()

    def test_controller_parent_keeps_current_phase1_gate_before_disk_or_vm(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, patch.object(ctl, 'ARTIFACTS', Path(directory)), \
                patch.object(ctl, 'launch') as launch, patch.object(toolchain_handoff, 'prepare') as prepare:
            with self.assertRaisesRegex(RuntimeError, 'resolve Alp DB reproducibility'):
                ctl.toolchain_parent('a' * 32, 'b' * 32, 'c' * 32)
            prepare.assert_not_called(); launch.assert_not_called()


class GuestHandoffTests(unittest.TestCase):
    @contextmanager
    def fixture(self, directory):
        root = Path(directory); infra = root / 'infra'; infra.mkdir(mode=0o700)
        repo = root / 'repo'; (repo / 'manifests').mkdir(parents=True)
        source = repo / 'manifests/infra-sources.json'; shutil.copyfile(REPO / 'manifests/infra-sources.json', source)
        inputs = {'inputs_sha256': '1' * 64, 'sources_sha256': package_stage.sha(source)}
        (infra / 'inputs.json').write_text(json.dumps(inputs))
        receipt, auth = handoff_fixture(infra, inputs)
        capsule = (infra / 'stability-acceptance.json').read_text()
        # Existing old transport cannot authorize the newly delivered capsule.
        (infra / 'stability-acceptance.json').write_text('{"result":"PASS"}')
        (infra / 'phase2-authorization.json').write_text(json.dumps({**auth, 'run_id': 'f' * 32, 'handoff_sha256': '0' * 64}))
        raw = json.dumps({'capsule': capsule, 'authorization': auth}).encode()
        with patch.object(guest_handoff, 'INFRA', infra), patch.object(guest_handoff, 'REPO', repo), \
                patch.object(guest_handoff, 'guest_install_guard') as guard, \
                patch.object(guest_handoff.os, 'geteuid', return_value=0):
            yield {'root': root, 'infra': infra, 'repo': repo, 'raw': raw, 'receipt': receipt, 'auth': auth, 'guard': guard}

    def test_unprivileged_host_cannot_deliver_or_create_records(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, patch.object(guest_handoff, 'INFRA', Path(directory)), \
                patch.object(guest_handoff, 'guest_install_guard') as guard:
            with self.assertRaisesRegex(RuntimeError, 'host invocation refused'): guest_handoff.install(b'{}')
            guard.assert_not_called(); self.assertEqual(list(Path(directory).iterdir()), [])

    def test_exact_raw_delivery_is_private_single_use_and_never_package_acceptance(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, self.fixture(directory) as f:
            response = guest_handoff.install(f['raw'])
            self.assertEqual(response['result'], 'HANDOFF_BOUND')
            self.assertEqual(response['handoff_sha256'], f['auth']['handoff_sha256'])
            for path in (f['infra'] / 'phase2-authorization.json', f['infra'] / 'stability-acceptance.json'):
                self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
            with self.assertRaises(FileExistsError): guest_handoff.install(f['raw'])
            self.assertTrue((f['infra'] / 'handoffs' / ('a' * 32 + '.completed.json')).is_file())
            with patch.object(package_stage, 'INFRA', f['infra']), patch.object(package_stage, 'REPO', f['repo']):
                package_stage.heavy_recipe_guard({'phase': 'toolchain', 'abi': 'multilib-m32'})
                with self.assertRaisesRegex(RuntimeError, 'input mismatch'):
                    package_stage.heavy_recipe_guard({'phase': 'stability', 'abi': 'multilib-m32'})

    def test_generic_large_or_wrong_guest_payload_fails_before_attempt_or_authority(self):
        for change in ('generic', 'large', 'guest', 'source'):
            with self.subTest(change=change), tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, self.fixture(directory) as f:
                payload = json.loads(f['raw'])
                if change == 'generic': payload['capsule'] = '{"result":"PASS"}'
                elif change == 'guest':
                    capsule = json.loads(payload['capsule']); capsule['guest_boot_id'] = '22222222-2222-4222-8222-222222222222'
                    payload['capsule'] = json.dumps(capsule)
                    payload['authorization']['handoff_sha256'] = hashlib.sha256(payload['capsule'].encode()).hexdigest()
                elif change == 'source': (f['repo'] / 'manifests/infra-sources.json').write_bytes(b'changed manifest')
                raw = json.dumps(payload).encode() if change != 'large' else b'x' * (guest_handoff.MAX_BYTES + 1)
                before = (f['infra'] / 'phase2-authorization.json').read_bytes()
                with self.assertRaises(RuntimeError): guest_handoff.install(raw)
                self.assertEqual(before, (f['infra'] / 'phase2-authorization.json').read_bytes())
                self.assertFalse((f['infra'] / 'handoffs').exists())

    def test_interrupted_pair_retains_attempt_and_cannot_replay_or_authorize(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, self.fixture(directory) as f:
            original = guest_handoff.replace
            def interrupted(path, raw):
                if path.name == 'phase2-authorization.json': raise OSError('fixture authorization rename failure')
                return original(path, raw)
            with patch.object(guest_handoff, 'replace', side_effect=interrupted):
                with self.assertRaisesRegex(OSError, 'rename failure'): guest_handoff.install(f['raw'])
            with self.assertRaises(FileExistsError): guest_handoff.install(f['raw'])
            self.assertFalse((f['infra'] / 'handoffs' / ('a' * 32 + '.completed.json')).exists())
            with patch.object(package_stage, 'INFRA', f['infra']), patch.object(package_stage, 'REPO', f['repo']):
                with self.assertRaises(RuntimeError): package_stage.heavy_recipe_guard({'phase': 'toolchain', 'abi': 'multilib-m32'})

    def test_existing_authority_alias_is_rejected_without_touching_target(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, self.fixture(directory) as f:
            path = f['infra'] / 'phase2-authorization.json'; path.unlink()
            target = f['root'] / 'untouched'; target.write_bytes(b'preserved target')
            path.symlink_to(target)
            with self.assertRaisesRegex(RuntimeError, 'alias/type/owner'): guest_handoff.install(f['raw'])
            self.assertEqual(target.read_bytes(), b'preserved target'); self.assertFalse((f['infra'] / 'handoffs').exists())


class BaseStageAuthorizationTests(unittest.TestCase):
    @contextmanager
    def fixture(self, directory):
        root = Path(directory); infra = root / 'infra'; infra.mkdir(mode=0o700)
        repo = root / 'repo'; (repo / 'manifests').mkdir(parents=True)
        source = repo / 'manifests/infra-sources.json'
        shutil.copyfile(REPO / 'manifests/infra-sources.json', source)
        inputs = {'inputs_sha256': '1' * 64, 'sources_sha256': package_stage.sha(source)}
        (infra / 'inputs.json').write_text(json.dumps(inputs))
        _, phase2 = handoff_fixture(infra, inputs)
        toolchain = {'schema': 'alpbahOS.toolchain-acceptance/v1', 'result': 'PASS',
            'stage': 'toolchain', 'mode': 'multilib-m32', 'run_id': 'f' * 32,
            'after_audit_id': 'e' * 32, 'inputs_sha256': inputs['inputs_sha256'],
            'sources_sha256': inputs['sources_sha256'], 'proof_sha256': 'c' * 64,
            'checkpoint_sha256': 'd' * 64}
        (infra / 'toolchain-acceptance.json').write_text(json.dumps(toolchain))
        base = {'schema': 'alpbahOS.base-authorization/v1', 'result': 'AUTHORIZED',
            'stage': 'base', 'mode': 'multilib-m32', 'oc_confirmed': True,
            'run_id': 'a' * 32, 'guest_boot_id': '22222222-2222-4222-8222-222222222222',
            'inputs_sha256': inputs['inputs_sha256'], 'sources_sha256': inputs['sources_sha256'],
            'phase2_authorization_sha256': package_stage.sha(infra / 'phase2-authorization.json'),
            'stability_acceptance_sha256': package_stage.sha(infra / 'stability-acceptance.json'),
            'toolchain_acceptance_sha256': package_stage.sha(infra / 'toolchain-acceptance.json'),
            'authorized_at_ns': 1234567890}
        (infra / 'base-authorization.json').write_text(json.dumps(base))
        with patch.object(package_stage, 'INFRA', infra), patch.object(package_stage, 'REPO', repo), \
                patch.object(package_install, 'guest_install_guard') as guest_guard:
            yield {'infra': infra, 'repo': repo, 'inputs': inputs, 'base': base,
                   'phase2': phase2, 'guest_guard': guest_guard}

    def test_base_stage_requires_live_guest_and_all_pinned_acceptances(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, self.fixture(directory) as f:
            package_stage.base_stage_authorization_guard({'phase': 'base', 'abi': 'multilib-m32'})
            f['guest_guard'].assert_called_once_with(package_stage.LFS, package_stage.LFS / 'results/base')

    def test_base_stage_rejects_changed_toolchain_acceptance_and_missing_authorization(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, self.fixture(directory) as f:
            path = f['infra'] / 'toolchain-acceptance.json'
            path.write_bytes(path.read_bytes() + b' ')
            with self.assertRaisesRegex(RuntimeError, 'acceptance binding mismatch'):
                package_stage.base_stage_authorization_guard({'phase': 'base', 'abi': 'multilib-m32'})
            (f['infra'] / 'base-authorization.json').unlink()
            with self.assertRaisesRegex(RuntimeError, 'need OC, stability, toolchain and base-stage'):
                package_stage.base_stage_authorization_guard({'phase': 'base', 'abi': 'multilib-m32'})


class ToolchainSessionTests(unittest.TestCase):
    @contextmanager
    def fixture(self, directory):
        with ToolchainHandoffTests().fixture(directory) as f:
            prepared = stage_runs.prepare_toolchain('multilib-m32', '1' * 64, '3' * 64, '3' * 64,
                f['value'], f['run_sha'], f['audit_id'], f['sources'], f['recipes'], f['vm'], f['argv'], lambda: None, lambda: None)
            context = stage_runs.load(prepared['run_id'], 'multilib-m32', '1' * 64, '3' * 64, '3' * 64, stage='toolchain')
            f.update(job=context, job_state=stage_runs.RUNS / prepared['run_id'], job_root=stage_runs.ARTIFACTS / prepared['run_id'])
            live = {'pid': None}; calls = []
            def launch(**kwargs): calls.append(('launch', kwargs)); live['pid'] = 987654321
            def stop(): calls.append(('stop', None)); live['pid'] = None
            def execute(argv, **kwargs):
                calls.append(('transport', argv))
                if argv[-1] == 'cat /proc/sys/kernel/random/boot_id':
                    return subprocess.CompletedProcess(argv, 0, '22222222-2222-4222-8222-222222222222\n', '')
                payload = json.loads(kwargs['input']); auth = payload['authorization']; capsule = json.loads(payload['capsule'])
                response = {'schema': 'alpbahOS.guest-handoff-response/v1', 'result': 'HANDOFF_BOUND',
                    'run_id': auth['run_id'], 'parent_run_id': capsule['parent_run_id'], 'guest_boot_id': auth['guest_boot_id'],
                    'host_boot_id': auth['boot_id'], 'inputs_sha256': auth['inputs_sha256'], 'sources_sha256': auth['sources_sha256'],
                    'handoff_sha256': hashlib.sha256(payload['capsule'].encode()).hexdigest(),
                    'authorization_sha256': hashlib.sha256(guest_handoff.encoded(auth)).hexdigest()}
                return subprocess.CompletedProcess(argv, 0, json.dumps(response).encode(), b'')
            with ExitStack() as stack:
                for name, replacement in (('VM', f['vm']), ('current_stage_run', lambda *a, **k: context),
                        ('stability_context', lambda *a: (f['value'], f['run_sha'], f['recipes'])),
                        ('stability_command', lambda: f['argv']),
                        ('pid', lambda: live['pid']), ('manifest', lambda: f['sources']), ('inputs_digest', lambda: '1' * 64),
                        ('verify_cache', lambda: None), ('verify_signatures', lambda: None), ('space_guard', lambda: None),
                        ('sample', lambda: host_sample_fixture(time.time_ns() - 10**9, time.monotonic_ns() - 10**9)),
                        ('launch', launch), ('sync', lambda: calls.append(('sync', None))), ('stop', stop), ('run', execute)):
                    stack.enter_context(patch.object(ctl, name, replacement))
                f.update(live=live, calls=calls, execute=execute)
                yield f

    def test_toolchain_request_has_exact_parent_new_nonce_and_no_vm_or_start(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, self.fixture(directory) as f:
            value, checksum, request_raw = f['job']
            self.assertEqual(value['stage'], 'toolchain'); self.assertNotEqual(value['run_id'], f['value']['run_id'])
            self.assertEqual(value['parent']['run_id'], f['value']['run_id'])
            self.assertEqual(value['parent']['sha256'], hashlib.sha256((f['job_state'] / 'parent.json').read_bytes()).hexdigest())
            self.assertEqual(json.loads(request_raw)['stage'], 'toolchain')
            self.assertFalse((f['job_state'] / 'started.json').exists()); self.assertEqual(f['calls'], [])
            with self.assertRaises(RuntimeError): stage_runs.load(value['run_id'], 'multilib-m32', '1' * 64, '3' * 64, '3' * 64)

    def test_missing_oc_or_current_phase1_cannot_prepare_or_open_vm(self):
        with patch.object(ctl, 'launch') as launch:
            with self.assertRaisesRegex(RuntimeError, 'explicit OC-complete'):
                with ctl.toolchain_handoff_session('multilib-m32', False, 'a' * 32): pass
            with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, patch.object(ctl, 'ARTIFACTS', Path(directory)), \
                    patch.object(ctl, 'pid', return_value=None):
                with self.assertRaisesRegex(RuntimeError, 'resolve Alp DB reproducibility'):
                    with ctl.toolchain_handoff_session('multilib-m32', True, 'a' * 32): pass
            launch.assert_not_called()

    def test_parent_raw_drift_or_child_write_blocks_session_before_launch(self):
        for change in ('raw', 'child'):
            with self.subTest(change=change), tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, self.fixture(directory) as f:
                if change == 'raw':
                    path = f['job_state'] / 'parent.json'; path.write_bytes(path.read_bytes() + b' ')
                else:
                    subprocess.run(['qemu-io', '-f', 'qcow2', '-c', 'write -P 31 65536 512', f['vm'] / 'lfs-active.qcow2'], check=True, capture_output=True)
                with self.assertRaisesRegex(RuntimeError, 'raw parent pin' if change == 'raw' else 'Fresh active overlay changed'):
                    with ctl.toolchain_handoff_session('multilib-m32', True, f['job'][0]['run_id']): pass
                self.assertFalse(any(row[0] == 'launch' for row in f['calls']))
                self.assertFalse((f['job_state'] / 'started.json').exists())

    def test_real_missing_root_before_certificate_never_launches_or_transfers(self):
        real_verify = host_stage_audit.verify
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, self.fixture(directory) as f, \
                patch.object(host_stage_audit, 'verify', side_effect=real_verify):
            with self.assertRaises((RuntimeError, FileNotFoundError)):
                with ctl.toolchain_handoff_session('multilib-m32', True, f['job'][0]['run_id']): pass
            self.assertFalse(any(row[0] in ('launch', 'transport') for row in f['calls']))
            self.assertFalse((f['job_state'] / 'started.json').exists())

    def test_bound_boot_transfer_closes_and_fails_without_verified_guest_bytes(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, self.fixture(directory) as f:
            with self.assertRaisesRegex(RuntimeError, 'guest execution/artifact verification absent'):
                with ctl.toolchain_handoff_session('multilib-m32', True, f['job'][0]['run_id']) as context:
                    self.assertEqual(context['response']['result'], 'HANDOFF_BOUND')
                    self.assertIsNotNone(f['live']['pid'])
            self.assertIsNone(f['live']['pid'])
            _, outcome = stage_runs.read(f['job_state'] / 'outcome.json')
            self.assertEqual(outcome['result'], 'FAIL'); self.assertIsNone(outcome['guest_artifact_evidence'])
            self.assertTrue(any('execution/artifact verification absent' in fault for fault in outcome['errors']))
            with self.assertRaises(RuntimeError): stage_runs.after_request(f['job'][0], f['job'][1])
            self.assertEqual([c[1][-1] for c in f['calls'] if c[0] == 'transport'],
                ['cat /proc/sys/kernel/random/boot_id', 'bash /opt/alp-infra/scripts/infra/guest-handoff.sh'])

    def test_bound_boot_transfer_requires_verified_guest_bytes_before_post_request(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, self.fixture(directory) as f:
            run_id = f['job'][0]['run_id']
            with ctl.toolchain_handoff_session('multilib-m32', True, run_id) as context:
                context['guest_artifact_evidence'] = {
                    'schema': 'alpbahOS.toolchain-guest-evidence/v1', 'result': 'VERIFIED_GUEST_BYTES',
                    'run_id': run_id, 'guest_boot_id': '22222222-2222-4222-8222-222222222222'}
            self.assertIsNone(f['live']['pid'])
            _, outcome = stage_runs.read(f['job_state'] / 'outcome.json')
            self.assertEqual(outcome['result'], 'PENDING_PRIVILEGED_POST')
            self.assertEqual(outcome['guest_artifact_evidence']['result'], 'VERIFIED_GUEST_BYTES')
            self.assertEqual(context['post_request']['run_id'], run_id)
            self.assertTrue(Path(context['post_request']['request']).is_file())

    def test_toolchain_run_does_not_open_vm_without_current_phase1_acceptance(self):
        with patch.object(ctl, 'phase1_acceptance_guard', side_effect=RuntimeError('Phase 1 acceptance absent')) as guard, \
                patch.object(ctl, 'launch') as launch:
            with self.assertRaisesRegex(RuntimeError, 'Phase 1 acceptance absent'):
                ctl.run_toolchain('multilib-m32', True, 'a' * 32)
            guard.assert_called_once_with()
            launch.assert_not_called()

    def test_changed_inputs_wrong_response_or_consumer_failure_stops_and_preserves(self):
        for change in ('inputs', 'response', 'consumer'):
            with self.subTest(change=change), tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, self.fixture(directory) as f:
                def execute(argv, **kwargs):
                    result = f['execute'](argv, **kwargs)
                    if change == 'response' and argv[-1].endswith('guest-handoff.sh'):
                        value = json.loads(result.stdout); value['run_id'] = 'f' * 32; result.stdout = json.dumps(value).encode()
                    return result
                def sync():
                    if change == 'inputs': ctl.inputs_digest = lambda: 'f' * 64
                with patch.object(ctl, 'run', side_effect=execute), patch.object(ctl, 'sync', side_effect=sync):
                    with self.assertRaises(RuntimeError):
                        with ctl.toolchain_handoff_session('multilib-m32', True, f['job'][0]['run_id']):
                            raise RuntimeError('fixture consumer failure')
                self.assertIsNone(f['live']['pid'])
                _, outcome = stage_runs.read(f['job_state'] / 'outcome.json'); self.assertEqual(outcome['result'], 'FAIL')
                self.assertNotEqual(outcome['errors'], [])


class StageRunTests(unittest.TestCase):
    def test_request_and_started_state_are_private_single_use(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, stage_job_fixture(directory) as context:
            value, run_sha, request = context
            root = stage_runs.RUNS / value['run_id']
            self.assertEqual(stat.S_IMODE(root.stat().st_mode), 0o700)
            self.assertEqual(stat.S_IMODE((root / 'run.json').stat().st_mode), 0o600)
            stage_runs.execution_guard(value, run_sha)
            with self.assertRaisesRegex(RuntimeError, 'already started'):
                stage_runs.begin(value, run_sha, request)
            self.assertFalse((root / 'outcome.json').exists())

    def test_missing_real_root_before_stops_prior_to_start(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, stage_job_fixture(directory, started=False, audited=False) as context:
            value, run_sha, request = context
            # Real root store transport: this new random run has no root audit.
            with self.assertRaises(FileNotFoundError):
                stage_runs.begin(value, run_sha, request)
            self.assertFalse((stage_runs.RUNS / value['run_id'] / 'started.json').exists())
            self.assertEqual(list((stage_runs.ARTIFACTS / value['run_id']).iterdir()), [])

    def test_changed_inputs_phase1_mode_boot_or_before_bytes_cannot_resume(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, stage_job_fixture(directory) as context:
            value, _, _ = context
            for args in (('multilib-m32', 'f' * 64, '2' * 64, '3' * 64),
                         ('multilib-m32', '1' * 64, 'f' * 64, '3' * 64),
                         ('multilib-m32', '1' * 64, '2' * 64, 'f' * 64),
                         ('x86_64', '1' * 64, '2' * 64, '3' * 64)):
                with self.assertRaisesRegex(RuntimeError, 'current inputs'):
                    stage_runs.load(value['run_id'], *args)
            Path(value['before_request']).write_text('{}')
            with self.assertRaises(RuntimeError):
                stage_runs.load(value['run_id'], 'multilib-m32', '1' * 64, '2' * 64, '3' * 64)

    def test_failed_outcome_preserves_bytes_and_refuses_post_request_and_retry(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, stage_job_fixture(directory) as context:
            value, run_sha, _ = context
            artifact = stage_runs.ARTIFACTS / value['run_id'] / 'raw.log'; artifact.write_bytes(b'actual failure log')
            result = stage_runs.finish(value, run_sha, [RuntimeError('guest fault')], None, lambda: None)
            self.assertEqual(result['result'], 'FAIL')
            self.assertEqual(result['artifact_sha256']['raw.log'], hashlib.sha256(artifact.read_bytes()).hexdigest())
            with self.assertRaisesRegex(RuntimeError, 'failed/incomplete'):
                stage_runs.after_request(value, run_sha)
            with self.assertRaises(FileExistsError):
                stage_runs.finish(value, run_sha, [], {'fixture': True}, lambda: None)
            with self.assertRaisesRegex(RuntimeError, 'fresh started'):
                stage_runs.execution_guard(value, run_sha)
            self.assertEqual(artifact.read_bytes(), b'actual failure log')

    def test_success_is_pending_post_and_changed_artifacts_reject_new_request(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, stage_job_fixture(directory) as context:
            value, run_sha, _ = context
            artifact = stage_runs.ARTIFACTS / value['run_id'] / 'raw.log'; artifact.write_bytes(b'collected bytes')
            result = stage_runs.finish(value, run_sha, [], {'fixture': True}, lambda: None)
            self.assertEqual(result['result'], 'PENDING_PRIVILEGED_POST')
            first = stage_runs.after_request(value, run_sha)
            second = stage_runs.after_request(value, run_sha)
            self.assertNotEqual(first['request'], second['request'])
            request = json.loads(Path(first['request']).read_text())
            self.assertEqual(request['phase'], 'after'); self.assertEqual(request['run_id'], value['run_id'])
            self.assertGreaterEqual(request['requested_at_ns'], result['ended_at_ns'])
            artifact.write_bytes(b'changed bytes')
            with self.assertRaisesRegex(RuntimeError, 'collected bytes changed'):
                stage_runs.after_request(value, run_sha)

    def test_live_writers_or_missing_guest_validation_never_become_pending(self):
        for live in (False, True):
            with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, stage_job_fixture(directory) as context:
                value, run_sha, _ = context
                def stopped():
                    if live: raise RuntimeError('live VM')
                result = stage_runs.finish(value, run_sha, [], {'fixture': True} if live else None, stopped)
                self.assertEqual(result['result'], 'FAIL')
                with self.assertRaises(RuntimeError): stage_runs.after_request(value, run_sha)

    def test_evidence_alias_and_hardlink_are_rejected(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, stage_job_fixture(directory) as context:
            root = stage_runs.ARTIFACTS / context[0]['run_id']
            artifact = root / 'raw.log'; artifact.write_bytes(b'payload')
            alias = root / 'alias'; alias.symlink_to(artifact)
            with self.assertRaisesRegex(RuntimeError, 'alias'): stage_runs.file_hashes(root)
            alias.unlink(); os.link(artifact, alias)
            with self.assertRaisesRegex(RuntimeError, 'hardlink'): stage_runs.file_hashes(root)

    def test_phase2_no_current_root_audit_never_launches(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, stage_job_fixture(directory, started=False) as context, \
                patch.object(ctl, 'phase1_acceptance_guard'), patch.object(ctl, 'current_stage_run', return_value=context), \
                patch.object(ctl, 'pid', return_value=None), patch.object(ctl, 'verify_cache'), \
                patch.object(ctl, 'run'), patch.object(ctl, 'LOGS', Path(directory)), \
                patch.object(ctl, 'sample', return_value={'errors': []}), patch.object(ctl, 'launch') as launch, \
                patch.object(ctl, 'validate_sample'), \
                patch.object(host_stage_audit, 'verify', side_effect=RuntimeError('no pristine root audit')):
            with self.assertRaisesRegex(RuntimeError, 'pristine root audit'):
                ctl.phase2('multilib-m32', True, context[0]['run_id'])
            launch.assert_not_called()
            self.assertFalse((stage_runs.RUNS / context[0]['run_id'] / 'started.json').exists())

    def test_controller_uses_fresh_guest_run_and_stops_at_pending(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, stage_job_fixture(directory) as context, \
                patch.object(ctl, 'run_monitored', return_value={'fixture_command': True}), patch.object(ctl, 'stop') as stop, \
                patch.object(ctl, 'pid', return_value=None), patch.object(ctl, 'checkpoint') as checkpoint, \
                patch.object(checkpoint_store, 'inspect_disks', return_value={'fixture': True}), \
                patch.object(ctl, 'verify_stability_artifacts', return_value={'fixture': True}) as verify:
            value = context[0]; root = stage_runs.ARTIFACTS / value['run_id']
            old = Path(directory) / 'old-stability'; old.mkdir(); (old / 'summary.json').write_bytes(b'old bytes')
            def collect(argv, **kwargs):
                self.assertEqual(argv[0], 'rsync')
                self.assertEqual(argv[-1], str(root / 'guest') + '/')
                (root / 'guest/summary.json').write_text(json.dumps({'run_id': value['run_id']}))
            with patch.object(ctl, 'run', side_effect=collect):
                outcome = ctl.stability_run(context[:2])
            self.assertEqual(outcome['result'], 'PENDING_PRIVILEGED_POST')
            self.assertIn('guest/summary.json', outcome['artifact_sha256'])
            self.assertIn('repositories-after.json', outcome['artifact_sha256'])
            self.assertEqual(verify.call_args.args[0], root / 'guest')
            self.assertEqual((old / 'summary.json').read_bytes(), b'old bytes')
            stop.assert_called_once(); checkpoint.assert_not_called()
            with self.assertRaisesRegex(RuntimeError, 'fresh started'):
                ctl.stability_run(context[:2])

    def test_another_guest_run_fails_before_artifact_acceptance(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory, stage_job_fixture(directory) as context, \
                patch.object(ctl, 'run_monitored', return_value={'fixture_command': True}), patch.object(ctl, 'stop') as stop, \
                patch.object(ctl, 'pid', return_value=None), patch.object(ctl, 'verify_stability_artifacts') as verify:
            root = stage_runs.ARTIFACTS / context[0]['run_id']
            def collect(argv, **kwargs):
                (root / 'guest/summary.json').write_text(json.dumps({'run_id': 'f' * 32}))
            with patch.object(ctl, 'run', side_effect=collect):
                with self.assertRaisesRegex(RuntimeError, 'no checkpoint'):
                    ctl.stability_run(context[:2])
            verify.assert_not_called(); stop.assert_called_once()
            outcome = json.loads((stage_runs.RUNS / context[0]['run_id'] / 'outcome.json').read_text())
            self.assertEqual(outcome['result'], 'FAIL')
            self.assertIn('another run', outcome['errors'][0])


class StageAuditTests(unittest.TestCase):
    def fixture(self, root, phase='before'):
        now = host_stage_audit.time.time_ns()
        request = {'schema': host_stage_audit.SCHEMA, 'stage': 'stability', 'phase': phase,
                   'outcome_sha256': None if phase == 'before' else 'e' * 64,
                   'run_id': 'a' * 32, 'audit_id': 'b' * 32, 'boot_id': host_stage_audit.BOOT.read_text().strip(),
                   'inputs_sha256': '1' * 64, 'sources_sha256': '2' * 64,
                   'requested_at_ns': now - 100000}
        raw = (json.dumps(request, sort_keys=True) + '\n').encode()
        dest = root / request['run_id'] / phase / request['audit_id']; dest.mkdir(parents=True)
        metadata = {'schema': 'alpbahOS.root-stage-audit/v1', 'uid': 0, 'request': request,
                    'request_sha256': host_stage_audit.digest(raw), 'producer_sha256': '3' * 64,
                    'started_at_ns': now - 90000, 'ended_at_ns': now - 1000,
                    'boot_id': request['boot_id'], 'boot_id_after': request['boot_id'],
                    'result': 'CAPTURED', 'commands': {}}
        for i, (role, argv) in enumerate(host_stage_audit.COMMANDS.items()):
            stdout = b'{"__CURSOR":"fixture-cursor","MESSAGE":"ordinary kernel message"}\n' if role == 'kernel' else b''
            stderr = b''
            (dest / (role + '.stdout')).write_bytes(stdout); (dest / (role + '.stderr')).write_bytes(stderr)
            metadata['commands'][role] = {'argv': argv, 'exit': 0,
                'started_at_ns': now - 80000 + i * 10000, 'ended_at_ns': now - 78000 + i * 10000,
                'stdout': role + '.stdout', 'stderr': role + '.stderr',
                'stdout_sha256': host_stage_audit.digest(stdout), 'stderr_sha256': host_stage_audit.digest(stderr)}
        (dest / 'audit.json').write_text(json.dumps(metadata))
        return raw, metadata, dest, now

    def verify_fixture(self, root, raw, boundary):
        # Real files/bytes/schema/content/times; only root ownership transport
        # is replaced. These uid1000 fixtures are never privileged evidence.
        with patch.object(host_stage_audit, 'STORE', root), \
                patch.object(host_stage_audit, 'read_file', side_effect=lambda path, owner: path.read_bytes()):
            return host_stage_audit.verify(raw, '3' * 64, boundary)

    def test_root_capture_cannot_be_launched_unprivileged(self):
        with patch.object(host_stage_audit, 'directory_fd') as directory, \
                patch.object(host_stage_audit.subprocess, 'run') as query:
            with self.assertRaisesRegex(RuntimeError, 'human-run root'):
                host_stage_audit.capture(Path('/unreachable'), '0' * 64, '0' * 64)
            directory.assert_not_called(); query.assert_not_called()

    def test_user_owned_forged_root_metadata_is_rejected(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory); raw, metadata, dest, now = self.fixture(root)
            with patch.object(host_stage_audit, 'STORE', root):
                with self.assertRaisesRegex(RuntimeError, 'protected root-owned'):
                    host_stage_audit.verify(raw, '3' * 64, now)

    def test_private_request_is_single_use_and_contains_no_commands(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory); requests = root / 'requests'
            with patch.object(host_stage_audit, 'REQUESTS', requests), \
                    patch.object(host_stage_audit.secrets, 'token_hex', return_value='b' * 32):
                path, checksum = host_stage_audit.request('stability', 'before', 'a' * 32, '1' * 64, '2' * 64)
                value = host_stage_audit.checked_request(path.read_bytes())
                self.assertEqual(checksum, package_stage.sha(path))
                self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
                self.assertEqual(stat.S_IMODE(requests.stat().st_mode), 0o700)
                self.assertNotIn('commands', value)
                with self.assertRaises(FileExistsError):
                    host_stage_audit.request('stability', 'before', 'a' * 32, '1' * 64, '2' * 64)
                changed = {**value, 'commands': ['untrusted-program']}
                with self.assertRaisesRegex(RuntimeError, 'schema'):
                    host_stage_audit.checked_request(json.dumps(changed))
                with patch.object(host_stage_audit.secrets, 'token_hex', return_value='c' * 32):
                    second, second_sha = host_stage_audit.request('stability', 'before', 'a' * 32, '1' * 64, '2' * 64)
                self.assertNotEqual(path, second)
                self.assertEqual(package_stage.sha(path), checksum)
                self.assertEqual(package_stage.sha(second), second_sha)

    def test_request_symlink_is_rejected_without_target_write(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory); target = root / 'target'; target.mkdir()
            requests = root / 'requests'; requests.symlink_to(target, target_is_directory=True)
            with patch.object(host_stage_audit, 'REQUESTS', requests):
                with self.assertRaises(OSError):
                    host_stage_audit.request('stability', 'before', 'a' * 32, '1' * 64, '2' * 64)
            self.assertEqual(list(target.iterdir()), [])

    def test_both_boundary_directions_and_current_raw_hashes(self):
        for phase in ('before', 'after'):
            with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
                root = Path(directory); raw, metadata, dest, now = self.fixture(root, phase)
                boundary = now if phase == 'before' else now - 100000
                evidence = self.verify_fixture(root, raw, boundary)
                self.assertTrue(evidence['pristine_rpm'])
                self.assertEqual(evidence['kernel_records'], 1)
                self.assertEqual(evidence['artifact_sha256']['audit.json'], package_stage.sha(dest / 'audit.json'))
                bad = now - 100000 if phase == 'before' else now
                with self.assertRaisesRegex(RuntimeError, 'bracket'):
                    self.verify_fixture(root, raw, bad)
                (dest / 'kernel.stdout').write_bytes(b'changed raw evidence')
                with self.assertRaisesRegex(RuntimeError, 'raw bytes changed'):
                    self.verify_fixture(root, raw, boundary)

    def test_identity_command_and_coverage_cannot_be_replaced(self):
        for field in ('uid', 'request_sha256', 'producer_sha256', 'boot_id_after', 'command', 'coverage'):
            with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
                root = Path(directory); raw, metadata, dest, now = self.fixture(root)
                if field == 'uid': metadata[field] = 1000
                elif field in ('request_sha256', 'producer_sha256'): metadata[field] = 'f' * 64
                elif field == 'boot_id_after': metadata[field] = 'other-boot'
                elif field == 'command': metadata['commands']['rpm']['argv'] = ['/usr/bin/rpm', '-V', 'kwin']
                elif field == 'coverage': del metadata['commands']['kernel']
                (dest / 'audit.json').write_text(json.dumps(metadata))
                with self.assertRaises(RuntimeError):
                    self.verify_fixture(root, raw, now)

    def test_nonpristine_rpm_journal_warning_fault_or_empty_coverage_fails(self):
        baseline = {'scripts_before': {'exit': 0, 'stdout': '', 'stderr': ''},
                    'scripts_after': {'exit': 0, 'stdout': '', 'stderr': ''},
                    'rpm': {'exit': 0, 'stdout': '', 'stderr': ''},
                    'kernel': {'exit': 0, 'stdout': '{"__CURSOR":"cursor","MESSAGE":"ordinary"}\n', 'stderr': ''}}
        for role, field, value in (('scripts_before', 'stdout', 'installed-script-package\n'),
                                  ('scripts_after', 'exit', 1),
                                  ('rpm', 'exit', 1), ('rpm', 'stdout', '..5...... c /etc/config\n'),
                                  ('rpm', 'stderr', 'Permission denied'),
                                  ('kernel', 'stderr', 'Journal file corrupted'),
                                  ('kernel', 'stdout', ''),
                                  ('kernel', 'stdout', '{"MESSAGE":"no cursor"}\n'),
                                  ('kernel', 'stdout', '{"__CURSOR":"cursor","MESSAGE":"mce: [Hardware Error]"}\n')):
            outputs = {key: dict(row) for key, row in baseline.items()}; outputs[role][field] = value
            with self.assertRaises(RuntimeError):
                host_stage_audit.inspect_outputs(outputs)

    def test_only_exact_preexisting_root_rpm_baseline_is_accepted(self):
        known = b'pre-existing RPM deviations recorded before isolated build\n'
        outputs = {'scripts_before': {'exit': 0, 'stdout': '', 'stderr': ''},
                   'scripts_after': {'exit': 0, 'stdout': '', 'stderr': ''},
                   'rpm': {'exit': 1, 'stdout': known.decode(), 'stderr': ''},
                   'kernel': {'exit': 0, 'stdout': '{"__CURSOR":"cursor","MESSAGE":"ordinary"}\n', 'stderr': ''}}
        with patch.object(host_stage_audit, 'KNOWN_RPM_BASELINE_SHA256', host_stage_audit.digest(known)):
            evidence = host_stage_audit.inspect_outputs(outputs)
            self.assertFalse(evidence['pristine_rpm'])
            self.assertTrue(evidence['pinned_preexisting_rpm_baseline'])
            outputs['rpm']['stdout'] += 'new deviation\n'
            with self.assertRaisesRegex(RuntimeError, 'differs from pristine or pinned'):
                host_stage_audit.inspect_outputs(outputs)

    def test_stale_future_or_other_boot_request_cannot_be_replayed(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory); raw, metadata, dest, now = self.fixture(root)
            request = json.loads(raw)
            for value in ({**request, 'requested_at_ns': now + 10**12},
                          {**request, 'requested_at_ns': now - 25 * 3600 * 10**9},
                          {**request, 'boot_id': '0' * 36},
                          {**request, 'requested_at_ns': True}):
                with self.assertRaises(RuntimeError):
                    host_stage_audit.checked_request(json.dumps(value))

    def test_pair_cannot_mix_runs_or_inputs(self):
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            root = Path(directory); base = host_stage_audit.time.time_ns() - 10**9
            with patch.object(host_stage_audit.time, 'time_ns', return_value=base):
                before, _, _, _ = self.fixture(root, 'before')
            with patch.object(host_stage_audit.time, 'time_ns', return_value=base + 150000):
                after, _, _, _ = self.fixture(root, 'after')
            with patch.object(host_stage_audit, 'STORE', root), \
                    patch.object(host_stage_audit, 'read_file', side_effect=lambda path, owner: path.read_bytes()):
                result = host_stage_audit.verify_pair(before, after, '3' * 64, base, base + 40000)
                self.assertTrue(result['before']['pristine_rpm']); self.assertTrue(result['after']['pristine_rpm'])
                for key, value in (('run_id', 'c' * 32), ('inputs_sha256', 'f' * 64), ('stage', 'toolchain')):
                    changed = {**json.loads(after), key: value}
                    with self.assertRaisesRegex(RuntimeError, 'different stages/runs'):
                        host_stage_audit.verify_pair(before, json.dumps(changed).encode(), '3' * 64, base, base + 40000)


class TestPolicyRegressionTests(unittest.TestCase):
    def evaluate(self, package, extra='', make_exit=0, missing=None, unfinished=None):
        policy = POLICIES[package]
        with tempfile.TemporaryDirectory(dir=ctl.STATE) as directory:
            files = []
            for i, name in enumerate(policy['required_summary_names']):
                if name == missing:
                    continue
                path = Path(directory) / name
                text = ('PASS: fixture\n' * policy['minimum_pass_count'] if i == 0 else 'PASS: fixture\n')
                if name != unfinished:
                    text += '\t=== fixture Summary ===\n'
                path.write_text(text + (extra if i == 0 else ''))
                files.append(path)
            return test_policy.evaluate(package, files, make_exit, policy)

    def test_fatal_results_cannot_pass_with_zero_make_exit(self):
        for status in ('ERROR', 'UNRESOLVED', 'XPASS'):
            result = self.evaluate('glibc', status + ': harness failure\n')
            self.assertFalse(result['accepted'])
            self.assertTrue(result['fatal_results'])

    def test_known_gcc_scan_failures_have_strict_limit(self):
        line = 'FAIL: gcc.target/i386/pr90579.c scan-assembler vaddsd\n'
        self.assertTrue(self.evaluate('gcc', line * 4, 2)['accepted'])
        self.assertFalse(self.evaluate('gcc', line * 5, 2)['accepted'])
        self.assertFalse(self.evaluate('gcc', 'ERROR: gcc.target/i386/pr90579.c scan-assembler vaddsd\n', 2)['accepted'])
        self.assertFalse(self.evaluate('gcc', 'FAIL: gcc.target/i386/pr90579.c compilation failed\n', 2)['accepted'])

    def test_missing_component_or_unfinished_suite_is_rejected(self):
        self.assertFalse(self.evaluate('gcc', missing='g++.sum')['accepted'])
        self.assertFalse(self.evaluate('binutils', unfinished='gas.sum')['accepted'])
        self.assertFalse(self.evaluate('glibc', make_exit=124)['accepted'])


if __name__ == '__main__':
    unittest.main()
