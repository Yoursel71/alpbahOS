#!/usr/bin/env python3
"""Validate a rootfs ownership ledger and compare its owned objects to disk.

This is deliberately a validator, not an installer or ledger writer. A valid
ledger proves only that its declared file and symlink metadata currently match
the inspected rootfs. It does not prove that a package was historically
installed, authenticate installation-event evidence, or make removal safe.
Captured DESTDIR/stage manifests must not be converted into ownership records.
The inspected rootfs must remain quiescent and trusted for the entire check.
Traversal is path-based and is not dirfd-atomic, so concurrent path replacement
can still race checks across parent components.
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


SCHEMA = "alpbahOS.rootfs-ownership-ledger/v1"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
TXN_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{7,127}$")


class LedgerError(ValueError):
    """Invalid ledger or unsafe/inconsistent rootfs state."""


def _require_object(value: Any, context: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise LedgerError(f"{context} must be an object")
    return value


def _require_string(value: Any, context: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise LedgerError(f"{context} must be a nonempty string")
    return value


def _require_sha256(value: Any, context: str) -> str:
    if not isinstance(value, str) or not SHA256_RE.fullmatch(value):
        raise LedgerError(f"{context} must be 64 lowercase hexadecimal characters")
    return value


def _safe_ledger_path(value: Any) -> tuple[str, tuple[str, ...]]:
    path = _require_string(value, "owned path")
    if "\\" in path or "\x00" in path or not path.startswith("/"):
        raise LedgerError(f"unsafe owned path: {path!r}")
    parts = path[1:].split("/")
    if not parts or any(part in ("", ".", "..") for part in parts):
        raise LedgerError(f"unsafe or non-canonical owned path: {path!r}")
    if PurePosixPath(path).as_posix() != path:
        raise LedgerError(f"non-canonical owned path: {path!r}")
    return path, tuple(parts)


def _validate_timestamp(value: Any, context: str) -> str:
    text = _require_string(value, context)
    try:
        parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError as exc:
        raise LedgerError(f"{context} must be an ISO-8601 timestamp") from exc
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise LedgerError(f"{context} must include a timezone")
    return text


def _validate_entry(raw: Any, context: str) -> tuple[dict[str, Any], tuple[str, ...]]:
    entry = _require_object(raw, context)
    path, parts = _safe_ledger_path(entry.get("path"))
    kind = entry.get("type")
    if kind not in ("file", "symlink"):
        raise LedgerError(f"{context} {path}: only files and symlinks can be owned")
    allowed = {"path", "type", "mode", "uid", "gid"}
    allowed |= {"size", "sha256"} if kind == "file" else {"target"}
    if set(entry) != allowed:
        raise LedgerError(f"{context} {path}: fields must be exactly {sorted(allowed)}")
    for field in ("mode", "uid", "gid"):
        if type(entry.get(field)) is not int or entry[field] < 0:
            raise LedgerError(f"{context} {path}: {field} must be a nonnegative integer")
    if entry["mode"] > 0o7777:
        raise LedgerError(f"{context} {path}: mode exceeds 0o7777")
    if kind == "file":
        if type(entry.get("size")) is not int or entry["size"] < 0:
            raise LedgerError(f"{context} {path}: size must be a nonnegative integer")
        _require_sha256(entry.get("sha256"), f"{context} {path} sha256")
    else:
        target = entry.get("target")
        if not isinstance(target, str) or "\x00" in target:
            raise LedgerError(f"{context} {path}: symlink target must be a string without NUL")
    return entry, parts


def validate_ledger(raw: Any) -> list[tuple[str, tuple[str, ...], dict[str, Any]]]:
    ledger = _require_object(raw, "ledger")
    if ledger.get("schema") != SCHEMA:
        raise LedgerError(f"ledger schema must be {SCHEMA!r}")
    if set(ledger) != {"schema", "records"}:
        raise LedgerError("ledger fields must be exactly ['records', 'schema']")
    records = ledger.get("records")
    if not isinstance(records, list):
        raise LedgerError("records must be an array")

    validated: list[tuple[str, tuple[str, ...], dict[str, Any]]] = []
    seen_paths: dict[str, str] = {}
    package_ids: set[tuple[str, str, str]] = set()
    for index, raw_record in enumerate(records):
        context = f"record[{index}]"
        record = _require_object(raw_record, context)
        expected = {
            "package", "transaction_id", "recorded_at", "manifest_sha256",
            "install_evidence", "entries",
        }
        if set(record) != expected:
            raise LedgerError(f"{context} fields must be exactly {sorted(expected)}")

        package = _require_object(record.get("package"), f"{context}.package")
        if set(package) != {"name", "version", "source", "recipe"}:
            raise LedgerError(f"{context}.package has an invalid field set")
        name = _require_string(package.get("name"), f"{context}.package.name")
        version = _require_string(package.get("version"), f"{context}.package.version")
        source = _require_object(package.get("source"), f"{context}.package.source")
        if set(source) != {"url", "sha256"}:
            raise LedgerError(f"{context}.package.source fields must be url and sha256")
        source_url = _require_string(source.get("url"), f"{context}.package.source.url")
        if not source_url.startswith(("https://", "http://")):
            raise LedgerError(f"{context}.package.source.url must be http(s)")
        _require_sha256(source.get("sha256"), f"{context}.package.source.sha256")
        recipe = _require_object(package.get("recipe"), f"{context}.package.recipe")
        if set(recipe) != {"identity", "sha256"}:
            raise LedgerError(f"{context}.package.recipe fields must be identity and sha256")
        _require_string(recipe.get("identity"), f"{context}.package.recipe.identity")
        _require_sha256(recipe.get("sha256"), f"{context}.package.recipe.sha256")

        package_key = (name, version, source["sha256"])
        if package_key in package_ids:
            raise LedgerError(f"duplicate package record: {name} {version}")
        package_ids.add(package_key)

        transaction_id = _require_string(record.get("transaction_id"), f"{context}.transaction_id")
        if not TXN_RE.fullmatch(transaction_id):
            raise LedgerError(f"{context}.transaction_id has invalid syntax")
        _validate_timestamp(record.get("recorded_at"), f"{context}.recorded_at")
        _require_sha256(record.get("manifest_sha256"), f"{context}.manifest_sha256")

        # This only checks the shape of an assertion. It is not an authenticated
        # proof that the recorded command actually installed these files.
        evidence = _require_object(record.get("install_evidence"), f"{context}.install_evidence")
        if set(evidence) != {"kind", "status", "uri", "sha256", "completed_at"}:
            raise LedgerError(f"{context}.install_evidence has an invalid field set")
        if evidence.get("kind") != "install-log" or evidence.get("status") != "claimed-complete":
            raise LedgerError(f"{context}.install_evidence must be an install-log claimed-complete assertion")
        _require_string(evidence.get("uri"), f"{context}.install_evidence.uri")
        _require_sha256(evidence.get("sha256"), f"{context}.install_evidence.sha256")
        _validate_timestamp(evidence.get("completed_at"), f"{context}.install_evidence.completed_at")

        entries = record.get("entries")
        if not isinstance(entries, list) or not entries:
            raise LedgerError(f"{context}.entries must be a nonempty array")
        for entry_index, raw_entry in enumerate(entries):
            entry, parts = _validate_entry(raw_entry, f"{context}.entries[{entry_index}]")
            path = entry["path"]
            if path in seen_paths:
                raise LedgerError(
                    f"duplicate ownership for {path}: {seen_paths[path]} and {name}; multi-owner policy is disabled"
                )
            for existing, owner in seen_paths.items():
                if existing.startswith(path.rstrip("/") + "/") or path.startswith(existing.rstrip("/") + "/"):
                    raise LedgerError(f"overlapping owned paths: {existing} ({owner}) and {path} ({name})")
            seen_paths[path] = name
            validated.append((name, parts, entry))
    return validated


def _stat_signature(info: os.stat_result) -> tuple[int, ...]:
    return (
        info.st_dev,
        info.st_ino,
        info.st_size,
        info.st_mtime_ns,
        # Windows exposes creation time as st_ctime and lstat/fstat may report
        # different sub-microsecond values. Linux ctime remains a useful change
        # detector for the intended rootfs validator.
        0 if os.name == "nt" else info.st_ctime_ns,
        info.st_mode,
        info.st_uid,
        info.st_gid,
    )


def _hash_file(path: Path, expected_info: os.stat_result) -> tuple[int, str]:
    digest = hashlib.sha256()
    flags = os.O_RDONLY | getattr(os, "O_BINARY", 0) | getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open(path, flags)
    try:
        opened = os.fstat(descriptor)
        if not stat.S_ISREG(opened.st_mode):
            raise LedgerError(f"owned file changed type while opening: {path}")
        with os.fdopen(descriptor, "rb", closefd=False) as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
        after = os.fstat(descriptor)
        path_after = os.lstat(path)
    finally:
        os.close(descriptor)
    if not (
        _stat_signature(expected_info)
        == _stat_signature(opened)
        == _stat_signature(after)
        == _stat_signature(path_after)
    ):
        raise LedgerError(f"file changed while hashing: {path}")
    return opened.st_size, digest.hexdigest()


def _inspect_entry(root: Path, parts: tuple[str, ...], expected: dict[str, Any]) -> dict[str, Any]:
    current = root
    for component in parts[:-1]:
        current = current / component
        try:
            info = os.lstat(current)
        except FileNotFoundError:
            raise LedgerError(f"missing path component: {current}") from None
        if not stat.S_ISDIR(info.st_mode):
            raise LedgerError(f"non-directory or symlink path component: {current}")
    target = current / parts[-1]
    try:
        info = os.lstat(target)
    except FileNotFoundError:
        raise LedgerError(f"owned path is missing: {expected['path']}") from None
    actual: dict[str, Any] = {
        "path": expected["path"],
        "mode": stat.S_IMODE(info.st_mode),
        "uid": info.st_uid,
        "gid": info.st_gid,
    }
    if stat.S_ISREG(info.st_mode):
        size, digest = _hash_file(target, info)
        actual.update(type="file", size=size, sha256=digest)
    elif stat.S_ISLNK(info.st_mode):
        link_target = os.readlink(target)
        after = os.lstat(target)
        if _stat_signature(info) != _stat_signature(after) or os.readlink(target) != link_target:
            raise LedgerError(f"symlink changed while inspecting: {target}")
        actual.update(type="symlink", target=link_target)
    else:
        actual["type"] = "directory" if stat.S_ISDIR(info.st_mode) else "special"
    return actual


def validate_rootfs(raw: Any, root_argument: Path) -> int:
    if ".." in root_argument.parts:
        raise LedgerError("--root must not contain '..' path components")
    root = Path(os.path.abspath(os.fspath(root_argument)))
    current = Path(root.anchor)
    for component in root.parts[1:]:
        current = current / component
        try:
            info = os.lstat(current)
        except FileNotFoundError:
            raise LedgerError(f"--root path does not exist: {current}") from None
        if stat.S_ISLNK(info.st_mode):
            raise LedgerError(f"--root has a symlinked component: {current}")
        if current != root and not stat.S_ISDIR(info.st_mode):
            raise LedgerError(f"--root has a non-directory ancestor: {current}")
    if not stat.S_ISDIR(os.lstat(root).st_mode):
        raise LedgerError("--root must resolve to a directory")
    validated = validate_ledger(raw)
    mismatches = 0
    for package, parts, expected in validated:
        actual = _inspect_entry(root, parts, expected)
        if actual != expected:
            mismatches += 1
            print(f"MISMATCH package={package} path={expected['path']}")
            print(f"  expected: {json.dumps(expected, sort_keys=True)}")
            print(f"  actual:   {json.dumps(actual, sort_keys=True)}")
    print("CONSISTENCY_ONLY: this command checks ledger structure and current rootfs agreement.")
    print(f"records={len(raw['records'])} owned_paths={len(validated)} mismatched={mismatches}")
    if raw["records"]:
        print("NOT_OWNERSHIP_PROOF: install-event assertions are unauthenticated; this does not prove historical installation or authorize removal.")
    else:
        print("EMPTY_LEDGER_BOOTSTRAP: no package ownership is recorded.")
    print("QUIESCENCE_REQUIRED: keep --root trusted and unchanged during the check; traversal is path-based, not dirfd-atomic.")
    return mismatches


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__,
        epilog="A successful check is never ownership proof. Empty ledgers return status 3.",
    )
    parser.add_argument("--ledger", required=True, type=Path)
    parser.add_argument("--root", required=True, type=Path)
    args = parser.parse_args()
    try:
        raw = json.loads(args.ledger.read_text(encoding="utf-8"))
        mismatches = validate_rootfs(raw, args.root)
    except (OSError, json.JSONDecodeError, LedgerError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    if not raw["records"] and mismatches == 0:
        return 3
    return 1 if mismatches else 0


if __name__ == "__main__":
    raise SystemExit(main())
