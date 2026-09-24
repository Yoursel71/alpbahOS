"""Linux fixture tests for the experimental M04 transaction writer."""

from __future__ import annotations

import importlib.util
import hashlib
import json
import os
import stat
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "m04-package-install-transaction.py"
SPEC = importlib.util.spec_from_file_location("m04_tx", SCRIPT)
tx = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(tx)


class Fixture:
    def __init__(self, temp: tempfile.TemporaryDirectory[str]):
        self.base = Path(temp.name)
        self.root = self.base / "root"
        self.stage = self.base / "stage"
        self.root.mkdir()
        self.stage.mkdir()
        (self.root / tx.MARKER).write_text(tx.MARKER_TEXT, encoding="utf-8")
        (self.root / "usr/bin").mkdir(parents=True)
        (self.stage / "usr/bin").mkdir(parents=True)

    def add_stage_file(self, relative: str, content: bytes, mode: int = 0o755) -> Path:
        path = self.stage / relative.lstrip("/")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        path.chmod(mode)
        return path

    def install(self, *, name: str = "fixture-pkg", policy: Path | None = None, fail=None) -> str:
        return tx.install_transaction(
            self.root, self.stage, name=name, version="1.0",
            source_sha256="1" * 64, recipe_sha256="2" * 64,
            policy_path=policy, failpoint=fail,
        )


class TransactionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.fx = Fixture(self.temp)

    def tearDown(self):
        self.temp.cleanup()

    def ledger(self):
        path = self.fx.root / tx.LEDGER_NAME
        return json.loads(path.read_text()) if path.exists() else {"records": []}

    def crash_at(self, point: str):
        def hook(actual: str):
            if actual == point:
                raise tx.InjectedCrash(point)
        return hook

    def test_install_commits_only_after_live_recapture_and_leaves_dirs_unowned(self):
        self.fx.add_stage_file("/usr/bin/hello", b"hello\n")
        txid = self.fx.install()
        live = self.fx.root / "usr/bin/hello"
        self.assertEqual(live.read_bytes(), b"hello\n")
        ledger = self.ledger()
        self.assertEqual(ledger["schema"], tx.SCHEMA)
        record = ledger["records"][0]
        self.assertEqual(record["transaction_id"], txid)
        self.assertEqual([e["path"] for e in record["entries"]], ["/usr/bin/hello"])
        self.assertFalse(any(e["path"] == "/usr/bin" for e in record["entries"]))
        journal_path = self.fx.root / tx.JOURNAL_DIR / txid / "journal.json"
        journal = json.loads(journal_path.read_text())
        self.assertEqual(journal["state"], "committed")
        self.assertTrue(record["stage_manifest_sha256"])
        self.assertTrue(record["pre_commit_journal_sha256"])
        self.assertEqual(stat.S_IMODE((self.fx.root / tx.JOURNAL_DIR).stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE(journal_path.parent.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE((journal_path.parent / "payloads").stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE((journal_path.parent / "backups").stat().st_mode), 0o700)

    def test_differing_existing_path_rejected_without_modification(self):
        target = self.fx.root / "usr/bin/tool"
        target.write_bytes(b"old")
        self.fx.add_stage_file("/usr/bin/tool", b"new")
        with self.assertRaisesRegex(tx.TransactionError, "exact replace policy"):
            self.fx.install()
        self.assertEqual(target.read_bytes(), b"old")
        self.assertEqual(self.ledger()["records"], [])

    def test_replace_policy_pins_old_fingerprint_and_transfers_claim(self):
        self.fx.add_stage_file("/usr/bin/tool", b"old")
        txid1 = self.fx.install(name="old-owner")
        target = self.fx.root / "usr/bin/tool"
        old = tx._object(target)
        self.fx.stage.joinpath("usr/bin/tool").write_bytes(b"new")
        policy = self.fx.base / "replace.json"
        policy.write_text(json.dumps({
            "schema": "alpbahOS.m04-fixture-replace-policy/v1",
            "replacements": {"/usr/bin/tool": {
                "old_fingerprint": tx._fingerprint(old), "previous_owner": "old-owner"
            }},
        }))
        txid2 = self.fx.install(name="new-owner", policy=policy)
        self.assertEqual(target.read_bytes(), b"new")
        ledger = self.ledger()
        records = {r["package"]["name"]: r for r in ledger["records"]}
        self.assertEqual(records["old-owner"]["entries"], [])
        self.assertEqual(records["new-owner"]["entries"][0]["path"], "/usr/bin/tool")
        self.assertEqual(tx.recover_transaction(self.fx.root, txid1), "committed")
        self.assertEqual(tx.recover_transaction(self.fx.root, txid2), "committed")
        journal2 = json.loads((self.fx.root / tx.JOURNAL_DIR / txid2 / "journal.json").read_text())
        self.assertEqual(journal2["policy_sha256"], hashlib.sha256(policy.read_bytes()).hexdigest())

    def test_policy_parser_and_hash_use_one_byte_snapshot(self):
        policy = self.fx.base / "policy-snapshot.json"
        raw = b'{ "schema": "alpbahOS.m04-fixture-replace-policy/v1", "replacements": {} }\n'
        policy.write_bytes(raw)
        parsed, digest = tx._load_policy_snapshot(policy)
        self.assertEqual(parsed["replacements"], {})
        self.assertEqual(digest, hashlib.sha256(raw).hexdigest())

    def test_crash_after_prepared_or_first_replace_rolls_back_idempotently(self):
        for point in ("after_prepared", "after_replace_0", "after_applied_0"):
            with self.subTest(point=point):
                # Use an independent disposable root per boundary.
                temp = tempfile.TemporaryDirectory()
                fx = Fixture(temp)
                fx.add_stage_file("/usr/bin/hello", b"new")
                txid = None
                try:
                    with self.assertRaises(tx.InjectedCrash):
                        fx.install(fail=self.crash_at(point))
                    journals = list((fx.root / tx.JOURNAL_DIR).glob("*/journal.json"))
                    txid = journals[0].parent.name
                    state = tx.recover_transaction(fx.root, txid)
                    self.assertEqual(state, "rolled_back")
                    self.assertEqual(tx.recover_transaction(fx.root, txid), "rolled_back")
                    self.assertFalse((fx.root / "usr/bin/hello").exists())
                    ledger_path = fx.root / tx.LEDGER_NAME
                    if ledger_path.exists():
                        self.assertEqual(json.loads(ledger_path.read_text())["records"], [])
                finally:
                    temp.cleanup()

    def test_crash_after_ledger_write_recovers_commit_not_rollback(self):
        for point in ("after_ledger_write", "before_commit_marker"):
            with self.subTest(point=point):
                temp = tempfile.TemporaryDirectory()
                fx = Fixture(temp)
                fx.add_stage_file("/usr/bin/hello", b"hello")
                try:
                    with self.assertRaises(tx.InjectedCrash):
                        fx.install(fail=self.crash_at(point))
                    txid = next((fx.root / tx.JOURNAL_DIR).iterdir()).name
                    self.assertEqual(tx.recover_transaction(fx.root, txid), "committed")
                    self.assertEqual((fx.root / "usr/bin/hello").read_bytes(), b"hello")
                    self.assertEqual(len(json.loads((fx.root / tx.LEDGER_NAME).read_text())["records"]), 1)
                finally:
                    temp.cleanup()

    def test_crash_after_live_verification_rolls_back(self):
        self.fx.add_stage_file("/usr/bin/hello", b"hello")
        with self.assertRaises(tx.InjectedCrash):
            self.fx.install(fail=self.crash_at("after_live_verify"))
        txid = next((self.fx.root / tx.JOURNAL_DIR).iterdir()).name
        self.assertEqual(tx.recover_transaction(self.fx.root, txid), "rolled_back")
        self.assertFalse((self.fx.root / "usr/bin/hello").exists())

    def test_recovery_refuses_to_overwrite_external_tampering(self):
        target = self.fx.root / "usr/bin/tool"
        target.write_bytes(b"old")
        self.fx.add_stage_file("/usr/bin/tool", b"new")
        old = tx._object(target)
        policy = self.fx.base / "replace.json"
        policy.write_text(json.dumps({"schema": "alpbahOS.m04-fixture-replace-policy/v1", "replacements": {
            "/usr/bin/tool": {"old_fingerprint": tx._fingerprint(old), "previous_owner": None}
        }}))
        with self.assertRaises(tx.InjectedCrash):
            self.fx.install(policy=policy, fail=self.crash_at("after_replace_0"))
        txid = next((self.fx.root / tx.JOURNAL_DIR).iterdir()).name
        target.write_bytes(b"external third-party edit")
        with self.assertRaisesRegex(tx.TransactionError, "unexpected object"):
            tx.recover_transaction(self.fx.root, txid)
        self.assertEqual(target.read_bytes(), b"external third-party edit")
        with self.assertRaisesRegex(tx.TransactionError, "unexpected object"):
            tx.recover_transaction(self.fx.root, txid)

    def test_corrupt_later_backup_is_detected_before_any_rollback_mutation(self):
        self.fx.add_stage_file("/usr/bin/one", b"old-one")
        self.fx.add_stage_file("/usr/bin/two", b"old-two")
        self.fx.install(name="prior-owner")

        for name in ("one", "two"):
            (self.fx.stage / "usr/bin" / name).write_bytes(f"new-{name}".encode())
        replacements = {}
        for name in ("one", "two"):
            old = tx._object(self.fx.root / "usr/bin" / name)
            replacements[f"/usr/bin/{name}"] = {
                "old_fingerprint": tx._fingerprint(old), "previous_owner": "prior-owner"
            }
        policy = self.fx.base / "replace.json"
        policy.write_text(json.dumps({
            "schema": "alpbahOS.m04-fixture-replace-policy/v1", "replacements": replacements
        }))
        with self.assertRaises(tx.InjectedCrash):
            self.fx.install(name="replacement", policy=policy, fail=self.crash_at("after_replace_1"))
        journal_path = next(
            p / "journal.json" for p in (self.fx.root / tx.JOURNAL_DIR).iterdir()
            if json.loads((p / "journal.json").read_text())["package"]["name"] == "replacement"
        )
        journal = json.loads(journal_path.read_text())
        txid = journal["transaction_id"]
        ledger_before = (self.fx.root / tx.LEDGER_NAME).read_bytes()
        objects_before = {
            name: tx._fingerprint(tx._object(self.fx.root / "usr/bin" / name))
            for name in ("one", "two")
        }
        backup = journal_path.parent / "backups/00000002.backup"
        backup.write_bytes(b"xxx-xxx")
        backup_mtime = journal["actions"][1]["before"]["backup_metadata"]["mtime_ns"]
        os.utime(backup, ns=(backup_mtime, backup_mtime))

        with self.assertRaisesRegex(tx.TransactionError, "rollback backup content mismatch"):
            tx.recover_transaction(self.fx.root, txid)
        self.assertEqual((self.fx.root / tx.LEDGER_NAME).read_bytes(), ledger_before)
        self.assertEqual({
            name: tx._fingerprint(tx._object(self.fx.root / "usr/bin" / name))
            for name in ("one", "two")
        }, objects_before)

    def test_backup_capture_mismatch_aborts_before_target_or_ledger_changes(self):
        target = self.fx.root / "usr/bin/tool"
        target.write_bytes(b"old-value")
        original = tx._object(target)
        self.fx.add_stage_file("/usr/bin/tool", b"new-value")
        policy = self.fx.base / "replace.json"
        policy.write_text(json.dumps({"schema": "alpbahOS.m04-fixture-replace-policy/v1", "replacements": {
            "/usr/bin/tool": {"old_fingerprint": tx._fingerprint(original), "previous_owner": None}
        }}))
        target_before = tx._fingerprint(tx._object(target))

        def corrupt_backup(point: str):
            if point == "after_backup_copy_1":
                backup = next((self.fx.root / tx.JOURNAL_DIR).glob("*/backups/00000001.backup"))
                info = backup.stat()
                backup.write_bytes(b"bad-value")
                os.utime(backup, ns=(info.st_atime_ns, info.st_mtime_ns))

        with self.assertRaisesRegex(tx.TransactionError, "backup copy verification failed"):
            self.fx.install(policy=policy, fail=corrupt_backup)
        self.assertEqual(tx._fingerprint(tx._object(target)), target_before)
        self.assertFalse((self.fx.root / tx.LEDGER_NAME).exists())

    def test_crash_between_two_replacements_restores_both_preimages(self):
        (self.fx.root / "usr/bin/one").write_bytes(b"before-one")
        (self.fx.root / "usr/bin/two").write_bytes(b"before-two")
        # A policy is required for both differing objects.
        self.fx.add_stage_file("/usr/bin/one", b"after-one")
        self.fx.add_stage_file("/usr/bin/two", b"after-two")
        replacements = {}
        for name in ("one", "two"):
            old = tx._object(self.fx.root / "usr/bin" / name)
            replacements[f"/usr/bin/{name}"] = {"old_fingerprint": tx._fingerprint(old), "previous_owner": None}
        policy = self.fx.base / "replace.json"
        policy.write_text(json.dumps({"schema": "alpbahOS.m04-fixture-replace-policy/v1", "replacements": replacements}))
        with self.assertRaises(tx.InjectedCrash):
            self.fx.install(policy=policy, fail=self.crash_at("after_replace_1"))
        txid = next((self.fx.root / tx.JOURNAL_DIR).iterdir()).name
        self.assertEqual(tx.recover_transaction(self.fx.root, txid), "rolled_back")
        self.assertEqual((self.fx.root / "usr/bin/one").read_bytes(), b"before-one")
        self.assertEqual((self.fx.root / "usr/bin/two").read_bytes(), b"before-two")

    def test_symlink_is_recorded_and_rolled_back(self):
        target = self.fx.root / "usr/bin/current"
        target.symlink_to("old-target")
        self.fx.stage.joinpath("usr/bin/current").symlink_to("new-target")
        old = tx._object(target)
        policy = self.fx.base / "replace.json"
        policy.write_text(json.dumps({"schema": "alpbahOS.m04-fixture-replace-policy/v1", "replacements": {
            "/usr/bin/current": {"old_fingerprint": tx._fingerprint(old), "previous_owner": None}
        }}))
        with self.assertRaises(tx.InjectedCrash):
            self.fx.install(policy=policy, fail=self.crash_at("after_replace_0"))
        txid = next((self.fx.root / tx.JOURNAL_DIR).iterdir()).name
        self.assertEqual(tx.recover_transaction(self.fx.root, txid), "rolled_back")
        self.assertTrue(target.is_symlink())
        self.assertEqual(os.readlink(target), "old-target")

    def test_refuses_unmarked_or_system_roots(self):
        with self.assertRaises(tx.TransactionError):
            tx._root(Path("/"))
        with self.assertRaises(tx.TransactionError):
            tx._root(Path("/mnt/lfs"))
        other = self.fx.base / "unmarked"
        other.mkdir()
        with self.assertRaisesRegex(tx.TransactionError, "requires exact disposable marker"):
            tx._root(other)

    def test_refuses_hardlinks_and_special_files(self):
        first = self.fx.add_stage_file("/usr/bin/a", b"linked")
        os.link(first, self.fx.stage / "usr/bin/b")
        with self.assertRaisesRegex(tx.TransactionError, "hardlinked stage"):
            self.fx.install()

    def test_refuses_fifo_stage_objects(self):
        fifo = self.fx.stage / "usr/bin/pipe"
        os.mkfifo(fifo)
        with self.assertRaisesRegex(tx.TransactionError, "unsupported stage object"):
            self.fx.install()

    def test_refuses_unsupported_xattrs(self):
        path = self.fx.add_stage_file("/usr/bin/cap", b"x")
        if not hasattr(os, "setxattr"):
            self.skipTest("xattrs unsupported by Python")
        try:
            os.setxattr(path, "user.m04-test", b"1")
        except OSError as exc:
            self.skipTest(f"filesystem does not support xattrs: {exc}")
        with self.assertRaisesRegex(tx.TransactionError, "unsupported xattrs"):
            self.fx.install()

    def test_refuses_symlinked_target_parent(self):
        outside = self.fx.base / "outside"
        outside.mkdir()
        (self.fx.root / "usr/escape").symlink_to(outside, target_is_directory=True)
        self.fx.add_stage_file("/usr/escape/file", b"no")
        with self.assertRaisesRegex(tx.TransactionError, "target parent is not a real directory"):
            self.fx.install()

    def test_refuses_missing_target_parent(self):
        self.fx.add_stage_file("/opt/missing/file", b"no")
        with self.assertRaisesRegex(tx.TransactionError, "target parent must already exist"):
            self.fx.install()


if __name__ == "__main__":
    unittest.main()
