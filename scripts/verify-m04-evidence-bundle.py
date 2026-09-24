#!/usr/bin/env python3
"""Verify integrity and declared coverage of an M04 install evidence bundle.

This verifies artifact hashes and the shape of install-event assertions. It
does not prove that a command was truthful, that a trace is complete, or that
the event actually produced the declared files. Keep the evidence root trusted
and quiescent while verification runs.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import sys
from datetime import datetime
from pathlib import Path, PurePosixPath
from typing import Any


INDEX_SCHEMA = "alpbahOS.m04-install-evidence/v1"
EXPECTED_SCHEMA = "alpbahOS.m04-expected-packages/v1"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
ARTIFACTS_REQUIRED = {
    "install_log", "syscall_trace", "rootfs_before", "rootfs_after",
}
ARTIFACTS_OPTIONAL = {"stage_before", "stage_after"}


class BundleError(ValueError):
    """Invalid evidence bundle or unsafe referenced artifact."""


def _obj(value: Any, where: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise BundleError(f"{where} must be an object")
    return value


def _str(value: Any, where: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise BundleError(f"{where} must be a nonempty string")
    return value


def _sha(value: Any, where: str) -> str:
    if not isinstance(value, str) or not SHA256_RE.fullmatch(value):
        raise BundleError(f"{where} must be a lowercase SHA-256 hex digest")
    return value


def _timestamp(value: Any, where: str) -> datetime:
    text = _str(value, where)
    try:
        result = datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError as exc:
        raise BundleError(f"{where} must be an ISO-8601 timestamp") from exc
    if result.tzinfo is None or result.utcoffset() is None:
        raise BundleError(f"{where} must include a timezone")
    return result


def _artifact_file(root: Path, relative: Any, where: str) -> Path:
    raw = _str(relative, f"{where}.path")
    if "\\" in raw or ":" in raw or "\x00" in raw or raw.startswith("/"):
        raise BundleError(f"{where}.path must be a canonical relative POSIX path")
    parts = raw.split("/")
    if not parts or any(part in ("", ".", "..") for part in parts):
        raise BundleError(f"{where}.path contains an unsafe/noncanonical component")
    if PurePosixPath(raw).as_posix() != raw:
        raise BundleError(f"{where}.path is not canonical")

    candidate = root
    for index, part in enumerate(parts):
        candidate = candidate / part
        try:
            info = os.lstat(candidate)
        except OSError as exc:
            raise BundleError(f"{where}.path cannot be inspected: {raw}: {exc}") from exc
        if stat.S_ISLNK(info.st_mode):
            raise BundleError(f"{where}.path traverses a symlink: {raw}")
        if index < len(parts) - 1 and not stat.S_ISDIR(info.st_mode):
            raise BundleError(f"{where}.path parent is not a directory: {raw}")
    if not stat.S_ISREG(os.lstat(candidate).st_mode):
        raise BundleError(f"{where}.path must reference a regular file: {raw}")
    try:
        resolved = candidate.resolve(strict=True)
        resolved.relative_to(root)
    except (OSError, ValueError) as exc:
        raise BundleError(f"{where}.path escapes evidence root: {raw}") from exc
    return candidate


def _hash_artifact(root: Path, raw: Any, where: str) -> tuple[str, int]:
    artifact = _obj(raw, where)
    if set(artifact) != {"path", "sha256", "size"}:
        raise BundleError(f"{where} fields must be exactly ['path', 'sha256', 'size']")
    expected_hash = _sha(artifact["sha256"], f"{where}.sha256")
    size = artifact["size"]
    if type(size) is not int or size < 0:
        raise BundleError(f"{where}.size must be a nonnegative integer")
    path = _artifact_file(root, artifact["path"], where)
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
    try:
        fd = os.open(path, flags)
        with os.fdopen(fd, "rb") as stream:
            before = os.fstat(stream.fileno())
            if not stat.S_ISREG(before.st_mode):
                raise BundleError(f"{where} changed type while opening")
            digest = hashlib.sha256()
            actual_size = 0
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
                actual_size += len(block)
            after = os.fstat(stream.fileno())
    except OSError as exc:
        raise BundleError(f"{where} could not be read: {exc}") from exc
    signature_before = (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns)
    signature_after = (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns)
    if signature_before != signature_after:
        raise BundleError(f"{where} changed while being hashed")
    actual_hash = digest.hexdigest()
    if actual_size != size or actual_hash != expected_hash:
        raise BundleError(
            f"{where} mismatch: expected size={size} sha256={expected_hash}; "
            f"actual size={actual_size} sha256={actual_hash}"
        )
    return actual_hash, actual_size


def _validate_package(package_raw: Any, where: str) -> tuple[str, str]:
    package = _obj(package_raw, where)
    if set(package) != {"name", "version", "source", "recipe"}:
        raise BundleError(f"{where} fields must be name, version, source, recipe")
    name = _str(package["name"], f"{where}.name")
    version = _str(package["version"], f"{where}.version")
    source = _obj(package["source"], f"{where}.source")
    if set(source) != {"url", "sha256"}:
        raise BundleError(f"{where}.source fields must be url and sha256")
    url = _str(source["url"], f"{where}.source.url")
    if not url.startswith(("https://", "http://")):
        raise BundleError(f"{where}.source.url must use http(s)")
    _sha(source["sha256"], f"{where}.source.sha256")
    recipe = _obj(package["recipe"], f"{where}.recipe")
    if set(recipe) != {"identity", "sha256"}:
        raise BundleError(f"{where}.recipe fields must be identity and sha256")
    _str(recipe["identity"], f"{where}.recipe.identity")
    _sha(recipe["sha256"], f"{where}.recipe.sha256")
    return name, version


def _validate_event(event_raw: Any, index: int, root: Path) -> tuple[int, str, str]:
    where = f"events[{index}]"
    event = _obj(event_raw, where)
    required = {
        "event_id", "sequence", "package", "command", "started_at",
        "completed_at", "exit_code", "artifacts",
    }
    if set(event) != required:
        raise BundleError(f"{where} fields must be exactly {sorted(required)}")
    event_id = _str(event["event_id"], f"{where}.event_id")
    sequence = event["sequence"]
    if type(sequence) is not int or sequence < 1:
        raise BundleError(f"{where}.sequence must be a positive integer")
    name, version = _validate_package(event["package"], f"{where}.package")

    command = _obj(event["command"], f"{where}.command")
    if set(command) != {"argv", "cwd", "env"}:
        raise BundleError(f"{where}.command fields must be argv, cwd, env")
    argv = command["argv"]
    if not isinstance(argv, list) or not argv or any(not isinstance(arg, str) for arg in argv):
        raise BundleError(f"{where}.command.argv must be a nonempty string array")
    _str(command["cwd"], f"{where}.command.cwd")
    env = _obj(command["env"], f"{where}.command.env")
    if any(not isinstance(key, str) or not key or not isinstance(value, str) for key, value in env.items()):
        raise BundleError(f"{where}.command.env must map nonempty names to string values")

    started = _timestamp(event["started_at"], f"{where}.started_at")
    completed = _timestamp(event["completed_at"], f"{where}.completed_at")
    if completed < started:
        raise BundleError(f"{where}.completed_at precedes started_at")
    if type(event["exit_code"]) is not int or event["exit_code"] != 0:
        raise BundleError(f"{where}.exit_code must be 0 (successful install command)")

    artifacts = _obj(event["artifacts"], f"{where}.artifacts")
    keys = set(artifacts)
    if not ARTIFACTS_REQUIRED <= keys or not keys <= ARTIFACTS_REQUIRED | ARTIFACTS_OPTIONAL:
        raise BundleError(
            f"{where}.artifacts must include {sorted(ARTIFACTS_REQUIRED)}; "
            f"optional keys are {sorted(ARTIFACTS_OPTIONAL)}"
        )
    if ("stage_before" in keys) != ("stage_after" in keys):
        raise BundleError(f"{where} must provide both stage_before and stage_after, or neither")
    for key, artifact in artifacts.items():
        _hash_artifact(root, artifact, f"{where}.artifacts.{key}")
    return sequence, name, version


def _load_json(path: Path, where: str) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise BundleError(f"cannot read {where}: {exc}") from exc


def _expected_packages(path: Path) -> list[tuple[str, str]]:
    raw = _obj(_load_json(path, "expected package list"), "expected package list")
    if set(raw) != {"schema", "packages"} or raw.get("schema") != EXPECTED_SCHEMA:
        raise BundleError(f"expected package list schema must be {EXPECTED_SCHEMA!r}")
    packages = raw.get("packages")
    if not isinstance(packages, list) or not packages:
        raise BundleError("expected package list must contain a nonempty packages array")
    result: list[tuple[str, str]] = []
    seen: set[tuple[str, str]] = set()
    for index, item in enumerate(packages):
        obj = _obj(item, f"expected packages[{index}]")
        if set(obj) != {"name", "version"}:
            raise BundleError(f"expected packages[{index}] fields must be name and version")
        pair = (_str(obj["name"], f"expected packages[{index}].name"),
                _str(obj["version"], f"expected packages[{index}].version"))
        if pair in seen:
            raise BundleError(f"duplicate expected package: {pair[0]} {pair[1]}")
        seen.add(pair)
        result.append(pair)
    return result


def verify_bundle(index_raw: Any, evidence_root_arg: Path,
                  expected: list[tuple[str, str]] | None = None,
                  strict_coverage: bool = False) -> int:
    if strict_coverage and expected is None:
        raise BundleError("strict coverage requires an expected package list")
    if ".." in evidence_root_arg.parts:
        raise BundleError("evidence root must not contain '..' components")
    try:
        root = evidence_root_arg.resolve(strict=True)
    except OSError as exc:
        raise BundleError(f"evidence root cannot be resolved: {exc}") from exc
    if evidence_root_arg.is_symlink() or not root.is_dir():
        raise BundleError("evidence root must be a real directory, not a symlink")

    index = _obj(index_raw, "index")
    if set(index) != {"schema", "events"} or index.get("schema") != INDEX_SCHEMA:
        raise BundleError(f"index schema must be {INDEX_SCHEMA!r} with exactly schema/events fields")
    events = index.get("events")
    if not isinstance(events, list) or not events:
        raise BundleError("index.events must be a nonempty array")

    ids: set[str] = set()
    sequences: list[int] = []
    observed: list[tuple[str, str]] = []
    for event_index, event in enumerate(events):
        sequence, name, version = _validate_event(event, event_index, root)
        event_id = event["event_id"]
        if event_id in ids:
            raise BundleError(f"duplicate event_id: {event_id}")
        if sequence in sequences:
            raise BundleError(f"duplicate sequence: {sequence}")
        ids.add(event_id)
        sequences.append(sequence)
        observed.append((name, version))
    if sequences != sorted(sequences):
        raise BundleError("events must be listed in ascending sequence order")

    if strict_coverage:
        assert expected is not None
        missing = [item for item in expected if item not in observed]
        unexpected = [item for item in observed if item not in expected]
        if missing or unexpected or len(observed) != len(expected):
            raise BundleError(f"strict coverage mismatch: missing={missing}; unexpected={unexpected}")
        if observed != expected:
            raise BundleError("strict coverage requires install events in expected package order")

    print("BUNDLE_INTEGRITY_OK: referenced artifacts match their declared sizes and SHA-256 hashes.")
    print(f"events={len(events)} packages={len(set(observed))} strict_coverage={strict_coverage}")
    print("NOT_TRUTH_PROOF: hashes do not prove that commands ran, logs/traces are truthful or complete, or snapshots came from the claimed rootfs.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--index", required=True, type=Path)
    parser.add_argument("--evidence-root", required=True, type=Path)
    parser.add_argument("--expected-packages", type=Path)
    parser.add_argument("--strict-coverage", action="store_true")
    args = parser.parse_args()
    try:
        index = _load_json(args.index, "evidence index")
        expected = _expected_packages(args.expected_packages) if args.expected_packages else None
        return verify_bundle(index, args.evidence_root, expected, args.strict_coverage)
    except BundleError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
