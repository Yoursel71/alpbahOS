from __future__ import annotations

import hashlib
import importlib.util
import io
import json
import os
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest.mock import patch


MODULE_PATH = Path(__file__).resolve().parents[1] / "scripts" / "validate-rootfs-ownership-ledger.py"
SPEC = importlib.util.spec_from_file_location("ownership_ledger_validator", MODULE_PATH)
assert SPEC and SPEC.loader
validator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(validator)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def record(name: str, path: str, content_sha: str) -> dict:
    return {
        "package": {
            "name": name,
            "version": "1.2.3",
            "source": {"url": "https://example.invalid/pkg-1.2.3.tar.xz", "sha256": "a" * 64},
            "recipe": {"identity": "git:0123456789abcdef/script.sh", "sha256": "b" * 64},
        },
        "transaction_id": f"txn-{name}-001",
        "recorded_at": "2026-09-24T12:00:00Z",
        "manifest_sha256": "c" * 64,
        "install_evidence": {
            "kind": "install-log",
            "status": "claimed-complete",
            "uri": "verification/example-install.log",
            "sha256": "d" * 64,
            "completed_at": "2026-09-24T11:59:00+00:00",
        },
        "entries": [
            {
                "path": path,
                "type": "file",
                "mode": 0o644,
                "uid": 0,
                "gid": 0,
                "size": 4,
                "sha256": content_sha,
            }
        ],
    }


class OwnershipLedgerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "rootfs"
        self.root.mkdir()
        (self.root / "usr/bin").mkdir(parents=True)
        self.file = self.root / "usr/bin/tool"
        self.file.write_bytes(b"test")
        os.chmod(self.file, 0o644)
        self.file_stat = self.file.stat()
        self.good_record = record("tool", "/usr/bin/tool", sha(b"test"))
        entry = self.good_record["entries"][0]
        entry["mode"] = self.file_stat.st_mode & 0o7777
        entry["uid"] = self.file_stat.st_uid
        entry["gid"] = self.file_stat.st_gid
        self.ledger = {"schema": validator.SCHEMA, "records": [self.good_record]}

    def test_valid_record_matches_rootfs(self) -> None:
        self.assertEqual(validator.validate_rootfs(self.ledger, self.root), 0)

    def test_accepts_empty_ledger_for_initial_bootstrap(self) -> None:
        empty = {"schema": validator.SCHEMA, "records": []}
        self.assertEqual(validator.validate_ledger(empty), [])
        self.assertEqual(validator.validate_rootfs(empty, self.root), 0)

    def test_empty_cli_result_is_consistency_only_and_distinct_nonzero(self) -> None:
        ledger_file = Path(self.temp.name) / "empty-ledger.json"
        ledger_file.write_text(json.dumps({"schema": validator.SCHEMA, "records": []}), encoding="utf-8")
        stdout = io.StringIO()
        with patch("sys.argv", [str(MODULE_PATH), "--ledger", str(ledger_file), "--root", str(self.root)]):
            with redirect_stdout(stdout):
                code = validator.main()
        self.assertEqual(code, 3)
        self.assertIn("CONSISTENCY_ONLY", stdout.getvalue())
        self.assertIn("EMPTY_LEDGER_BOOTSTRAP", stdout.getvalue())
        self.assertIn("QUIESCENCE_REQUIRED", stdout.getvalue())
        self.assertNotIn("NOT_OWNERSHIP_PROOF", stdout.getvalue())

    def test_nonempty_cli_success_is_not_ownership_proof(self) -> None:
        ledger_file = Path(self.temp.name) / "ledger.json"
        ledger_file.write_text(json.dumps(self.ledger), encoding="utf-8")
        stdout = io.StringIO()
        with patch("sys.argv", [str(MODULE_PATH), "--ledger", str(ledger_file), "--root", str(self.root)]):
            with redirect_stdout(stdout):
                code = validator.main()
        self.assertEqual(code, 0)
        self.assertIn("CONSISTENCY_ONLY", stdout.getvalue())
        self.assertIn("NOT_OWNERSHIP_PROOF", stdout.getvalue())
        self.assertIn("QUIESCENCE_REQUIRED", stdout.getvalue())

    def test_rejects_dotdot_root_before_path_normalization(self) -> None:
        noncanonical_root = self.root.parent / "missing" / ".." / "rootfs"
        with self.assertRaisesRegex(validator.LedgerError, "must not contain '..'"):
            validator.validate_rootfs({"schema": validator.SCHEMA, "records": []}, noncanonical_root)

        ledger_file = Path(self.temp.name) / "empty-ledger.json"
        ledger_file.write_text(json.dumps({"schema": validator.SCHEMA, "records": []}), encoding="utf-8")
        stderr = io.StringIO()
        with patch("sys.argv", [str(MODULE_PATH), "--ledger", str(ledger_file), "--root", str(noncanonical_root)]):
            with redirect_stderr(stderr):
                code = validator.main()
        self.assertEqual(code, 2)
        self.assertIn("must not contain '..'", stderr.getvalue())

    def test_rejects_wrong_schema_and_missing_fields(self) -> None:
        bad = json.loads(json.dumps(self.ledger))
        bad["schema"] = "alpbahOS.package-files/v1"
        with self.assertRaises(validator.LedgerError):
            validator.validate_ledger(bad)

    def test_rejects_malformed_source_recipe_manifest_and_evidence_hashes(self) -> None:
        for section, field in (
            ("source", "sha256"),
            ("recipe", "sha256"),
            (None, "manifest_sha256"),
            ("install_evidence", "sha256"),
        ):
            with self.subTest(section=section, field=field):
                bad = json.loads(json.dumps(self.ledger))
                if section is None:
                    target = bad["records"][0]
                elif section in ("source", "recipe"):
                    target = bad["records"][0]["package"][section]
                else:
                    target = bad["records"][0][section]
                target[field] = "not-a-sha256"
                with self.assertRaises(validator.LedgerError):
                    validator.validate_ledger(bad)
        bad = json.loads(json.dumps(self.ledger))
        del bad["records"][0]["manifest_sha256"]
        with self.assertRaises(validator.LedgerError):
            validator.validate_ledger(bad)

    def test_rejects_path_traversal_and_noncanonical_paths(self) -> None:
        for unsafe in ("/../etc/passwd", "/usr/../etc/passwd", "/usr//bin/tool", "usr/bin/tool", "/usr\\bin\\tool"):
            with self.subTest(path=unsafe):
                bad = json.loads(json.dumps(self.ledger))
                bad["records"][0]["entries"][0]["path"] = unsafe
                with self.assertRaises(validator.LedgerError):
                    validator.validate_ledger(bad)

    def test_rejects_directories_as_owned_paths(self) -> None:
        bad = json.loads(json.dumps(self.ledger))
        entry = bad["records"][0]["entries"][0]
        entry.update(type="directory")
        entry.pop("size")
        entry.pop("sha256")
        with self.assertRaisesRegex(validator.LedgerError, "only files and symlinks"):
            validator.validate_ledger(bad)

    def test_rejects_duplicate_owner_and_path_prefix_overlap(self) -> None:
        duplicate = json.loads(json.dumps(self.ledger))
        second = json.loads(json.dumps(duplicate["records"][0]))
        second["package"]["name"] = "second"
        second["transaction_id"] = "txn-second-001"
        duplicate["records"].append(second)
        with self.assertRaisesRegex(validator.LedgerError, "duplicate ownership"):
            validator.validate_ledger(duplicate)

        overlap = json.loads(json.dumps(self.ledger))
        second = json.loads(json.dumps(overlap["records"][0]))
        second["package"]["name"] = "child"
        second["transaction_id"] = "txn-child-0001"
        second["entries"][0]["path"] = "/usr/bin/tool/child"
        overlap["records"].append(second)
        with self.assertRaisesRegex(validator.LedgerError, "overlapping owned paths"):
            validator.validate_ledger(overlap)

    def test_detects_content_hash_and_metadata_mismatch(self) -> None:
        self.file.write_bytes(b"evil")
        self.assertEqual(validator.validate_rootfs(self.ledger, self.root), 1)

    def test_detects_file_replacement_after_initial_lstat(self) -> None:
        original_hash_file = validator._hash_file

        def replace_then_hash(path: Path, expected_info: os.stat_result) -> tuple[int, str]:
            replacement = path.with_name("replacement")
            replacement.write_bytes(b"evil")
            os.chmod(replacement, path.stat().st_mode & 0o7777)
            os.replace(replacement, path)
            return original_hash_file(path, expected_info)

        with patch.object(validator, "_hash_file", side_effect=replace_then_hash):
            with self.assertRaisesRegex(validator.LedgerError, "changed while hashing"):
                validator.validate_rootfs(self.ledger, self.root)

    def test_symlink_target_is_compared_without_following_it(self) -> None:
        link = self.root / "usr/bin/current"
        try:
            link.symlink_to("tool")
        except OSError as exc:
            if getattr(exc, "winerror", None) == 1314:
                self.skipTest("Windows symlink creation requires Developer Mode or the SeCreateSymbolicLink privilege")
            raise
        info = link.lstat()
        rec = record("link-package", "/usr/bin/current", "e" * 64)
        rec["entries"] = [{
            "path": "/usr/bin/current", "type": "symlink", "mode": info.st_mode & 0o7777,
            "uid": info.st_uid, "gid": info.st_gid, "target": "tool",
        }]
        self.assertEqual(validator.validate_rootfs({"schema": validator.SCHEMA, "records": [rec]}, self.root), 0)
        rec["entries"][0]["target"] = "wrong"
        self.assertEqual(validator.validate_rootfs({"schema": validator.SCHEMA, "records": [rec]}, self.root), 1)

    def test_rejects_symlinked_intermediate_directory(self) -> None:
        external = Path(self.temp.name) / "external"
        external.mkdir()
        (external / "tool").write_bytes(b"test")
        try:
            (self.root / "usr/escape").symlink_to(external, target_is_directory=True)
        except OSError as exc:
            if getattr(exc, "winerror", None) == 1314:
                self.skipTest("Windows symlink creation requires Developer Mode or the SeCreateSymbolicLink privilege")
            raise
        bad = json.loads(json.dumps(self.ledger))
        bad["records"][0]["entries"][0]["path"] = "/usr/escape/tool"
        with self.assertRaisesRegex(validator.LedgerError, "symlink path component"):
            validator.validate_rootfs(bad, self.root)

    def test_rejects_symlinked_root_ancestor(self) -> None:
        real_parent = Path(self.temp.name) / "real-parent"
        real_parent.mkdir()
        real_root = real_parent / "rootfs"
        real_root.mkdir()
        link_parent = Path(self.temp.name) / "linked-parent"
        try:
            link_parent.symlink_to(real_parent, target_is_directory=True)
        except OSError as exc:
            if getattr(exc, "winerror", None) == 1314:
                self.skipTest("Windows symlink creation requires Developer Mode or the SeCreateSymbolicLink privilege")
            raise
        with self.assertRaisesRegex(validator.LedgerError, "symlinked component"):
            validator.validate_rootfs({"schema": validator.SCHEMA, "records": []}, link_parent / "rootfs")

    def test_detects_symlink_replacement_while_reading_target(self) -> None:
        link = self.root / "usr/bin/current"
        try:
            link.symlink_to("tool")
        except OSError as exc:
            if getattr(exc, "winerror", None) == 1314:
                self.skipTest("Windows symlink creation requires Developer Mode or the SeCreateSymbolicLink privilege")
            raise
        info = link.lstat()
        rec = record("link-package", "/usr/bin/current", "e" * 64)
        rec["entries"] = [{
            "path": "/usr/bin/current", "type": "symlink", "mode": info.st_mode & 0o7777,
            "uid": info.st_uid, "gid": info.st_gid, "target": "tool",
        }]
        raw_readlink = os.readlink
        swapped = False

        def replace_then_read(path: os.PathLike[str] | str) -> str:
            nonlocal swapped
            if not swapped:
                swapped = True
                Path(path).unlink()
                Path(path).symlink_to("replacement")
            return raw_readlink(path)

        with patch.object(validator.os, "readlink", side_effect=replace_then_read):
            with self.assertRaisesRegex(validator.LedgerError, "symlink changed while inspecting"):
                validator.validate_rootfs({"schema": validator.SCHEMA, "records": [rec]}, self.root)


if __name__ == "__main__":
    unittest.main()
