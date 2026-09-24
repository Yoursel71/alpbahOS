#!/usr/bin/env python3
"""Adapt one fixture capture event to the integrity-only evidence bundle format.

This utility is fixture-only. It does not authenticate provenance or capture,
and deliberately refuses final-owner reconciliation because the capture runner
does not establish a complete, exclusive write set.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import re
import stat
import sys
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any


CAPTURE_SCHEMA = "alpbahOS.m04-install-event-capture/v1"
PROVENANCE_SCHEMA = "alpbahOS.m04-capture-adapter-provenance/v1"
BUNDLE_SCHEMA = "alpbahOS.m04-install-evidence/v1"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
VERIFIER_PATH = Path(__file__).with_name("verify-m04-evidence-bundle.py")


class AdapterError(ValueError):
    """The capture record lacks fields needed for an honest conversion."""


def _load_verifier() -> Any:
    spec = importlib.util.spec_from_file_location("m04_bundle_verifier_for_adapter", VERIFIER_PATH)
    if spec is None or spec.loader is None:
        raise AdapterError(f"cannot load evidence bundle verifier: {VERIFIER_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _read_json(path: Path, label: str) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise AdapterError(f"cannot read {label}: {exc}") from exc


def _safe_artifact(root: Path, raw: Any, label: str) -> tuple[Path, dict[str, Any]]:
    if not isinstance(raw, dict) or set(raw) != {"path", "size", "sha256"}:
        raise AdapterError(f"{label} must contain capture artifact path/size/sha256")
    relative = raw["path"]
    if (not isinstance(relative, str) or not relative or relative.startswith(("/", "\\"))
            or "\\" in relative or ":" in relative or "\x00" in relative):
        raise AdapterError(f"{label}.path must be a relative POSIX path")
    parts = relative.split("/")
    if any(part in ("", ".", "..") for part in parts) or PurePosixPath(relative).as_posix() != relative:
        raise AdapterError(f"{label}.path is unsafe or noncanonical")
    candidate = root
    for index, part in enumerate(parts):
        candidate = candidate / part
        try:
            info = os.lstat(candidate)
        except OSError as exc:
            raise AdapterError(f"{label} cannot be inspected: {exc}") from exc
        if stat.S_ISLNK(info.st_mode):
            raise AdapterError(f"{label} traverses a symlink")
        if index < len(parts) - 1 and not stat.S_ISDIR(info.st_mode):
            raise AdapterError(f"{label} parent is not a directory")
    if not stat.S_ISREG(os.lstat(candidate).st_mode):
        raise AdapterError(f"{label} must be a regular file")
    # Reuse the verifier's no-follow, stable-read, size and hash checks.
    try:
        _load_verifier()._hash_artifact(root, raw, label)
    except Exception as exc:
        raise AdapterError(f"{label} failed evidence verifier integrity checks: {exc}") from exc
    return candidate, raw


def _iso_from_ns(value: Any, label: str) -> str:
    if type(value) is not int or value < 0:
        raise AdapterError(f"capture {label} must be a nonnegative integer nanosecond timestamp")
    seconds, nanos = divmod(value, 1_000_000_000)
    try:
        stamp = datetime.fromtimestamp(seconds, tz=timezone.utc).replace(microsecond=nanos // 1000)
    except (OverflowError, OSError, ValueError) as exc:
        raise AdapterError(f"capture {label} is outside the supported timestamp range") from exc
    return stamp.isoformat(timespec="microseconds").replace("+00:00", "Z")


def _validate_capture(raw: Any) -> dict[str, Any]:
    if not isinstance(raw, dict) or raw.get("schema") != CAPTURE_SCHEMA:
        raise AdapterError(f"event schema must be {CAPTURE_SCHEMA}")
    required = {"schema", "event_id", "root_id", "event_dir", "package", "version", "argv",
                "cwd", "environment", "started_unix_ns", "ended_unix_ns", "exit_status",
                "changed_paths", "outside_root_write_attempts", "inputs", "artifacts"}
    if not required <= set(raw):
        raise AdapterError(f"capture event is missing fields: {sorted(required - set(raw))}")
    if type(raw["exit_status"]) is not int or raw["exit_status"] != 0:
        raise AdapterError("failed capture events cannot be adapted")
    if raw["outside_root_write_attempts"]:
        raise AdapterError("capture reports outside-root write attempts")
    if not isinstance(raw["package"], str) or not raw["package"].strip():
        raise AdapterError("capture package name is missing")
    if not isinstance(raw["version"], str) or not raw["version"].strip():
        raise AdapterError("capture package version is missing")
    if (not isinstance(raw["argv"], list) or not raw["argv"]
            or any(not isinstance(arg, str) for arg in raw["argv"])):
        raise AdapterError("capture argv must be a nonempty string array")
    if not isinstance(raw["environment"], dict) or any(
            not isinstance(k, str) or not isinstance(v, str) for k, v in raw["environment"].items()):
        raise AdapterError("capture environment must map strings to strings")
    return raw


def _input_hash(event: dict[str, Any], path_key: str) -> str:
    inputs = event.get("inputs")
    if not isinstance(inputs, list):
        raise AdapterError("capture inputs must be an array")
    path = path_key
    matches = [item for item in inputs if isinstance(item, dict) and item.get("path") == path]
    if len(matches) != 1:
        raise AdapterError(f"provenance input path must match exactly one captured input: {path}")
    digest = matches[0].get("sha256")
    if not isinstance(digest, str) or not SHA256_RE.fullmatch(digest):
        raise AdapterError(f"captured input has an invalid SHA-256: {path}")
    return digest


def _mkdirs_without_symlinks(root: Path, relative_dir: str) -> Path:
    current = root
    for part in relative_dir.split("/"):
        current = current / part
        try:
            info = os.lstat(current)
        except FileNotFoundError:
            try:
                current.mkdir()
            except FileExistsError:
                pass
            info = os.lstat(current)
        except OSError as exc:
            raise AdapterError(f"cannot inspect adapter output directory {current}: {exc}") from exc
        if stat.S_ISLNK(info.st_mode) or not stat.S_ISDIR(info.st_mode):
            raise AdapterError(f"adapter output directory is not a real directory: {current}")
    return current


def adapt_bundle_event(event_raw: Any, provenance_raw: Any, evidence_root_arg: Path) -> dict[str, Any]:
    event = _validate_capture(event_raw)
    if not isinstance(provenance_raw, dict) or set(provenance_raw) != {
            "schema", "sequence", "source_url", "source_input_path", "recipe_identity", "recipe_input_path"}:
        raise AdapterError("provenance must contain schema/sequence/source_url/source_input_path/recipe_identity/recipe_input_path")
    if provenance_raw["schema"] != PROVENANCE_SCHEMA:
        raise AdapterError(f"provenance schema must be {PROVENANCE_SCHEMA}")
    sequence = provenance_raw["sequence"]
    if type(sequence) is not int or sequence < 1:
        raise AdapterError("provenance sequence must be a positive integer")
    source_url, recipe_identity = provenance_raw["source_url"], provenance_raw["recipe_identity"]
    if not isinstance(source_url, str) or not source_url.startswith(("https://", "http://")):
        raise AdapterError("source_url must be an explicit http(s) provenance assertion")
    if not isinstance(recipe_identity, str) or not recipe_identity.strip():
        raise AdapterError("recipe_identity must be an explicit provenance assertion")
    source_hash = _input_hash(event, provenance_raw["source_input_path"])
    recipe_hash = _input_hash(event, provenance_raw["recipe_input_path"])

    root_arg = Path(evidence_root_arg)
    if ".." in root_arg.parts or root_arg.is_symlink():
        raise AdapterError("evidence root must be a real directory without '..' components")
    try:
        root = root_arg.resolve(strict=True)
    except OSError as exc:
        raise AdapterError(f"evidence root cannot be resolved: {exc}") from exc
    if not root.is_dir():
        raise AdapterError("evidence root must be a directory")
    artifacts = event.get("artifacts")
    if not isinstance(artifacts, dict):
        raise AdapterError("capture artifacts must be an object")
    artifact_paths: dict[str, tuple[Path, dict[str, Any]]] = {}
    for key in ("before_snapshot", "after_snapshot", "stdout", "stderr", "strace"):
        if key not in artifacts:
            raise AdapterError(f"capture is missing required artifact {key}")
        artifact_paths[key] = _safe_artifact(root, artifacts[key], f"capture.artifacts.{key}")

    stdout = artifact_paths["stdout"][0].read_bytes()
    stderr = artifact_paths["stderr"][0].read_bytes()
    log_bytes = b"=== stdout ===\n" + stdout + b"\n=== stderr ===\n" + stderr
    event_id = event.get("event_id")
    if not isinstance(event_id, str) or not re.fullmatch(r"[A-Za-z0-9._-]+", event_id):
        raise AdapterError("event_id must be a safe filename component")
    log_relative = f"adapter-output/{event_id}/install.log"
    log_path = root / log_relative
    _mkdirs_without_symlinks(root, f"adapter-output/{event_id}")
    if log_path.exists() or log_path.is_symlink():
        if log_path.is_symlink() or not log_path.is_file() or log_path.read_bytes() != log_bytes:
            raise AdapterError(f"refusing to overwrite existing adapter artifact: {log_path}")
    else:
        try:
            with log_path.open("xb") as stream:
                stream.write(log_bytes)
        except FileExistsError as exc:
            raise AdapterError(f"adapter artifact appeared during creation: {log_path}") from exc
    log_artifact = {"path": log_relative, "size": len(log_bytes),
                    "sha256": hashlib.sha256(log_bytes).hexdigest()}

    def bundle_artifact(key: str) -> dict[str, Any]:
        raw = artifact_paths[key][1]
        return {"path": raw["path"], "size": raw["size"], "sha256": raw["sha256"]}

    return {
        "event_id": event_id,
        "sequence": sequence,
        "package": {
            "name": event["package"], "version": event["version"],
            "source": {"url": source_url, "sha256": source_hash},
            "recipe": {"identity": recipe_identity, "sha256": recipe_hash},
        },
        "command": {"argv": event["argv"], "cwd": event["cwd"], "env": event["environment"]},
        "started_at": _iso_from_ns(event["started_unix_ns"], "started_unix_ns"),
        "completed_at": _iso_from_ns(event["ended_unix_ns"], "ended_unix_ns"),
        "exit_code": event["exit_status"],
        "artifacts": {
            "install_log": log_artifact,
            "syscall_trace": bundle_artifact("strace"),
            "rootfs_before": bundle_artifact("before_snapshot"),
            "rootfs_after": bundle_artifact("after_snapshot"),
        },
    }


def refuse_reconciliation() -> None:
    raise AdapterError(
        "refusing reconciler conversion: this fixture runner cannot establish a complete, "
        "exclusive write set or attribute concurrent tree changes to the install command. "
        "Its trace parser skips unknown syscall records and does not deny io_uring; snapshots "
        "are path-based and lack a quiescent-root/exclusive-lock guarantee. A complete 79-event "
        "chain, independently pinned package identities, and a validated complete observation "
        "boundary are still required. No write_set_complete=true assertion was generated."
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--event", type=Path, required=True)
    parser.add_argument("--evidence-root", type=Path, required=True)
    parser.add_argument("--provenance", type=Path)
    parser.add_argument("--bundle-index-out", type=Path)
    parser.add_argument("--reconcile", action="store_true",
                        help="check whether an owner-reconciler conversion is permitted (currently refused)")
    args = parser.parse_args()
    try:
        event = _read_json(args.event, "capture event")
        if args.reconcile:
            refuse_reconciliation()
        if args.provenance is None or args.bundle_index_out is None:
            raise AdapterError("bundle conversion requires --provenance and --bundle-index-out")
        provenance = _read_json(args.provenance, "adapter provenance")
        adapted = adapt_bundle_event(event, provenance, args.evidence_root)
        index = {"schema": BUNDLE_SCHEMA, "events": [adapted]}
        args.bundle_index_out.parent.mkdir(parents=True, exist_ok=True)
        args.bundle_index_out.write_text(json.dumps(index, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(f"WROTE_INTEGRITY_ONLY_BUNDLE_INDEX: {args.bundle_index_out}")
        print("NOT_TRUTH_PROOF: package provenance and capture contents remain caller assertions.")
        return 0
    except AdapterError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
