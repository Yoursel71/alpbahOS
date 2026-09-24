#!/usr/bin/env python3
"""Build a non-authoritative final-owner projection from an M04 event chain.

Preparation prototype only. It never writes an Alp database, installs files,
or proves that commands ran. Input write sets are assertions; cryptographic
hashes establish file integrity, not truth or completeness of capture.
This prototype never emits an Alp-importable plan. Package identity-pin files
are caller assertions until an independently verified committed pin artifact
and capture chain exist. Hashes establish byte integrity, not truth.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import sys
from pathlib import Path, PurePosixPath
from typing import Any


INPUT_SCHEMA = "alpbahOS.m04-final-owner-input/v2"
SNAPSHOT_SCHEMA = "alpbahOS.m04-reconcile-snapshot/v2"
DELTA_SCHEMA = "alpbahOS.m04-reconcile-delta/v2"
OUTPUT_SCHEMA = "alpbahOS.m04-final-owner-plan/v2"
IDENTITY_PINS_SCHEMA = "alpbahOS.m04-package-identity-pins/v1"
DEFAULT_EXPECTED = Path(__file__).resolve().parents[1] / "docs/verification/manifests/lfs-base/m04-expected-chapter8-packages-12.4.json"
DEFAULT_EXPECTED_SHA256 = "612f7d8bdf54f228910c877b3a0c5d3565ead067c030ab55f9a0df472428fff5"
SHA_RE = re.compile(r"^[0-9a-f]{64}$")
CLASSIFICATIONS = {"shared", "generated", "config", "non-package"}


class ReconcileError(ValueError):
    """Malformed or inconsistent event chain; no owner plan is safe."""


def _object(value: Any, where: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ReconcileError(f"{where} must be an object")
    return value


def _string(value: Any, where: str) -> str:
    if not isinstance(value, str) or not value.strip() or "\x00" in value:
        raise ReconcileError(f"{where} must be a nonempty NUL-free string")
    return value


def _sha(value: Any, where: str) -> str:
    if not isinstance(value, str) or not SHA_RE.fullmatch(value):
        raise ReconcileError(f"{where} must be lowercase SHA-256 hex")
    return value


def _path(value: Any, where: str) -> str:
    raw = _string(value, where)
    if not raw.startswith("/") or "\\" in raw:
        raise ReconcileError(f"{where} must be a canonical absolute POSIX path")
    parts = raw[1:].split("/")
    if not parts or any(part in ("", ".", "..") for part in parts):
        raise ReconcileError(f"{where} has an unsafe or noncanonical component")
    if PurePosixPath(raw).as_posix() != raw:
        raise ReconcileError(f"{where} is not canonical")
    return raw


def _fingerprint(raw: Any, where: str) -> dict[str, Any] | None:
    if raw is None:
        return None
    obj = _object(raw, where)
    kind = obj.get("type")
    common = {"type", "mode", "uid", "gid", "metadata_support"}
    required = common | ({"size", "sha256"} if kind == "file" else
                        {"target"} if kind == "symlink" else
                        set() if kind == "directory" else
                        {"rdev"} if kind == "special" else set())
    if kind not in {"file", "symlink", "directory", "special"} or set(obj) != required:
        raise ReconcileError(f"{where} has an unsupported type or field set")
    for key in ("mode", "uid", "gid"):
        if type(obj[key]) is not int or obj[key] < 0:
            raise ReconcileError(f"{where}.{key} must be a nonnegative integer")
    if obj["mode"] > 0o7777:
        raise ReconcileError(f"{where}.mode exceeds 0o7777")
    support = _object(obj["metadata_support"], f"{where}.metadata_support")
    if set(support) != {"xattrs_sha256", "capabilities_sha256", "hardlink_count", "hardlink_group_sha256"}:
        raise ReconcileError(f"{where}.metadata_support must include xattr/capability hashes and hardlink identity fields")
    for key in ("xattrs_sha256", "capabilities_sha256", "hardlink_group_sha256"):
        if support[key] is not None:
            _sha(support[key], f"{where}.metadata_support.{key}")
    count = support["hardlink_count"]
    if count is not None and (type(count) is not int or count < 1):
        raise ReconcileError(f"{where}.metadata_support.hardlink_count must be null or a positive integer")
    if count == 1 and support["hardlink_group_sha256"] is not None:
        raise ReconcileError(f"{where}.metadata_support single-link identity must not name a group")
    if count is not None and count > 1 and support["hardlink_group_sha256"] is None:
        raise ReconcileError(f"{where}.metadata_support hardlinked object requires group identity")
    if count is None and support["hardlink_group_sha256"] is not None:
        raise ReconcileError(f"{where}.metadata_support unknown link count cannot have group identity")
    if kind == "file":
        if type(obj["size"]) is not int or obj["size"] < 0:
            raise ReconcileError(f"{where}.size must be a nonnegative integer")
        _sha(obj["sha256"], f"{where}.sha256")
    elif kind == "symlink":
        _string(obj["target"], f"{where}.target")
    elif kind == "special" and (type(obj["rdev"]) is not int or obj["rdev"] < 0):
        raise ReconcileError(f"{where}.rdev must be a nonnegative integer")
    return obj


def _entries(raw: Any, where: str) -> dict[str, dict[str, Any]]:
    obj = _object(raw, where)
    result: dict[str, dict[str, Any]] = {}
    for raw_path, raw_fp in obj.items():
        path = _path(raw_path, f"{where} path")
        fp = _fingerprint(raw_fp, f"{where}[{path}]")
        if fp is None:
            raise ReconcileError(f"{where}[{path}] cannot be null")
        result[path] = fp
    _validate_state(result, where)
    return result


def _reject_overlapping_non_directories(entries: dict[str, dict[str, Any]], where: str) -> None:
    for path, fp in entries.items():
        if fp["type"] == "directory":
            continue
        prefix = path.rstrip("/") + "/"
        child = next((candidate for candidate in entries if candidate.startswith(prefix)), None)
        if child is not None:
            raise ReconcileError(f"{where} has overlapping non-directory paths: {path} and {child}")


def _canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n").encode("utf-8")


def _snapshot_state_hash(root_id: str, entries: dict[str, dict[str, Any]]) -> str:
    return hashlib.sha256(_canonical_bytes({"schema": SNAPSHOT_SCHEMA, "root_id": root_id, "entries": entries})).hexdigest()


def _stable_json_artifact(root: Path, raw: Any, where: str) -> tuple[Any, str]:
    artifact = _object(raw, where)
    if set(artifact) != {"path", "sha256"}:
        raise ReconcileError(f"{where} fields must be exactly path and sha256")
    relative = _string(artifact["path"], f"{where}.path")
    if relative.startswith(("/", "\\")) or "\\" in relative or ":" in relative or "\x00" in relative:
        raise ReconcileError(f"{where}.path must be a relative POSIX path")
    parts = relative.split("/")
    if any(part in ("", ".", "..") for part in parts) or PurePosixPath(relative).as_posix() != relative:
        raise ReconcileError(f"{where}.path is unsafe or noncanonical")
    expected_hash = _sha(artifact["sha256"], f"{where}.sha256")
    candidate = root
    for index, part in enumerate(parts):
        candidate = candidate / part
        try:
            info = os.lstat(candidate)
        except OSError as exc:
            raise ReconcileError(f"{where} cannot be inspected: {exc}") from exc
        if stat.S_ISLNK(info.st_mode):
            raise ReconcileError(f"{where} traverses a symlink")
        if index < len(parts) - 1 and not stat.S_ISDIR(info.st_mode):
            raise ReconcileError(f"{where} parent is not a directory")
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
    try:
        fd = os.open(candidate, flags)
        with os.fdopen(fd, "rb") as stream:
            before = os.fstat(stream.fileno())
            if not stat.S_ISREG(before.st_mode):
                raise ReconcileError(f"{where} is not a regular file")
            data = stream.read()
            after = os.fstat(stream.fileno())
    except OSError as exc:
        raise ReconcileError(f"{where} cannot be read: {exc}") from exc
    signature_before = (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns)
    signature_after = (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns)
    if signature_before != signature_after:
        raise ReconcileError(f"{where} changed while being read")
    if hashlib.sha256(data).hexdigest() != expected_hash:
        raise ReconcileError(f"{where} SHA-256 mismatch")
    try:
        value = json.loads(data)
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise ReconcileError(f"{where} is not valid UTF-8 JSON: {exc}") from exc
    return value, expected_hash


def _snapshot(raw: Any, root_id: str, where: str) -> dict[str, dict[str, Any]]:
    obj = _object(raw, where)
    if set(obj) != {"schema", "root_id", "entries"} or obj["schema"] != SNAPSHOT_SCHEMA:
        raise ReconcileError(f"{where} must use {SNAPSHOT_SCHEMA}")
    if obj["root_id"] != root_id:
        raise ReconcileError(f"{where} root_id mismatch")
    return _entries(obj["entries"], f"{where}.entries")


def _expected_packages() -> list[tuple[str, str]]:
    try:
        raw_bytes = DEFAULT_EXPECTED.read_bytes()
        obj = json.loads(raw_bytes)
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ReconcileError(f"cannot read expected package list: {exc}") from exc
    if hashlib.sha256(raw_bytes).hexdigest() != DEFAULT_EXPECTED_SHA256:
        raise ReconcileError("canonical Chapter 8 package list SHA-256 mismatch")
    if not isinstance(obj, dict) or set(obj) != {"schema", "packages"}:
        raise ReconcileError("canonical expected package list has invalid fields")
    result = []
    for index, raw in enumerate(obj["packages"]):
        entry = _object(raw, f"expected packages[{index}]")
        if set(entry) != {"name", "version"}:
            raise ReconcileError(f"expected packages[{index}] has invalid fields")
        result.append((_string(entry["name"], "expected package name"),
                       _string(entry["version"], "expected package version")))
    if len(result) != 79 or len(set(result)) != 79:
        raise ReconcileError("pinned Chapter 8 package list must contain 79 unique identities")
    return result


def _load_identity_pins(path: Path, expected: list[tuple[str, str]]) -> tuple[list[dict[str, str]], str]:
    try:
        if path.is_symlink():
            raise ReconcileError("identity-pins file must not be a symlink")
        before = path.stat()
        if not stat.S_ISREG(before.st_mode):
            raise ReconcileError("identity-pins path must be a regular file")
        data = path.read_bytes()
        after = path.stat()
    except OSError as exc:
        raise ReconcileError(f"cannot read mandatory identity-pins file: {exc}") from exc
    if (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns) != (
        after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns
    ):
        raise ReconcileError("identity-pins file changed while being read")
    digest = hashlib.sha256(data).hexdigest()
    try:
        raw = json.loads(data)
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise ReconcileError(f"identity-pins file is not valid JSON: {exc}") from exc
    obj = _object(raw, "identity pins")
    if set(obj) != {"schema", "packages"} or obj["schema"] != IDENTITY_PINS_SCHEMA:
        raise ReconcileError(f"identity-pins schema must be {IDENTITY_PINS_SCHEMA}")
    packages = obj["packages"]
    if not isinstance(packages, list) or len(packages) != len(expected):
        raise ReconcileError(f"identity pins must contain exactly {len(expected)} ordered package rows")
    result: list[dict[str, str]] = []
    for index, (raw_pin, expected_identity) in enumerate(zip(packages, expected, strict=True)):
        where = f"identity pins[{index}]"
        pin = _object(raw_pin, where)
        if set(pin) != {"name", "version", "source_sha256", "recipe_identity", "recipe_sha256"}:
            raise ReconcileError(f"{where} must pin name/version/source_sha256/recipe_identity/recipe_sha256")
        if (pin["name"], pin["version"]) != expected_identity:
            raise ReconcileError(f"{where} does not match the committed 79-package order")
        _sha(pin["source_sha256"], f"{where}.source_sha256")
        _string(pin["recipe_identity"], f"{where}.recipe_identity")
        _sha(pin["recipe_sha256"], f"{where}.recipe_sha256")
        result.append(pin)
    return result, digest


def _validate_package(raw: Any, expected: tuple[str, str], pin: dict[str, str], where: str) -> dict[str, str]:
    obj = _object(raw, where)
    if set(obj) != {"name", "version", "source_sha256", "recipe_identity", "recipe_sha256"}:
        raise ReconcileError(f"{where} must contain exact name/version/source_sha256/recipe_identity/recipe_sha256 fields")
    if (obj["name"], obj["version"]) != expected:
        raise ReconcileError(f"{where} identity does not match pinned Chapter 8 order: expected {expected}")
    _sha(obj["source_sha256"], f"{where}.source_sha256")
    _string(obj["recipe_identity"], f"{where}.recipe_identity")
    _sha(obj["recipe_sha256"], f"{where}.recipe_sha256")
    if obj != pin:
        raise ReconcileError(f"{where} source/recipe identity does not exactly match mandatory verified identity pins")
    return obj


def _validate_event_header(raw: Any, index: int, expected: tuple[str, str], pin: dict[str, str], root_id: str,
                           seen_ids: set[str]) -> tuple[dict[str, Any], dict[str, str]]:
    where = f"events[{index}]"
    event = _object(raw, where)
    event_id = _string(event.get("event_id"), f"{where}.event_id")
    if event_id in seen_ids:
        raise ReconcileError(f"duplicate event_id: {event_id}")
    seen_ids.add(event_id)
    if type(event.get("sequence")) is not int or event["sequence"] != index + 1:
        raise ReconcileError(f"{where}.sequence must be {index + 1}")
    if event.get("root_id") != root_id:
        raise ReconcileError(f"{where}.root_id mismatch")
    if type(event.get("exit_code")) is not int or event["exit_code"] != 0:
        raise ReconcileError(f"{where} is failed; only exit_code 0 can be projected")
    if event.get("write_set_complete") is not True:
        raise ReconcileError(f"{where} must assert write_set_complete=true")
    package = _validate_package(event.get("package"), expected, pin, f"{where}.package")
    return event, package


def _validate_classifications(raw: Any) -> dict[str, str]:
    obj = _object(raw, "classifications")
    result: dict[str, str] = {}
    for raw_path, raw_class in obj.items():
        path = _path(raw_path, "classification path")
        if not isinstance(raw_class, str) or raw_class not in CLASSIFICATIONS:
            raise ReconcileError(f"classification for {path} must be one of {sorted(CLASSIFICATIONS)}")
        result[path] = raw_class
    return result


def _reject_alp_reserved(path: str, where: str) -> None:
    if path == "/var/lib/alp" or path.startswith("/var/lib/alp/") or path == "/var/log/alp" or path.startswith("/var/log/alp/"):
        raise ReconcileError(f"{where} uses Alp-reserved path: {path}")


def _validate_state(entries: dict[str, dict[str, Any]], where: str) -> None:
    _reject_overlapping_non_directories(entries, where)
    for path in entries:
        _reject_alp_reserved(path, where)
        parts = path.strip("/").split("/")
        for index in range(1, len(parts)):
            parent = "/" + "/".join(parts[:index])
            fingerprint = entries.get(parent)
            if fingerprint is None or fingerprint["type"] != "directory":
                raise ReconcileError(f"{where} missing directory parent or has non-directory parent: {parent} -> {path}")


def _unsupported_metadata(fingerprint: dict[str, Any]) -> list[str]:
    support = fingerprint["metadata_support"]
    unsupported = []
    if support["xattrs_sha256"] is None:
        unsupported.append("xattrs")
    if support["capabilities_sha256"] is None:
        unsupported.append("capabilities")
    if fingerprint["type"] in ("file", "symlink"):
        count = support["hardlink_count"]
        if count is None:
            unsupported.append("hardlink identity")
        elif count > 1:
            unsupported.append("hardlinked payload")
    return unsupported


def reconcile(index_raw: Any, evidence_root_arg: Path,
              identity_pins_path: Path) -> dict[str, Any]:
    root_arg = Path(evidence_root_arg)
    if ".." in root_arg.parts or root_arg.is_symlink():
        raise ReconcileError("evidence root must be a real directory without '..' components")
    try:
        evidence_root = root_arg.resolve(strict=True)
    except OSError as exc:
        raise ReconcileError(f"evidence root cannot be resolved: {exc}") from exc
    if not evidence_root.is_dir():
        raise ReconcileError("evidence root must be a directory")
    expected = _expected_packages()
    identity_pins, identity_pins_sha256 = _load_identity_pins(identity_pins_path, expected)
    index = _object(index_raw, "input")
    if set(index) != {"schema", "mode", "root_id", "classifications", "events", "baseline", "final"}:
        raise ReconcileError("input fields must be exactly schema/mode/root_id/classifications/events/baseline/final")
    if index["schema"] != INPUT_SCHEMA:
        raise ReconcileError(f"input schema must be {INPUT_SCHEMA}")
    mode = index["mode"]
    if mode not in ("snapshots", "deltas"):
        raise ReconcileError("mode must be snapshots or deltas")
    root_id = _string(index["root_id"], "root_id")
    classifications = _validate_classifications(index["classifications"])
    events_raw = index["events"]
    if not isinstance(events_raw, list) or len(events_raw) != len(expected):
        raise ReconcileError(f"input must contain exactly {len(expected)} ordered events")
    seen_ids: set[str] = set()
    histories: dict[str, list[dict[str, Any]]] = {}
    last_writer: dict[str, dict[str, str]] = {}

    if mode == "snapshots":
        if index["baseline"] is not None or index["final"] is not None:
            raise ReconcileError("snapshots mode requires baseline=null and final=null")
        state: dict[str, dict[str, Any]] | None = None
        final_state: dict[str, dict[str, Any]] = {}
        for i, (raw_event, package_expected, pin) in enumerate(zip(events_raw, expected, identity_pins, strict=True)):
            event, package = _validate_event_header(raw_event, i, package_expected, pin, root_id, seen_ids)
            if set(event) != {"sequence", "event_id", "root_id", "package", "exit_code", "write_set_complete", "before", "after", "writes"}:
                raise ReconcileError(f"events[{i}] fields invalid for snapshots mode")
            before_raw, _ = _stable_json_artifact(evidence_root, event["before"], f"events[{i}].before")
            after_raw, _ = _stable_json_artifact(evidence_root, event["after"], f"events[{i}].after")
            before = _snapshot(before_raw, root_id, f"events[{i}].before")
            after = _snapshot(after_raw, root_id, f"events[{i}].after")
            if state is not None and before != state:
                raise ReconcileError(f"event chain is not contiguous before sequence {i + 1}")
            writes = event["writes"]
            if not isinstance(writes, list):
                raise ReconcileError(f"events[{i}].writes must be an array")
            seen_write_paths: set[str] = set()
            for wi, raw_write in enumerate(writes):
                write = _object(raw_write, f"events[{i}].writes[{wi}]")
                if set(write) != {"path", "before", "after"}:
                    raise ReconcileError(f"events[{i}].writes[{wi}] fields invalid")
                path = _path(write["path"], f"events[{i}].writes[{wi}].path")
                _reject_alp_reserved(path, f"events[{i}].writes[{wi}].path")
                if path in seen_write_paths:
                    raise ReconcileError(f"duplicate write path in event {i + 1}: {path}")
                seen_write_paths.add(path)
                before_fp = _fingerprint(write["before"], f"events[{i}].writes[{wi}].before")
                after_fp = _fingerprint(write["after"], f"events[{i}].writes[{wi}].after")
                if before.get(path) != before_fp or after.get(path) != after_fp:
                    raise ReconcileError(f"write transition disagrees with event boundary snapshots: {path}")
                if before_fp == after_fp:
                    raise ReconcileError(f"no-op write lacks trusted trace evidence: {path}")
                histories.setdefault(path, []).append({"event_id": event["event_id"], "sequence": i + 1,
                                                       "package": package["name"], "before": before_fp, "after": after_fp})
                if after_fp is None:
                    last_writer.pop(path, None)
                else:
                    last_writer[path] = {"name": package["name"], "version": package["version"],
                                         "source_sha256": package["source_sha256"],
                                         "recipe_identity": package["recipe_identity"],
                                         "recipe_sha256": package["recipe_sha256"],
                                         "event_id": event["event_id"]}
            actual_changed = {p for p in set(before) | set(after) if before.get(p) != after.get(p)}
            if not actual_changed <= seen_write_paths:
                missing = sorted(actual_changed - seen_write_paths)
                raise ReconcileError(f"event {i + 1} snapshot changes lack write-set entries: {missing[:5]}")
            state = after
            _validate_state(state, f"snapshot state after event {i + 1}")
            final_state = after
    else:
        if not isinstance(index["baseline"], dict) or not isinstance(index["final"], dict):
            raise ReconcileError("deltas mode requires baseline and final snapshot artifacts")
        baseline_raw, _ = _stable_json_artifact(evidence_root, index["baseline"], "baseline")
        final_raw, _ = _stable_json_artifact(evidence_root, index["final"], "final")
        state = _snapshot(baseline_raw, root_id, "baseline")
        final_state = _snapshot(final_raw, root_id, "final")
        current_hash = _snapshot_state_hash(root_id, state)
        for i, (raw_event, package_expected, pin) in enumerate(zip(events_raw, expected, identity_pins, strict=True)):
            event, package = _validate_event_header(raw_event, i, package_expected, pin, root_id, seen_ids)
            if set(event) != {"sequence", "event_id", "root_id", "package", "exit_code", "write_set_complete", "delta"}:
                raise ReconcileError(f"events[{i}] fields invalid for deltas mode")
            delta_raw, _ = _stable_json_artifact(evidence_root, event["delta"], f"events[{i}].delta")
            delta = _object(delta_raw, f"events[{i}].delta")
            if set(delta) != {"schema", "root_id", "complete", "before_state_sha256", "after_state_sha256", "changes"}:
                raise ReconcileError(f"events[{i}].delta fields invalid")
            if delta["schema"] != DELTA_SCHEMA or delta["root_id"] != root_id or delta["complete"] is not True:
                raise ReconcileError(f"events[{i}] delta is not a complete delta for this root")
            if _sha(delta["before_state_sha256"], f"events[{i}].delta.before_state_sha256") != current_hash:
                raise ReconcileError(f"delta state chain mismatch before sequence {i + 1}")
            changes = delta["changes"]
            if not isinstance(changes, list):
                raise ReconcileError(f"events[{i}].delta.changes must be an array")
            seen_write_paths: set[str] = set()
            for ci, raw_change in enumerate(changes):
                change = _object(raw_change, f"events[{i}].delta.changes[{ci}]")
                if set(change) != {"path", "before", "after"}:
                    raise ReconcileError(f"events[{i}].delta.changes[{ci}] fields invalid")
                path = _path(change["path"], f"events[{i}].delta.changes[{ci}].path")
                _reject_alp_reserved(path, f"events[{i}].delta.changes[{ci}].path")
                if path in seen_write_paths:
                    raise ReconcileError(f"duplicate write path in event {i + 1}: {path}")
                seen_write_paths.add(path)
                before_fp = _fingerprint(change["before"], f"events[{i}].delta.changes[{ci}].before")
                after_fp = _fingerprint(change["after"], f"events[{i}].delta.changes[{ci}].after")
                if state.get(path) != before_fp:
                    raise ReconcileError(f"delta preimage mismatch at event {i + 1}: {path}")
                if before_fp == after_fp:
                    raise ReconcileError(f"no-op delta lacks trusted trace evidence: {path}")
                if after_fp is None:
                    state.pop(path, None)
                    last_writer.pop(path, None)
                else:
                    state[path] = after_fp
                    last_writer[path] = {"name": package["name"], "version": package["version"],
                                         "source_sha256": package["source_sha256"],
                                         "recipe_identity": package["recipe_identity"],
                                         "recipe_sha256": package["recipe_sha256"],
                                         "event_id": event["event_id"]}
                histories.setdefault(path, []).append({"event_id": event["event_id"], "sequence": i + 1,
                                                       "package": package["name"], "before": before_fp, "after": after_fp})
            _validate_state(state, f"delta state after event {i + 1}")
            current_hash = _snapshot_state_hash(root_id, state)
            if _sha(delta["after_state_sha256"], f"events[{i}].delta.after_state_sha256") != current_hash:
                raise ReconcileError(f"delta postimage hash mismatch after sequence {i + 1}")
        if state != final_state:
            raise ReconcileError("applied deltas do not match final inventory")

    # All final paths need an owner or explicit classification. Only files and
    # symlinks can appear in the package projection; directories/special files
    # must be classified. Untouched baseline objects are unresolved by design.
    unknown_classifications = set(classifications) - (set(final_state) | set(histories))
    if unknown_classifications:
        raise ReconcileError(f"stale/unknown classifications: {sorted(unknown_classifications)[:5]}")
    projection: dict[str, list[dict[str, Any]]] = {}
    classified: list[dict[str, Any]] = [
        {"path": path, "classification": category, "final": final_state.get(path),
         "event_written": path in histories, "history": histories.get(path, [])}
        for path, category in sorted(classifications.items())
        if path in final_state or path in histories
    ]
    unresolved: list[dict[str, str]] = []
    for path, fp in sorted(final_state.items()):
        category = classifications.get(path)
        if category is not None:
            unsupported = _unsupported_metadata(fp)
            if unsupported:
                unresolved.append({"path": path, "reason": "unsupported fingerprint metadata: " + ", ".join(unsupported)})
            continue
        owner = last_writer.get(path)
        if fp["type"] not in ("file", "symlink"):
            unresolved.append({"path": path, "reason": f"{fp['type']} path requires explicit classification"})
            continue
        if owner is None:
            unresolved.append({"path": path, "reason": "untouched baseline path has no event owner or explicit classification"})
            continue
        unsupported = _unsupported_metadata(fp)
        if unsupported:
            unresolved.append({"path": path, "reason": "unsupported fingerprint metadata: " + ", ".join(unsupported)})
            continue
        entry: dict[str, Any] = {"path": path, **fp}
        key = (owner["name"], owner["version"], owner["source_sha256"],
               owner["recipe_identity"], owner["recipe_sha256"])
        group_key = json.dumps(key, separators=(",", ":"))
        if group_key not in projection:
            projection[group_key] = [{"identity": {"name": key[0], "version": key[1],
                                                       "source_sha256": key[2], "recipe_identity": key[3],
                                                       "recipe_sha256": key[4]},
                                     "final_owner_event_id": owner["event_id"], "entries": []}]
        projection[group_key][0]["entries"].append(entry)

    owned_paths = [entry["path"] for records in projection.values() for record in records for entry in record["entries"]]
    _reject_overlapping_owned_paths(owned_paths)
    owner_records = [record for records in projection.values() for record in records]
    owner_records.sort(key=lambda record: (record["identity"]["name"], record["identity"]["version"]))
    package_dispositions = []
    unresolved_paths = {item["path"] for item in unresolved}
    for package_expected, pin in zip(expected, identity_pins, strict=True):
        name, version = package_expected
        records = [record for record in owner_records if (record["identity"]["name"], record["identity"]["version"]) == (name, version)]
        final_paths = [path for path, owner in last_writer.items()
                       if path in final_state and (owner["name"], owner["version"]) == (name, version)]
        classified_count = sum(path in classifications for path in final_paths)
        unresolved_count = sum(path in unresolved_paths for path in final_paths)
        projected_count = sum(len(record["entries"]) for record in records)
        if not final_paths:
            disposition = "no-surviving-final-paths"
        elif classified_count and unresolved_count:
            disposition = "final-paths-classified-and-unresolved"
        elif classified_count:
            disposition = "final-paths-classified"
        elif unresolved_count:
            disposition = "final-paths-unresolved"
        else:
            disposition = "owns-final-paths"
        package_dispositions.append({"name": name, "version": version,
                                     "disposition": disposition,
                                     "final_writer_path_count": len(final_paths),
                                     "classified_final_path_count": classified_count,
                                     "unresolved_final_path_count": unresolved_count,
                                     "projected_entry_count": projected_count,
                                     "alp_manifest_available": False,
                                     "manifest_note": "This prototype emits no Alp manifest.",
                                     "identity_pin_sha256": hashlib.sha256(_canonical_bytes(pin)).hexdigest()})
    plan = {
        "schema": OUTPUT_SCHEMA,
        "notice": "NOT_TRUTH_PROOF: inputs and write_set_complete flags are assertions; hashes prove byte integrity only.",
        "root_id": root_id,
        "identity_pins_sha256": identity_pins_sha256,
        "mode": mode,
        "event_count": len(events_raw),
        "status": "blocked" if unresolved else "assertions-consistent",
        "alp_importable": False,
        "readiness_basis": "caller assertions only; identity pin provenance and capture truth are not established",
        "package_dispositions": package_dispositions,
        "owners": owner_records,
        "classified_paths": classified,
        "path_history": [{"path": path, "transitions": transitions} for path, transitions in sorted(histories.items())],
        "unresolved": unresolved,
    }
    plan["plan_sha256"] = hashlib.sha256(_canonical_bytes(plan)).hexdigest()
    return plan


def _reject_overlapping_owned_paths(paths: list[str]) -> None:
    ordered = sorted(set(paths))
    if len(ordered) != len(paths):
        raise ReconcileError("final projection contains duplicate owned paths")
    for i, path in enumerate(ordered):
        prefix = path.rstrip("/") + "/"
        child = next((candidate for candidate in ordered[i + 1:] if candidate.startswith(prefix)), None)
        if child is not None:
            raise ReconcileError(f"overlapping projected owner paths: {path} and {child}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--evidence-root", required=True, type=Path)
    parser.add_argument("--identity-pins", required=True, type=Path,
                        help="separately verified exact 79-package source/recipe identity pins")
    parser.add_argument("--output", type=Path, help="write plan JSON; stdout if omitted")
    args = parser.parse_args()
    try:
        raw = json.loads(args.input.read_text(encoding="utf-8"))
        result = reconcile(raw, args.evidence_root, args.identity_pins)
    except (ReconcileError, OSError, json.JSONDecodeError) as exc:
        print(f"reconcile refused: {exc}", file=sys.stderr)
        return 2
    serialized = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.write_text(serialized, encoding="utf-8")
    else:
        sys.stdout.write(serialized)
    return 3 if result["status"] == "blocked" else 0


if __name__ == "__main__":
    raise SystemExit(main())
