import hashlib
import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('kernel_authorize', REPO / 'scripts/infra-kernel-authorize.py')
transport = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(transport)
kernel = transport.kernel


class KernelAuthorization(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.infra = Path(self.temp.name)
        self.infra.chmod(0o700)
        self.proof_raw = b'{"fixture":"base"}\n'
        self.parent_raw = b'{"fixture":"parent"}\n'
        self.auth_raw = b'{"fixture":"authorization"}\n'
        self.raw = b'fixture transport bytes'
        self.current = {'run_id': 'b' * 32,
                        'guest_boot_id': '12345678-1234-1234-1234-123456789abc',
                        'host_boot_id': 'abcdefab-cdef-abcd-abcd-abcdefabcdef',
                        'base_acceptance_sha256': transport.digest(self.proof_raw),
                        'parent_sha256': transport.digest(self.parent_raw),
                        'helper_sha256': {name: '3' * 64 for name in kernel.HELPERS}}
        self.paths = [self.infra / name for name in ('kernel-base-acceptance.json',
                      'kernel-parent.json', 'kernel-build-authorization.json')]

    def deliver(self):
        return transport.deliver(self.raw, self.current, self.proof_raw, self.parent_raw, self.auth_raw)

    def fixture_guards(self):
        return patch.object(kernel.package_install, 'guest_install_guard')

    def test_host_invocation_fails_before_decode_guard_or_mutation(self):
        with patch('os.geteuid', return_value=1000), self.fixture_guards() as guard, patch.object(transport, 'decode') as decode:
            with self.assertRaisesRegex(RuntimeError, 'host invocation refused'):
                transport.install(b'{}')
            guard.assert_not_called()
            decode.assert_not_called()

    def test_oversized_unknown_fields_and_wrong_evidence_type_fail(self):
        for raw in (b'x' * (transport.MAX_BYTES + 1), b'[]', b'{"extra":1}',
                    b'{"base_raw":"[]","parent_raw":"{}","authorization":{}}',
                    b'{"base_raw":{},"parent_raw":"{}","authorization":{}}'):
            with self.subTest(raw=raw[:80]), self.assertRaises((RuntimeError, ValueError)):
                transport.decode(raw)

    def test_raw_parent_and_proof_bytes_are_preserved_not_reserialized(self):
        raw = json.dumps({'base_raw': self.proof_raw.decode(), 'parent_raw': self.parent_raw.decode(),
                          'authorization': {'fixture': 'authorization'}}).encode()
        proof_raw, proof, parent_raw, parent, auth = transport.decode(raw)
        self.assertEqual(proof_raw, self.proof_raw)
        self.assertEqual(parent_raw, self.parent_raw)
        self.assertEqual(proof, {'fixture': 'base'})
        self.assertEqual(parent, {'fixture': 'parent'})
        self.assertEqual(auth, {'fixture': 'authorization'})

    def test_actual_exclusive_files_auth_last_and_completion_match(self):
        real = kernel.guest_handoff.exclusive
        order = []
        def record(path, raw):
            order.append(path.name)
            real(path, raw)
        with patch.object(transport, 'INFRA', self.infra), self.fixture_guards() as guard, patch.object(kernel.guest_handoff, 'exclusive', side_effect=record):
            response = self.deliver()
        self.assertEqual(order, ['b' * 32 + '.attempt.json', *[p.name for p in self.paths],
                                 'b' * 32 + '.completed.json'])
        self.assertEqual(guard.call_count, 5)
        for path, contents in zip(self.paths, (self.proof_raw, self.parent_raw, self.auth_raw)):
            self.assertEqual(path.read_bytes(), contents)
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        receipt = self.infra / 'kernel-handoffs' / ('b' * 32 + '.completed.json')
        self.assertEqual(kernel.completed_handoff(receipt.read_bytes(), self.current, self.auth_raw),
                         hashlib.sha256(receipt.read_bytes()).hexdigest())
        self.assertEqual(response['payload_sha256'], transport.digest(self.raw))

    def test_replayed_complete_delivery_preserves_every_byte(self):
        with patch.object(transport, 'INFRA', self.infra), self.fixture_guards():
            self.deliver()
            before = {str(p): p.read_bytes() for p in self.infra.rglob('*') if p.is_file()}
            with self.assertRaisesRegex(RuntimeError, 'Existing kernel handoff'):
                self.deliver()
            self.assertEqual(before, {str(p): p.read_bytes() for p in self.infra.rglob('*') if p.is_file()})

    def test_interruption_at_each_record_and_completion_refuses_replay(self):
        real = kernel.guest_handoff.exclusive
        for fail_at in range(2, 6):
            with self.subTest(fail_at=fail_at), tempfile.TemporaryDirectory() as folder:
                infra = Path(folder); infra.chmod(0o700)
                calls = []
                def interrupted(path, raw):
                    calls.append(path)
                    if len(calls) == fail_at:
                        raise OSError('fixture abrupt delivery interruption')
                    real(path, raw)
                with patch.object(transport, 'INFRA', infra), self.fixture_guards(), patch.object(kernel.guest_handoff, 'exclusive', side_effect=interrupted):
                    with self.assertRaises(OSError):
                        self.deliver()
                self.assertTrue((infra / 'kernel-handoffs' / ('b' * 32 + '.attempt.json')).is_file())
                self.assertFalse((infra / 'kernel-handoffs' / ('b' * 32 + '.completed.json')).exists())
                # Even if all three records exist, missing completion blocks producer.
                with self.assertRaises((RuntimeError, OSError)):
                    kernel.read_record(infra / 'kernel-handoffs' / ('b' * 32 + '.completed.json'))
                with patch.object(transport, 'INFRA', infra), self.fixture_guards():
                    with self.assertRaises((RuntimeError, FileExistsError)):
                        self.deliver()

    def test_aliased_destination_refused_before_attempt_or_replacement(self):
        original = self.infra / 'protected'; original.write_bytes(b'original')
        self.paths[0].symlink_to(original)
        with patch.object(transport, 'INFRA', self.infra), self.fixture_guards():
            with self.assertRaisesRegex(RuntimeError, 'alias/type/owner'):
                self.deliver()
        self.assertEqual(original.read_bytes(), b'original')
        self.assertFalse((self.infra / 'kernel-handoffs').exists())

    def test_post_write_drift_never_writes_completion_receipt(self):
        real = kernel.read_record
        def drift(path):
            raw, value = real(path)
            return (raw + b' ', value) if path.name == 'kernel-parent.json' else (raw, value)
        with patch.object(transport, 'INFRA', self.infra), self.fixture_guards(), patch.object(kernel, 'read_record', side_effect=drift):
            with self.assertRaisesRegex(RuntimeError, 'delivered bytes changed'):
                self.deliver()
        self.assertFalse((self.infra / 'kernel-handoffs' / ('b' * 32 + '.completed.json')).exists())
        self.assertTrue(self.paths[2].exists())

    def test_completed_receipt_rejects_auth_boot_helper_payload_or_extra_field_drift(self):
        with patch.object(transport, 'INFRA', self.infra), self.fixture_guards():
            response = self.deliver()
        for key, value in [('authorization_sha256', '0' * 64), ('guest_boot_id', 'other'),
                           ('helper_sha256', {}), ('payload_sha256', ''), ('extra', True)]:
            changed = {**response, key: value}
            with self.subTest(key=key), self.assertRaisesRegex(RuntimeError, 'handoff is partial'):
                kernel.completed_handoff(json.dumps(changed).encode(), self.current, self.auth_raw)


if __name__ == '__main__':
    unittest.main()
