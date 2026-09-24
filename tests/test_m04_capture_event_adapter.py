"""Tests for the fixture-only capture-to-bundle adapter."""

from __future__ import annotations

import hashlib
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
ADAPTER_SCRIPT = ROOT / "scripts" / "adapt-m04-capture-event.py"
ADAPTER_SPEC = importlib.util.spec_from_file_location("m04_capture_adapter", ADAPTER_SCRIPT)
adapter = importlib.util.module_from_spec(ADAPTER_SPEC)
assert ADAPTER_SPEC and ADAPTER_SPEC.loader
ADAPTER_SPEC.loader.exec_module(adapter)
VERIFIER_SCRIPT = ROOT / "scripts" / "verify-m04-evidence-bundle.py"
VERIFIER_SPEC = importlib.util.spec_from_file_location("m04_bundle_verifier_for_adapter_test", VERIFIER_SCRIPT)
verifier = importlib.util.module_from_spec(VERIFIER_SPEC)
assert VERIFIER_SPEC and VERIFIER_SPEC.loader
VERIFIER_SPEC.loader.exec_module(verifier)


class CaptureEventAdapterTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="m04-capture-adapter-")
        self.root = Path(self.temp.name)
        self.artifact_dir = self.root / ".m04-capture" / "events" / "event-1"
        self.artifact_dir.mkdir(parents=True)
        self.event_path = self.root / "capture-event.json"
        self.source_path = "/fixture/source.tar.xz"
        self.recipe_path = "/fixture/recipe.sh"
        source_hash = "a" * 64
        recipe_hash = "b" * 64
        self.event: dict[str, Any] = {
            "schema": adapter.CAPTURE_SCHEMA,
            "event_id": "event-1",
            "root_id": "0" * 32,
            "event_dir": ".m04-capture/events/event-1",
            "seccomp_architecture": "x86_64",
            "package": "alpha",
            "version": "1.0",
            "argv": ["make", "install"],
            "cwd": "/fixture/.m04-capture/work/event-1",
            "environment": {"DESTDIR": "/fixture"},
            "started_unix_ns": 1_790_000_000_123_456_789,
            "ended_unix_ns": 1_790_000_001_987_654_321,
            "exit_status": 0,
            "changed_paths": ["/usr/bin/alpha"],
            "outside_root_write_attempts": [],
            "observation_violations": [],
            "inputs": [
                {"path": self.source_path, "sha256": source_hash},
                {"path": self.recipe_path, "sha256": recipe_hash},
            ],
            "artifacts": {},
        }
        for key, content in {
            "before_snapshot": b'{"before":true}\n',
            "after_snapshot": b'{"after":true}\n',
            "stdout": b"install stdout\n",
            "stderr": b"install stderr\n",
            "strace": b"openat(...)=0\n",
            "seccomp_policy": adapter._expected_seccomp_policy("x86_64"),
        }.items():
            path = self.artifact_dir / f"{key}.dat"
            path.write_bytes(content)
            relative = path.relative_to(self.root).as_posix()
            self.event["artifacts"][key] = {
                "path": relative, "size": len(content), "sha256": hashlib.sha256(content).hexdigest(),
            }
        self.provenance = {
            "schema": adapter.PROVENANCE_SCHEMA,
            "sequence": 1,
            "source_url": "https://example.invalid/alpha-1.0.tar.xz",
            "source_input_path": self.source_path,
            "recipe_identity": "test recipe alpha 1.0",
            "recipe_input_path": self.recipe_path,
        }

    def _write_event_and_manifest(self) -> None:
        event_bytes = (json.dumps(self.event, sort_keys=True) + "\n").encode("utf-8")
        self.event_path.write_bytes(event_bytes)
        manifest = {
            "schema": adapter.EVENT_MANIFEST_SCHEMA,
            "event_path": self.event_path.relative_to(self.root).as_posix(),
            "size": len(event_bytes),
            "sha256": hashlib.sha256(event_bytes).hexdigest(),
        }
        self.event_path.with_name(self.event_path.name + ".manifest.json").write_text(
            json.dumps(manifest, sort_keys=True) + "\n", encoding="utf-8")

    def _adapt(self) -> dict[str, Any]:
        self._write_event_and_manifest()
        return adapter.adapt_bundle_event(self.event, self.provenance, self.root, self.event_path)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_adapted_event_is_accepted_by_integrity_verifier(self) -> None:
        event = self._adapt()
        index = {"schema": adapter.BUNDLE_SCHEMA, "events": [event]}
        self.assertEqual(verifier.verify_bundle(index, self.root), 0)
        self.assertEqual(event["artifacts"]["syscall_trace"], {
            "path": self.event["artifacts"]["strace"]["path"],
            "size": self.event["artifacts"]["strace"]["size"],
            "sha256": self.event["artifacts"]["strace"]["sha256"],
        })
        self.assertEqual(event["artifacts"]["confinement_policy"], {
            "path": self.event["artifacts"]["seccomp_policy"]["path"],
            "size": self.event["artifacts"]["seccomp_policy"]["size"],
            "sha256": self.event["artifacts"]["seccomp_policy"]["sha256"],
        })
        combined = (self.root / event["artifacts"]["install_log"]["path"]).read_bytes()
        self.assertIn(b"=== stdout ===", combined)
        self.assertIn(b"=== stderr ===", combined)

    def test_cli_writes_verifier_accepted_bundle_index(self) -> None:
        event_path = self.event_path
        provenance_path = self.root / "provenance.json"
        output_path = self.root / "adapted-index.json"
        self._write_event_and_manifest()
        provenance_path.write_text(json.dumps(self.provenance), encoding="utf-8")
        argv = [str(ADAPTER_SCRIPT), "--event", str(event_path), "--evidence-root", str(self.root),
                "--provenance", str(provenance_path), "--bundle-index-out", str(output_path)]
        with mock.patch.object(sys, "argv", argv), mock.patch.object(sys, "stdout", new_callable=io.StringIO):
            self.assertEqual(adapter.main(), 0)

        index = json.loads(output_path.read_text(encoding="utf-8"))
        self.assertEqual(verifier.verify_bundle(index, self.root), 0)

    def test_source_and_recipe_hashes_must_match_captured_inputs(self) -> None:
        self.provenance["recipe_input_path"] = "/fixture/other-recipe.sh"
        with self.assertRaisesRegex(adapter.AdapterError, "match exactly one captured input"):
            self._adapt()

    def test_adapter_refuses_failed_or_escape_attempt_events(self) -> None:
        original = self.event
        failed = dict(original, exit_status=1)
        with self.assertRaisesRegex(adapter.AdapterError, "failed capture"):
            self.event = failed
            self._adapt()
        escaped = dict(original, outside_root_write_attempts=["fixture escape"])
        with self.assertRaisesRegex(adapter.AdapterError, "outside-root"):
            self.event = escaped
            self._adapt()
        incomplete = dict(original, observation_violations=["io_uring_setup was used"])
        with self.assertRaisesRegex(adapter.AdapterError, "incomplete observation"):
            self.event = incomplete
            self._adapt()
        self.event = original

    def test_adapter_rejects_artifact_hash_mismatch(self) -> None:
        changed = self.artifact_dir / "strace.dat"
        changed.write_bytes(b"tampered")
        with self.assertRaisesRegex(adapter.AdapterError, "integrity checks"):
            self._adapt()

    def test_adapter_rejects_unexpected_seccomp_policy(self) -> None:
        policy = self.artifact_dir / "seccomp_policy.dat"
        policy.write_bytes(b"allow everything")
        self.event["artifacts"]["seccomp_policy"]["size"] = policy.stat().st_size
        self.event["artifacts"]["seccomp_policy"]["sha256"] = hashlib.sha256(policy.read_bytes()).hexdigest()
        with self.assertRaisesRegex(adapter.AdapterError, "not the required io_uring-deny filter"):
            self._adapt()

    def test_adapter_rejects_missing_event_manifest(self) -> None:
        self.event_path.write_text(json.dumps(self.event), encoding="utf-8")
        with self.assertRaisesRegex(adapter.AdapterError, "capture event manifest cannot be inspected"):
            adapter.adapt_bundle_event(self.event, self.provenance, self.root, self.event_path)

    def test_adapter_rejects_tampered_manifest_and_event_bytes(self) -> None:
        self._write_event_and_manifest()
        sidecar = self.event_path.with_name(self.event_path.name + ".manifest.json")
        manifest = json.loads(sidecar.read_text(encoding="utf-8"))
        manifest["sha256"] = "f" * 64
        sidecar.write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(adapter.AdapterError, "capture event manifest mismatch"):
            adapter.adapt_bundle_event(self.event, self.provenance, self.root, self.event_path)

        self._write_event_and_manifest()
        with self.event_path.open("ab") as stream:
            stream.write(b" ")
        with self.assertRaisesRegex(adapter.AdapterError, "capture event manifest mismatch"):
            adapter.adapt_bundle_event(self.event, self.provenance, self.root, self.event_path)

    def test_reconciliation_is_refused_without_complete_capture_boundary(self) -> None:
        with self.assertRaisesRegex(adapter.AdapterError, "cannot establish a complete, exclusive write set"):
            adapter.refuse_reconciliation()


if __name__ == "__main__":
    unittest.main()
