import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[1]

def load(name):
    spec = importlib.util.spec_from_file_location(name, REPO / 'scripts' / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

parent = load('infra-base-parent')
archived = load('infra-parent-audit')
audit = archived.audit


class ArchivedAuditTests(unittest.TestCase):
    def setUp(self):
        # Model capture while the request was fresh, inspection days later.
        self.now = archived.time.time_ns()
        self.requested = self.now - 3 * 24 * 3600 * 10**9
        self.request = dict(schema=audit.SCHEMA, stage='base', phase='before',
            run_id='1' * 32, audit_id='2' * 32,
            boot_id='11111111-2222-4333-8444-555555555555',
            inputs_sha256='3' * 64, sources_sha256='4' * 64,
            requested_at_ns=self.requested, outcome_sha256=None)
        self.raw = json.dumps(self.request).encode()
        self.root = audit.STORE / self.request['run_id'] / 'before' / self.request['audit_id']
        self.start = self.requested + 100
        self.end = self.start + 1000
        self.metadata = dict(schema='alpbahOS.root-stage-audit/v1', uid=0,
            result='CAPTURED', request=self.request, request_sha256=audit.digest(self.raw),
            producer_sha256=archived.AUDIT_SHA, boot_id=self.request['boot_id'],
            boot_id_after=self.request['boot_id'], started_at_ns=self.start,
            ended_at_ns=self.end, commands={})
        self.files = {}
        for i, (role, argv) in enumerate(audit.COMMANDS.items()):
            row = dict(argv=argv, exit=0, started_at_ns=self.start + i * 10,
                       ended_at_ns=self.start + i * 10 + 5)
            for stream in ('stdout', 'stderr'):
                body = b'{"__CURSOR":"cursor-1","MESSAGE":"healthy"}\n' if role == 'kernel' and stream == 'stdout' else b''
                name = role + '.' + stream
                row[stream], row[stream + '_sha256'] = name, audit.digest(body)
                self.files[self.root / name] = body
            self.metadata['commands'][role] = row

    def verify(self):
        self.files[self.root / 'audit.json'] = json.dumps(self.metadata).encode()
        def read(path, uid):
            self.assertEqual(uid, 0)
            return self.files[path]
        with patch.object(audit, 'read_file', side_effect=read):
            return archived.verify(self.raw, archived.AUDIT_SHA, self.end + 1)

    def test_old_capture_can_be_read_without_authorizing_a_new_launch(self):
        proof = self.verify()
        self.assertTrue(proof['pristine_rpm'])
        self.assertEqual(proof['kernel_cursor'], 'cursor-1')
        with self.assertRaises(RuntimeError):
            audit.checked_request(self.raw)

    def test_capture_must_have_been_fresh_when_root_ran_it(self):
        self.metadata['started_at_ns'] += 25 * 3600 * 10**9
        self.metadata['ended_at_ns'] = self.metadata['started_at_ns'] + 1
        with self.assertRaisesRegex(RuntimeError, 'stale at capture'):
            self.verify()

    def test_root_provenance_and_recorded_boot_are_required(self):
        for key, value in [('uid', 1000), ('uid', False), ('result', 'PASS'),
                           ('boot_id_after', 'changed'), ('producer_sha256', '0' * 64)]:
            with self.subTest(key=key, value=value):
                old = self.metadata[key]; self.metadata[key] = value
                with self.assertRaisesRegex(RuntimeError, 'identity mismatch'):
                    self.verify()
                self.metadata[key] = old

    def test_raw_output_change_is_rejected(self):
        self.files[self.root / 'rpm.stdout'] = b'drift'
        with self.assertRaisesRegex(RuntimeError, 'raw bytes changed'):
            self.verify()

    def test_kernel_fault_and_script_inventory_keep_strict_original_policy(self):
        for role, body in [('kernel', b'{"__CURSOR":"c","MESSAGE":"Kernel panic"}\n'),
                            ('scripts_before', b'package verifier script')]:
            with self.subTest(role=role):
                path = self.root / (role + '.stdout')
                old = self.files[path]; self.files[path] = body
                row = self.metadata['commands'][role]
                old_sha = row['stdout_sha256']; row['stdout_sha256'] = audit.digest(body)
                with self.assertRaises(RuntimeError):
                    self.verify()
                self.files[path] = old; row['stdout_sha256'] = old_sha

    def test_pinned_command_and_output_filename_cannot_drift(self):
        row = self.metadata['commands']['rpm']
        for key, value in [('argv', ['rpm', '-Va']), ('stdout', '../rpm.stdout'),
                           ('exit', False), ('started_at_ns', self.start - 1)]:
            with self.subTest(key=key):
                old = row[key]; row[key] = value
                with self.assertRaises(RuntimeError):
                    self.verify()
                row[key] = old

    def test_pair_cannot_cross_runs_or_boots(self):
        after = {**self.request, 'phase': 'after', 'audit_id': '5' * 32,
                 'outcome_sha256': '6' * 64, 'run_id': '7' * 32}
        with self.assertRaisesRegex(RuntimeError, 'pair stage/run/input'):
            archived.verify_pair(self.raw, json.dumps(after).encode(), archived.AUDIT_SHA,
                                 self.end + 1, self.end + 2)

    def test_actual_historical_toolchain_root_capture_repeats_stored_proof(self):
        raw, proof = parent.stage_runs.read(parent.buildctl.ARTIFACTS / 'toolchain-acceptance.json')
        run_root = parent.stage_runs.RUNS / proof['run_id']
        _, run = parent.stage_runs.read(run_root / 'run.json')
        _, started = parent.stage_runs.read(run_root / 'started.json')
        _, outcome = parent.stage_runs.read(run_root / 'outcome.json')
        _, after = parent.stage_runs.read(run_root / ('after-' + proof['after_audit_id'] + '.json'))
        before_raw = audit.read_file(Path(run['before_request']), audit.USER_UID, 65536)
        after_raw = audit.read_file(Path(after['request']), audit.USER_UID, 65536)
        actual = archived.verify_pair(before_raw, after_raw, run['producer_sha256'],
                                      started['started_at_ns'], outcome['ended_at_ns'])
        self.assertEqual(actual, proof['host'])


class SealedCheckpointTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.vm = Path(self.temp.name)
        for disk in parent.checkpoint_store.DISKS:
            ancestor = self.vm / (disk + '-ancestor.qcow2')
            subprocess.run(['qemu-img', 'create', '-f', 'qcow2', str(ancestor), '1M'], check=True, capture_output=True)
            ancestor.chmod(0o400)
            subprocess.run(['qemu-img', 'create', '-f', 'qcow2', '-F', 'qcow2', '-b', str(ancestor),
                            str(self.vm / (disk + '-active.qcow2'))], check=True, capture_output=True)
        chains = parent.checkpoint_store.inspect_disks(self.vm, lambda: None, lambda: None)
        self.proof = dict(schema='alpbahOS.base-acceptance/v1', result='PASS', stage='base',
            mode='multilib-m32', inputs_sha256='1' * 64, sources_sha256='2' * 64,
            closed_disk_chains=chains)
        self.directory = parent.checkpoint_store.create(self.vm, 'base', '1' * 64, '2' * 64,
                                                       self.proof, lambda: None, lambda: None)
        self.vm_patch = patch.object(parent.buildctl, 'VM', self.vm); self.vm_patch.start()
        self.addCleanup(self.vm_patch.stop)
        self.pid_patch = patch.object(parent.buildctl, 'pid', return_value=None); self.pid_patch.start()
        self.addCleanup(self.pid_patch.stop)
        self.space_patch = patch.object(parent.buildctl, 'space_guard'); self.space_patch.start()
        self.addCleanup(self.space_patch.stop)

    def test_real_relocated_checkpoint_remains_valid_after_current_children_change(self):
        before = {p: p.read_bytes() for p in self.directory.iterdir()}
        for disk in parent.checkpoint_store.DISKS:
            # Current overlays are future-stage bytes, not this accepted parent's bytes.
            subprocess.run(['qemu-io', '-f', 'qcow2', '-c', 'write 0 4096',
                            str(self.vm / (disk + '-active.qcow2'))], check=True, capture_output=True)
        result = parent.checkpoint(self.proof)
        self.assertEqual(result['checkpoint_sha256'], audit.digest(before[self.directory / 'checkpoint.json']))
        self.assertEqual(before, {p: p.read_bytes() for p in self.directory.iterdir()})

    def test_changed_saved_image_cannot_pass_with_old_receipts(self):
        saved = self.directory / 'builder.qcow2'; saved.chmod(0o600)
        subprocess.run(['qemu-io', '-f', 'qcow2', '-c', 'write 0 4096', str(saved)], check=True, capture_output=True)
        saved.chmod(0o400)
        with self.assertRaisesRegex(RuntimeError, 'bytes changed'):
            parent.checkpoint(self.proof)

    def test_saved_writable_alias_and_changed_ancestor_are_rejected(self):
        saved = self.directory / 'builder.qcow2'; saved.chmod(0o600)
        with self.assertRaisesRegex(RuntimeError, 'writable or aliased'):
            parent.checkpoint(self.proof)
        saved.chmod(0o400)
        alias = self.vm / 'alias.qcow2'; os.link(saved, alias)
        with self.assertRaisesRegex(RuntimeError, 'writable or aliased'):
            parent.checkpoint(self.proof)
        alias.unlink()
        ancestor = self.vm / 'builder-ancestor.qcow2'; ancestor.chmod(0o600)
        with self.assertRaisesRegex(RuntimeError, 'ancestor writable'):
            parent.checkpoint(self.proof)

    def test_incomplete_transaction_and_original_path_drift_fail(self):
        tx = self.directory / 'transaction.json'
        original = tx.read_bytes(); value = json.loads(original); value['status'] = 'STARTED'
        tx.write_text(json.dumps(value))
        with self.assertRaisesRegex(RuntimeError, 'Incomplete'):
            parent.checkpoint(self.proof)
        tx.write_bytes(original)
        proof = copy.deepcopy(self.proof); proof['closed_disk_chains']['lfs'][0]['path'] = '/wrong'
        with self.assertRaisesRegex(RuntimeError, 'transaction/proof differs'):
            parent.checkpoint(proof)

    def test_live_writer_is_rejected_before_qemu_inspection(self):
        with patch.object(parent.buildctl, 'pid', return_value=123), patch.object(parent.checkpoint_store, 'command') as command:
            with self.assertRaisesRegex(RuntimeError, 'stopped Builder'):
                parent.checkpoint(self.proof)
            command.assert_not_called()

    def test_missing_actual_base_gate_cannot_launch_or_issue_authorization(self):
        with patch.object(parent.buildctl, 'ARTIFACTS', self.vm), patch.object(parent, 'load') as loader:
            with self.assertRaises(FileNotFoundError):
                parent.accepted_base()
            loader.assert_not_called()

    def test_root_and_unknown_stage_are_rejected_before_disk_access(self):
        with patch.object(parent.os, 'geteuid', return_value=0):
            with self.assertRaisesRegex(RuntimeError, 'unprivileged'):
                parent.checkpoint(self.proof)
        with self.assertRaisesRegex(RuntimeError, 'fixed stage'):
            parent.checkpoint(self.proof, 'kernel')

    def test_base_acceptance_keeps_current_disk_gate_and_requires_saved_checkpoint_for_replay(self):
        base = load('infra-base-stage')
        with self.assertRaisesRegex(RuntimeError, 'chains changed before checkpoint'):
            base.verify_base_disks(self.proof)
        base.verify_base_disks(self.proof, checkpointed=True)
        saved = self.directory / 'lfs.qcow2'; saved.chmod(0o600)
        with self.assertRaisesRegex(RuntimeError, 'writable or aliased'):
            base.verify_base_disks(self.proof, checkpointed=True)

    def test_host_controller_rejects_changed_parent_helper(self):
        base = load('infra-base-stage')
        self.assertEqual(len(base.parent_helpers()), 2)
        with patch.object(base, 'sha', return_value='0' * 64):
            with self.assertRaisesRegex(RuntimeError, 'helper source changed'):
                base.parent_helpers()

if __name__ == '__main__':
    unittest.main()
