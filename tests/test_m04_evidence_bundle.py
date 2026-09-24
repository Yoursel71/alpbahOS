"""Cross-platform fixture tests for the M04 evidence bundle verifier."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "verify-m04-evidence-bundle.py"
SPEC = importlib.util.spec_from_file_location("m04_evidence", SCRIPT)
verify = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(verify)


class EvidenceBundleTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name) / "evidence"
        self.root.mkdir()
        self.index = {"schema": verify.INDEX_SCHEMA, "events": [self.event(1, "alpha", "1.0")]}

    def tearDown(self) -> None:
        self.temp.cleanup()

    def artifact(self, name: str, content: bytes) -> dict:
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        return {"path": name, "sha256": hashlib.sha256(content).hexdigest(), "size": len(content)}

    def event(self, sequence: int, name: str, version: str) -> dict:
        artifacts = {
            "install_log": self.artifact(f"event-{sequence}/install.log", b"make install: ok\n"),
            "syscall_trace": self.artifact(f"event-{sequence}/trace.log", b"openat(...)=0\n"),
            "rootfs_before": self.artifact(f"event-{sequence}/root-before.json", b"{}\n"),
            "rootfs_after": self.artifact(f"event-{sequence}/root-after.json", b"{}\n"),
        }
        return {
            "event_id": f"m04-{sequence:04d}", "sequence": sequence,
            "package": {
                "name": name, "version": version,
                "source": {"url": "https://example.invalid/pkg.tar.xz", "sha256": "a" * 64},
                "recipe": {"identity": f"LFS Chapter 8 {name}", "sha256": "b" * 64},
            },
            "command": {"argv": ["make", "install"], "cwd": "/sources/pkg", "env": {"DESTDIR": "/stage"}},
            "started_at": "2026-09-24T10:00:00Z", "completed_at": "2026-09-24T10:00:01Z",
            "exit_code": 0, "artifacts": artifacts,
        }

    def test_accepts_integral_bundle_and_reports_integrity_only(self) -> None:
        self.assertEqual(verify.verify_bundle(self.index, self.root), 0)

    def test_rejects_artifact_hash_mismatch(self) -> None:
        artifact = self.index["events"][0]["artifacts"]["install_log"]
        (self.root / artifact["path"]).write_bytes(b"changed")
        with self.assertRaisesRegex(verify.BundleError, "mismatch"):
            verify.verify_bundle(self.index, self.root)

    def test_rejects_traversal_and_absolute_paths(self) -> None:
        for unsafe in ("../outside", "/absolute", "event\\trace", "C:/outside"):
            with self.subTest(path=unsafe):
                bad = json.loads(json.dumps(self.index))
                bad["events"][0]["artifacts"]["install_log"]["path"] = unsafe
                with self.assertRaises(verify.BundleError):
                    verify.verify_bundle(bad, self.root)

    def test_rejects_symlink_artifact(self) -> None:
        original = self.root / "event-1/install.log"
        target = self.root / "real.log"
        target.write_bytes(original.read_bytes())
        original.unlink()
        try:
            original.symlink_to(target)
        except (OSError, NotImplementedError):
            self.skipTest("symlink creation is unavailable on this host")
        with self.assertRaisesRegex(verify.BundleError, "symlink"):
            verify.verify_bundle(self.index, self.root)

    def test_rejects_nonzero_or_missing_command_exit(self) -> None:
        self.index["events"][0]["exit_code"] = 1
        with self.assertRaisesRegex(verify.BundleError, "exit_code"):
            verify.verify_bundle(self.index, self.root)

    def test_rejects_missing_provenance(self) -> None:
        del self.index["events"][0]["package"]["recipe"]
        with self.assertRaisesRegex(verify.BundleError, "package fields"):
            verify.verify_bundle(self.index, self.root)

    def test_requires_paired_stage_snapshots(self) -> None:
        self.index["events"][0]["artifacts"]["stage_before"] = self.artifact("stage/before.json", b"{}")
        with self.assertRaisesRegex(verify.BundleError, "both stage_before"):
            verify.verify_bundle(self.index, self.root)

    def test_strict_coverage_requires_exact_ordered_package_list(self) -> None:
        expected = [("alpha", "1.0"), ("beta", "2.0")]
        self.index["events"].append(self.event(2, "beta", "2.0"))
        self.assertEqual(verify.verify_bundle(self.index, self.root, expected, True), 0)
        with self.assertRaisesRegex(verify.BundleError, "expected package order"):
            verify.verify_bundle(self.index, self.root, list(reversed(expected)), True)

    def test_strict_coverage_rejects_missing_and_extra_events(self) -> None:
        with self.assertRaisesRegex(verify.BundleError, "coverage mismatch"):
            verify.verify_bundle(self.index, self.root, [("alpha", "1.0"), ("beta", "2.0")], True)

    def test_strict_coverage_requires_expected_list(self) -> None:
        with self.assertRaisesRegex(verify.BundleError, "requires an expected"):
            verify.verify_bundle(self.index, self.root, strict_coverage=True)


if __name__ == "__main__":
    unittest.main()
