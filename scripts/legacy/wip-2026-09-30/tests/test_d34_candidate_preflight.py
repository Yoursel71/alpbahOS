from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "preflight-d34-candidate-root.py"
SPEC = importlib.util.spec_from_file_location("d34_candidate_preflight", SCRIPT)
preflight = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(preflight)


class CandidatePreflightTests(unittest.TestCase):
    def _fake_run(self, argv):
        if argv[0] == "findmnt":
            output = {
                "filesystems": [{
                    "id": 64, "source": "/dev/nvme0n1p3[/home]", "fstype": "btrfs",
                    "uuid": "663b4a21-0364-4ee2-91cd-67d5994e9fe4",
                    "target": "/home", "fsroot": "/home",
                }]
            }
        else:
            output = "Name: candidate\nUUID: c205dbcb-bd1d-4c46-9150-03272bbbf8d6\nSubvolume ID: 290\n"
        return __import__("subprocess").CompletedProcess(argv, 0, json.dumps(output) if isinstance(output, dict) else output, "")

    def test_candidate_identity_is_authenticated_against_expected_ids(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / "root"
            root.mkdir()
            with mock.patch.object(preflight, "_run", side_effect=self._fake_run), \
                 mock.patch.object(preflight, "_nested_mounts", return_value=[]):
                evidence = preflight.inspect_candidate(
                    root, "663b4a21-0364-4ee2-91cd-67d5994e9fe4",
                    "c205dbcb-bd1d-4c46-9150-03272bbbf8d6",
                )
            self.assertEqual(evidence["filesystem"]["mount_id"], 64)
            self.assertEqual(evidence["subvolume"], {
                "uuid": "c205dbcb-bd1d-4c46-9150-03272bbbf8d6", "id": 290,
            })
            self.assertFalse(evidence["rootfs_mutated"])

    def test_wrong_subvolume_identity_fails_closed(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / "root"
            root.mkdir()
            with mock.patch.object(preflight, "_run", side_effect=self._fake_run), \
                 mock.patch.object(preflight, "_nested_mounts", return_value=[]):
                with self.assertRaisesRegex(preflight.CandidatePreflightError, "subvolume UUID mismatch"):
                    preflight.inspect_candidate(
                        root, "663b4a21-0364-4ee2-91cd-67d5994e9fe4", "f" * 36,
                    )

    def test_nested_mount_fails_closed(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / "root"
            root.mkdir()
            with mock.patch.object(preflight, "_run", side_effect=self._fake_run), \
                 mock.patch.object(preflight, "_nested_mounts", return_value=[
                     {"mount_id": "101", "mountpoint": str(root / "usr")},
                 ]):
                with self.assertRaisesRegex(preflight.CandidatePreflightError, "nested mounts"):
                    preflight.inspect_candidate(
                        root, "663b4a21-0364-4ee2-91cd-67d5994e9fe4",
                        "c205dbcb-bd1d-4c46-9150-03272bbbf8d6",
                    )

    def test_writer_lock_is_exclusive_between_preflight_callers(self):
        with tempfile.TemporaryDirectory() as temp:
            lock = Path(temp) / "writer.lock"
            first = preflight.exclusive_writer_lock(lock)
            first.__enter__()
            try:
                second = preflight.exclusive_writer_lock(lock)
                with self.assertRaisesRegex(preflight.CandidatePreflightError, "lock is busy"):
                    second.__enter__()
            finally:
                first.__exit__(None, None, None)

    def test_active_lfs_path_is_refused_without_running_identity_commands(self):
        with mock.patch.object(preflight, "_run") as run:
            with self.assertRaisesRegex(preflight.CandidatePreflightError, "refusing"):
                preflight.inspect_candidate(
                    Path("/mnt/lfs"), "a315d631-1708-4649-b6aa-23dba88cc71a", "f" * 36,
                )
        run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
