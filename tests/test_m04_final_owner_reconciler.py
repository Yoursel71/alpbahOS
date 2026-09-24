"""Synthetic tests for the non-authoritative M04 owner-plan reconciler."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from typing import Any


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "reconcile-m04-final-owners.py"
SPEC = importlib.util.spec_from_file_location("m04_final_owner_reconciler", SCRIPT)
reconcile_module = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(reconcile_module)


def file_fp(content: str, mode: int = 0o644) -> dict[str, Any]:
    data = content.encode()
    return {"type": "file", "mode": mode, "uid": 0, "gid": 0,
            "size": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            "metadata_support": {"xattrs_sha256": hashlib.sha256(b"[]").hexdigest(),
                                 "capabilities_sha256": hashlib.sha256(b"[]").hexdigest(),
                                 "hardlink_count": 1, "hardlink_group_sha256": None}}


def directory_fp(mode: int = 0o755) -> dict[str, Any]:
    return {"type": "directory", "mode": mode, "uid": 0, "gid": 0,
            "metadata_support": {"xattrs_sha256": hashlib.sha256(b"[]").hexdigest(),
                                 "capabilities_sha256": hashlib.sha256(b"[]").hexdigest(),
                                 "hardlink_count": None, "hardlink_group_sha256": None}}


def special_fp(special_type: str, rdev: int = 0) -> dict[str, Any]:
    return {"type": "special", "special_type": special_type, "mode": 0o644,
            "uid": 0, "gid": 0, "rdev": rdev,
            "metadata_support": {"xattrs_sha256": hashlib.sha256(b"[]").hexdigest(),
                                 "capabilities_sha256": hashlib.sha256(b"[]").hexdigest(),
                                 "hardlink_count": 1, "hardlink_group_sha256": None}}


class ReconcileFixture:
    def __init__(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="m04-final-owner-")
        self.root = Path(self.temp.name)
        self.root_id = "candidate-clone-2026-09-24-a"
        self.expected = reconcile_module._expected_packages()
        self.identity_pins = []
        for sequence, (name, version) in enumerate(self.expected, 1):
            self.identity_pins.append({"name": name, "version": version,
                                       "source_sha256": f"{sequence:064x}",
                                       "recipe_identity": f"synthetic-recipe:{name}:{version}",
                                       "recipe_sha256": f"{sequence + 1000:064x}"})
        self.identity_pins_path = self.root / "identity-pins.json"
        self.identity_pins_path.write_text(json.dumps({
            "schema": reconcile_module.IDENTITY_PINS_SCHEMA,
            "packages": self.identity_pins,
        }, sort_keys=True), encoding="utf-8")
        self.baseline = {
            "/etc": directory_fp(),
            "/etc/issue": file_fp("base issue\n"),
            "/usr": directory_fp(),
            "/usr/bin": directory_fp(),
            "/usr/bin/stale": file_fp("preexisting\n"),
            "/usr/bin/tool": file_fp("old tool\n"),
            "/usr/share": directory_fp(),
            "/usr/share/doc": directory_fp(),
        }
        self.classifications = {
            "/etc": "shared",
            "/etc/issue": "config",
            "/usr/bin/stale": "non-package",
            "/usr": "shared",
            "/usr/bin": "shared",
            "/usr/share": "shared",
            "/usr/share/doc": "shared",
        }
        self.events = []
        self.states = [self.baseline]
        current = self.baseline
        for sequence, (name, version) in enumerate(self.expected, 1):
            after = dict(current)
            writes = []
            if sequence == 1:
                after["/usr/bin/tool"] = file_fp("tool v1\n")
                writes = [{"path": "/usr/bin/tool", "before": current["/usr/bin/tool"],
                           "after": after["/usr/bin/tool"]}]
            elif sequence == 2:
                after["/usr/bin/tool"] = file_fp("tool v2\n")
                writes = [{"path": "/usr/bin/tool", "before": current["/usr/bin/tool"],
                           "after": after["/usr/bin/tool"]}]
            elif sequence == 3:
                del after["/usr/bin/stale"]
                writes = [{"path": "/usr/bin/stale", "before": current["/usr/bin/stale"], "after": None}]
            event = {
                "sequence": sequence,
                "event_id": f"event-{sequence:02d}",
                "root_id": self.root_id,
                "package": {"name": name, "version": version,
                            "source_sha256": self.identity_pins[sequence - 1]["source_sha256"],
                            "recipe_identity": self.identity_pins[sequence - 1]["recipe_identity"],
                            "recipe_sha256": self.identity_pins[sequence - 1]["recipe_sha256"]},
                "exit_code": 0,
                "write_set_complete": True,
                "writes": writes,
                "before": self.artifact(f"snapshot/{sequence:02d}-before.json", self.snapshot(current)),
                "after": self.artifact(f"snapshot/{sequence:02d}-after.json", self.snapshot(after)),
            }
            self.events.append(event)
            self.states.append(after)
            current = after
        self.input = {"schema": reconcile_module.INPUT_SCHEMA, "mode": "snapshots",
                      "root_id": self.root_id, "classifications": self.classifications,
                      "events": self.events, "baseline": None, "final": None}

    def snapshot(self, entries: dict[str, dict[str, Any]]) -> dict[str, Any]:
        return {"schema": reconcile_module.SNAPSHOT_SCHEMA, "root_id": self.root_id,
                "entries": entries}

    def artifact(self, name: str, value: Any) -> dict[str, str]:
        data = (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return {"path": name, "sha256": hashlib.sha256(data).hexdigest()}

    def run(self, data: dict[str, Any] | None = None) -> dict[str, Any]:
        return reconcile_module.reconcile(data or self.input, self.root, self.identity_pins_path)

    def close(self) -> None:
        self.temp.cleanup()


class FinalOwnerReconcilerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.fx = ReconcileFixture()

    def tearDown(self) -> None:
        self.fx.close()

    def test_special_fingerprint_requires_and_preserves_node_subtype(self) -> None:
        fifo = reconcile_module._fingerprint(special_fp("fifo"), "fifo")
        socket = reconcile_module._fingerprint(special_fp("socket"), "socket")
        self.assertEqual(fifo["rdev"], socket["rdev"])
        self.assertNotEqual(fifo, socket)
        legacy = special_fp("fifo")
        del legacy["special_type"]
        with self.assertRaisesRegex(reconcile_module.ReconcileError, "unsupported type or field set"):
            reconcile_module._fingerprint(legacy, "legacy special")
        invalid = special_fp("unknown")
        with self.assertRaisesRegex(reconcile_module.ReconcileError, "special_type is unsupported"):
            reconcile_module._fingerprint(invalid, "invalid special")

    def test_snapshot_v2_is_rejected_with_special_node_compatibility_reason(self) -> None:
        legacy = self.fx.snapshot(self.fx.baseline)
        legacy["schema"] = "alpbahOS.m04-reconcile-snapshot/v2"
        with self.assertRaisesRegex(reconcile_module.ReconcileError,
                                   "unsupported snapshot schema.*v2.*does not record special-node subtypes"):
            reconcile_module._snapshot(legacy, self.fx.root_id, "legacy v2 snapshot")

    def test_snapshot_chain_projects_last_writer_and_keeps_deletion_history(self) -> None:
        result = self.fx.run()
        self.assertEqual(result["status"], "assertions-consistent")
        self.assertFalse(result["alp_importable"])
        self.assertEqual(result["event_count"], 79)
        self.assertIn("NOT_TRUTH_PROOF", result["notice"])
        self.assertEqual(len(result["owners"]), 1)
        record = result["owners"][0]
        self.assertEqual(record["identity"]["name"], self.fx.expected[1][0])
        self.assertEqual(record["final_owner_event_id"], "event-02")
        self.assertEqual(record["entries"][0]["path"], "/usr/bin/tool")
        stale = next(item for item in result["path_history"] if item["path"] == "/usr/bin/stale")
        self.assertIsNone(stale["transitions"][-1]["after"])
        self.assertEqual({item["path"]: item["classification"] for item in result["classified_paths"]}["/usr/share/doc"], "shared")
        self.assertEqual(result["unresolved"], [])
        self.assertEqual(len(result["package_dispositions"]), 79)
        self.assertTrue(all(item["alp_manifest_available"] is False for item in result["package_dispositions"]))
        self.assertTrue(any(item["disposition"] == "no-surviving-final-paths" for item in result["package_dispositions"]))

    def test_untouched_baseline_without_classification_blocks_projection(self) -> None:
        self.fx.input["classifications"].pop("/etc/issue")
        result = self.fx.run()
        self.assertEqual(result["status"], "blocked")
        self.assertTrue(any(item["path"] == "/etc/issue" for item in result["unresolved"]))

    def test_snapshot_mode_rejects_noncontiguous_state_chain(self) -> None:
        wrong_entries = dict(self.fx.states[1])
        wrong_entries["/usr/bin/tool"] = file_fp("unexpected\n")
        wrong = self.fx.snapshot(wrong_entries)
        self.fx.events[1]["before"] = self.fx.artifact("snapshot/wrong-before.json", wrong)
        with self.assertRaisesRegex(reconcile_module.ReconcileError, "not contiguous"):
            self.fx.run()

    def test_rejects_failed_event_and_wrong_package_order(self) -> None:
        self.fx.events[0]["exit_code"] = 1
        with self.assertRaisesRegex(reconcile_module.ReconcileError, "failed"):
            self.fx.run()
        self.fx.events[0]["exit_code"] = 0
        self.fx.events[0]["package"]["name"] = "wrong-package"
        with self.assertRaisesRegex(reconcile_module.ReconcileError, "pinned Chapter 8 order"):
            self.fx.run()

    def test_rejects_source_or_recipe_identity_not_in_separate_pins(self) -> None:
        self.fx.events[0]["package"]["source_sha256"] = "f" * 64
        with self.assertRaisesRegex(reconcile_module.ReconcileError, "does not exactly match"):
            self.fx.run()

    def test_rejects_incomplete_identity_pin_set(self) -> None:
        pins = json.loads(self.fx.identity_pins_path.read_text(encoding="utf-8"))
        pins["packages"].pop()
        self.fx.identity_pins_path.write_text(json.dumps(pins), encoding="utf-8")
        with self.assertRaisesRegex(reconcile_module.ReconcileError, "exactly 79 ordered"):
            self.fx.run()

    def test_rejects_incomplete_write_set_and_malicious_path(self) -> None:
        self.fx.events[0]["writes"] = []
        with self.assertRaisesRegex(reconcile_module.ReconcileError, "lack write-set"):
            self.fx.run()
        self.fx.events[0]["writes"] = [{"path": "/usr/bin/../escape", "before": None, "after": None}]
        with self.assertRaisesRegex(reconcile_module.ReconcileError, "unsafe or noncanonical"):
            self.fx.run()

    def test_rejects_noop_writes_without_trusted_trace_and_alp_reserved_paths(self) -> None:
        same = self.fx.states[3]["/usr/bin/tool"]
        self.fx.events[3]["writes"] = [{"path": "/usr/bin/tool", "before": same, "after": same}]
        with self.assertRaisesRegex(reconcile_module.ReconcileError, "no-op write"):
            self.fx.run()
        self.fx.events[3]["writes"] = [{"path": "/var/lib/alp/db.json", "before": None, "after": None}]
        with self.assertRaisesRegex(reconcile_module.ReconcileError, "Alp-reserved path"):
            self.fx.run()

    def test_rejects_stale_classification_and_reports_classified_writer(self) -> None:
        self.fx.input["classifications"]["/opt/not-present"] = "non-package"
        with self.assertRaisesRegex(reconcile_module.ReconcileError, "stale/unknown classifications"):
            self.fx.run()
        del self.fx.input["classifications"]["/opt/not-present"]
        self.fx.input["classifications"]["/usr/bin/tool"] = "shared"
        result = self.fx.run()
        row = next(item for item in result["classified_paths"] if item["path"] == "/usr/bin/tool")
        self.assertTrue(row["event_written"])
        self.assertEqual(row["history"][-1]["event_id"], "event-02")
        writer = result["package_dispositions"][1]
        self.assertEqual(writer["disposition"], "final-paths-classified")
        self.assertEqual(writer["final_writer_path_count"], 1)
        self.assertEqual(writer["classified_final_path_count"], 1)
        self.assertEqual(writer["projected_entry_count"], 0)

    def test_unsupported_metadata_is_unresolved_and_not_projected(self) -> None:
        # Mark the last package's final payload as lacking capability/xattr
        # fingerprinting, while preserving all event-boundary consistency.
        final_state = dict(self.fx.states[3])
        final_fp = dict(final_state["/usr/bin/tool"])
        final_support = dict(final_fp["metadata_support"])
        final_support["xattrs_sha256"] = None
        final_fp["metadata_support"] = final_support
        final_state["/usr/bin/tool"] = final_fp
        self.fx.events[2]["before"] = self.fx.artifact("snapshot/03-before-unsupported.json", self.fx.snapshot(self.fx.states[2]))
        self.fx.events[2]["after"] = self.fx.artifact("snapshot/03-after-unsupported.json", self.fx.snapshot(final_state))
        self.fx.events[2]["writes"] = [
            {"path": "/usr/bin/tool", "before": self.fx.states[2]["/usr/bin/tool"],
             "after": final_fp},
            {"path": "/usr/bin/stale", "before": self.fx.states[2]["/usr/bin/stale"],
             "after": None},
        ]
        for index in range(3, len(self.fx.events)):
            self.fx.events[index]["before"] = self.fx.artifact(
                f"snapshot/{index + 1:02d}-before-unsupported.json", self.fx.snapshot(final_state))
            self.fx.events[index]["after"] = self.fx.artifact(
                f"snapshot/{index + 1:02d}-after-unsupported.json", self.fx.snapshot(final_state))
            self.fx.events[index]["writes"] = []
            self.fx.states[index] = final_state
        self.fx.states[-1] = final_state
        result = self.fx.run()
        self.assertEqual(result["status"], "blocked")
        self.assertEqual(result["owners"], [])
        self.assertTrue(any(item["path"] == "/usr/bin/tool" and "xattrs" in item["reason"]
                            for item in result["unresolved"]))
        writer = result["package_dispositions"][2]
        self.assertEqual(writer["disposition"], "final-paths-unresolved")
        self.assertEqual(writer["final_writer_path_count"], 1)
        self.assertEqual(writer["unresolved_final_path_count"], 1)

    def test_rejects_artifact_hash_mismatch(self) -> None:
        path = self.fx.root / self.fx.events[0]["after"]["path"]
        path.write_text("{}\n", encoding="utf-8")
        with self.assertRaisesRegex(reconcile_module.ReconcileError, "SHA-256 mismatch"):
            self.fx.run()

    def test_delta_mode_reconciles_complete_preimage_postimage_and_final_inventory(self) -> None:
        state = self.fx.baseline
        events = []
        for original in self.fx.events:
            sequence = original["sequence"]
            after = self.fx.states[sequence]
            changes = original["writes"]
            before_hash = reconcile_module._snapshot_state_hash(self.fx.root_id, state)
            # Delta inputs are complete path transitions, including deletions.
            delta = {"schema": reconcile_module.DELTA_SCHEMA, "root_id": self.fx.root_id,
                     "complete": True, "before_state_sha256": before_hash,
                     "after_state_sha256": reconcile_module._snapshot_state_hash(self.fx.root_id, after),
                     "changes": changes}
            events.append({key: original[key] for key in
                           ("sequence", "event_id", "root_id", "package", "exit_code", "write_set_complete")}
                          | {"delta": self.fx.artifact(f"delta/{sequence:02d}.json", delta)})
            state = after
        index = {"schema": reconcile_module.INPUT_SCHEMA, "mode": "deltas", "root_id": self.fx.root_id,
                 "classifications": self.fx.classifications, "events": events,
                 "baseline": self.fx.artifact("baseline.json", self.fx.snapshot(self.fx.baseline)),
                 "final": self.fx.artifact("final.json", self.fx.snapshot(state))}
        result = self.fx.run(index)
        self.assertEqual(result["status"], "assertions-consistent")
        self.assertFalse(result["alp_importable"])
        self.assertEqual(result["owners"][0]["final_owner_event_id"], "event-02")

    def test_delta_mode_rejects_incomplete_or_broken_state_chain(self) -> None:
        # Build a minimal well-formed first delta; validation must reject the
        # completeness assertion before emitting a projection.
        state = self.fx.baseline
        after = self.fx.states[1]
        delta = {"schema": reconcile_module.DELTA_SCHEMA, "root_id": self.fx.root_id,
                 "complete": False,
                 "before_state_sha256": reconcile_module._snapshot_state_hash(self.fx.root_id, state),
                 "after_state_sha256": reconcile_module._snapshot_state_hash(self.fx.root_id, after),
                 "changes": self.fx.events[0]["writes"]}
        events = []
        for i, original in enumerate(self.fx.events):
            delta_path = self.fx.artifact(f"incomplete/{i:02d}.json", delta if i == 0 else {
                "schema": reconcile_module.DELTA_SCHEMA, "root_id": self.fx.root_id, "complete": True,
                "before_state_sha256": "0" * 64, "after_state_sha256": "0" * 64, "changes": []})
            events.append({key: original[key] for key in
                           ("sequence", "event_id", "root_id", "package", "exit_code", "write_set_complete")}
                          | {"delta": delta_path})
        index = {"schema": reconcile_module.INPUT_SCHEMA, "mode": "deltas", "root_id": self.fx.root_id,
                 "classifications": self.fx.classifications, "events": events,
                 "baseline": self.fx.artifact("baseline2.json", self.fx.snapshot(self.fx.baseline)),
                 "final": self.fx.artifact("final2.json", self.fx.snapshot(self.fx.states[-1]))}
        with self.assertRaisesRegex(reconcile_module.ReconcileError, "not a complete delta"):
            self.fx.run(index)
        delta["complete"] = True
        first = json.loads((self.fx.root / "incomplete/00.json").read_text())
        first["complete"] = True
        (self.fx.root / "incomplete/00.json").write_text(json.dumps(first), encoding="utf-8")
        events[0]["delta"]["sha256"] = hashlib.sha256((self.fx.root / "incomplete/00.json").read_bytes()).hexdigest()
        with self.assertRaisesRegex(reconcile_module.ReconcileError, "state chain mismatch"):
            self.fx.run(index)

    def test_delta_mode_validates_parent_tree_after_each_event(self) -> None:
        state = self.fx.baseline
        events = []
        for sequence, original in enumerate(self.fx.events, 1):
            after = self.fx.states[sequence]
            changes = original["writes"]
            if sequence == 1:
                after = dict(after)
                del after["/usr/bin"]
                changes = [{"path": "/usr/bin", "before": state["/usr/bin"], "after": None}]
            delta = {"schema": reconcile_module.DELTA_SCHEMA, "root_id": self.fx.root_id,
                     "complete": True,
                     "before_state_sha256": reconcile_module._snapshot_state_hash(self.fx.root_id, state),
                     "after_state_sha256": reconcile_module._snapshot_state_hash(self.fx.root_id, after),
                     "changes": changes}
            events.append({key: original[key] for key in
                           ("sequence", "event_id", "root_id", "package", "exit_code", "write_set_complete")}
                          | {"delta": self.fx.artifact(f"tree-delta/{sequence:02d}.json", delta)})
            state = after
        index = {"schema": reconcile_module.INPUT_SCHEMA, "mode": "deltas", "root_id": self.fx.root_id,
                 "classifications": self.fx.classifications, "events": events,
                 "baseline": self.fx.artifact("tree-baseline.json", self.fx.snapshot(self.fx.baseline)),
                 "final": self.fx.artifact("tree-final.json", self.fx.snapshot(state))}
        with self.assertRaisesRegex(reconcile_module.ReconcileError, "missing directory parent"):
            self.fx.run(index)


if __name__ == "__main__":
    unittest.main()
