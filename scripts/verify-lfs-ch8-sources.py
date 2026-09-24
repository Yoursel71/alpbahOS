#!/usr/bin/env python3
"""Verify the LFS 12.4-systemd Chapter 8 source archive set, read-only.

The official LFS download publishes MD5 values. This tool compares a caller's
source directory to the pinned 79-archive list and does not alter that tree.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import sys
from pathlib import Path
from typing import Any, TextIO


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = (
    REPO_ROOT
    / "docs/verification/m04-lfs-12.4-systemd-ch8-source-md5.json"
)
DEFAULT_COVERAGE = (
    REPO_ROOT
    / "docs/verification/m04-lfs-12.4-package-coverage-2026-09-24.md"
)
SCHEMA = "alpbahos-lfs-ch8-source-md5-v1"
MD5_RE = re.compile(r"^[0-9a-f]{32}$")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
OFFICIAL_MD5SUMS_URL = (
    "https://www.linuxfromscratch.org/lfs/downloads/12.4-systemd/md5sums"
)
MANIFEST_FIELDS = {
    "schema", "book", "scope", "source", "package_order_source",
    "expected_count", "entries",
}
SOURCE_FIELDS = {
    "url", "retrieved_on", "snapshot_file", "snapshot_sha256",
    "checksum_algorithm", "use",
}
ENTRY_FIELDS = {"index", "package", "archive", "md5"}


class VerificationError(ValueError):
    """The pinned manifest or its package-order evidence is invalid."""


class SourceFileChangedError(OSError):
    """A source archive changed or was replaced while being hashed."""


class NonRegularSourceError(OSError):
    """A matching source path is not a regular file."""


def _is_basename(value: str) -> bool:
    """Reject path separators and NUL regardless of the host OS."""
    return bool(value) and "/" not in value and "\\" not in value and "\0" not in value


def load_manifest(path: Path, coverage_path: Path | None = None) -> dict[str, Any]:
    """Load and validate the pinned checksum manifest and optional row order."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise VerificationError(f"cannot load manifest {path}: {error}") from error

    if not isinstance(data, dict):
        raise VerificationError("manifest root must be an object")
    if set(data) != MANIFEST_FIELDS:
        missing = sorted(MANIFEST_FIELDS - set(data))
        extra = sorted(set(data) - MANIFEST_FIELDS)
        raise VerificationError(f"manifest fields invalid: missing={missing}, extra={extra}")
    if data.get("schema") != SCHEMA:
        raise VerificationError(f"manifest schema must be {SCHEMA!r}")
    if data.get("book") != "Linux From Scratch 12.4-systemd":
        raise VerificationError("manifest book identity is invalid")
    if not isinstance(data.get("scope"), str) or not data["scope"].strip():
        raise VerificationError("manifest scope must be a nonempty string")
    entries = data.get("entries")
    expected_count = data.get("expected_count")
    if not isinstance(entries, list) or type(expected_count) is not int:
        raise VerificationError("manifest entries and expected_count are required")
    if expected_count != 79:
        raise VerificationError("this verifier requires exactly 79 Chapter 8 archives")
    if expected_count != len(entries):
        raise VerificationError(
            f"manifest expected_count={expected_count}, entries={len(entries)}"
        )

    seen_archives: set[str] = set()
    seen_packages: set[str] = set()
    for position, entry in enumerate(entries, start=1):
        if not isinstance(entry, dict):
            raise VerificationError(f"entry {position} must be an object")
        if set(entry) != ENTRY_FIELDS:
            missing = sorted(ENTRY_FIELDS - set(entry))
            extra = sorted(set(entry) - ENTRY_FIELDS)
            raise VerificationError(
                f"entry {position} fields invalid: missing={missing}, extra={extra}"
            )
        index = entry.get("index")
        package = entry.get("package")
        archive = entry.get("archive")
        digest = entry.get("md5")
        if type(index) is not int or index != position:
            raise VerificationError(
                f"entry order/index mismatch at position {position}: {index!r}"
            )
        if not isinstance(package, str) or not package.strip():
            raise VerificationError(f"entry {position} has no package identity")
        if package in seen_packages:
            raise VerificationError(f"duplicate package identity: {package}")
        seen_packages.add(package)
        if (
            not isinstance(archive, str)
            or not _is_basename(archive)
            or archive in {".", ".."}
        ):
            raise VerificationError(f"entry {position} has unsafe archive name")
        if archive in seen_archives:
            raise VerificationError(f"duplicate archive in manifest: {archive}")
        seen_archives.add(archive)
        if not isinstance(digest, str) or not MD5_RE.fullmatch(digest):
            raise VerificationError(f"entry {position} has invalid MD5: {archive}")

    source = data.get("source")
    if not isinstance(source, dict) or set(source) != SOURCE_FIELDS:
        raise VerificationError("manifest source provenance is required")
    for name in SOURCE_FIELDS:
        if not isinstance(source[name], str) or not source[name].strip():
            raise VerificationError(f"source field {name!r} must be a nonempty string")
    snapshot = source.get("snapshot_file")
    snapshot_hash = source.get("snapshot_sha256")
    if snapshot is not None or snapshot_hash is not None:
        if (
            not isinstance(snapshot, str)
            or not _is_basename(snapshot)
            or not isinstance(snapshot_hash, str)
            or not SHA256_RE.fullmatch(snapshot_hash)
        ):
            raise VerificationError("invalid checksum-source snapshot metadata")
        snapshot_path = path.parent / snapshot
        try:
            actual_hash = sha256_file(snapshot_path)
        except OSError as error:
            raise VerificationError(
                f"cannot read checksum-source snapshot {snapshot_path}: {error}"
            ) from error
        if actual_hash != snapshot_hash:
            raise VerificationError(
                f"checksum-source snapshot SHA-256 mismatch: expected={snapshot_hash} actual={actual_hash}"
            )
        if source.get("url") != OFFICIAL_MD5SUMS_URL:
            raise VerificationError("checksum source URL is not the official LFS 12.4 list")
        try:
            official_checksums = read_official_md5sums(snapshot_path)
        except (OSError, UnicodeDecodeError, VerificationError) as error:
            raise VerificationError(
                f"cannot parse official checksum snapshot {snapshot_path}: {error}"
            ) from error
        for entry in entries:
            official_md5 = official_checksums.get(entry["archive"])
            if official_md5 is None:
                raise VerificationError(
                    f"archive is absent from official checksum snapshot: {entry['archive']}"
                )
            if entry["md5"] != official_md5:
                raise VerificationError(
                    f"manifest MD5 differs from official snapshot for {entry['archive']}"
                )

    order_source = data.get("package_order_source")
    if not isinstance(order_source, str) or not _is_basename(order_source):
        raise VerificationError("package_order_source must be a basename")
    order_path = coverage_path or (path.parent / order_source)
    try:
        package_order = read_coverage_order(order_path)
    except (OSError, VerificationError) as error:
        raise VerificationError(f"cannot verify package order: {error}") from error
    manifest_order = [entry["package"] for entry in entries]
    if manifest_order != package_order:
        raise VerificationError(
            f"manifest package order differs from {order_path} rows 1-{len(entries)}"
        )
    return data


def read_coverage_order(path: Path) -> list[str]:
    """Read the first 79 ordered package labels from the M04 Markdown table."""
    order: list[tuple[int, str]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.startswith("|"):
            continue
        fields = [field.strip() for field in line.split("|")]
        if len(fields) < 4 or not fields[1].isdigit():
            continue
        index = int(fields[1])
        if index <= 79:
            order.append((index, fields[2]))
    if [index for index, _ in order] != list(range(1, 80)):
        raise VerificationError(
            f"coverage table must contain ordered rows 1-79; got {len(order)} rows"
        )
    return [package for _, package in order]


def read_official_md5sums(path: Path) -> dict[str, str]:
    """Parse strict two-space MD5 records from the official text snapshot."""
    checksums: dict[str, str] = {}
    for line_number, line in enumerate(path.read_text(encoding="ascii").splitlines(), start=1):
        if not line:
            continue
        match = re.fullmatch(r"([0-9a-f]{32})  (\S+)", line)
        if match is None:
            raise VerificationError(f"invalid md5sums record at line {line_number}")
        digest, filename = match.groups()
        if filename in checksums:
            raise VerificationError(f"duplicate filename in official md5sums: {filename}")
        checksums[filename] = digest
    if not checksums:
        raise VerificationError("official md5sums snapshot is empty")
    return checksums


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _file_signature(
    metadata: os.stat_result, *, include_change_time: bool = False
) -> tuple[int | None, ...]:
    """Portable identity; ctime is compared only through the same stat API."""
    inode = getattr(metadata, "st_ino", 0)
    signature: tuple[int | None, ...] = (
        getattr(metadata, "st_dev", None),
        inode if inode else None,
        metadata.st_size,
        getattr(metadata, "st_mtime_ns", int(metadata.st_mtime * 1_000_000_000)),
    )
    if include_change_time:
        signature += (
            getattr(metadata, "st_ctime_ns", int(metadata.st_ctime * 1_000_000_000)),
        )
    return signature


def digest_source_file(path: Path) -> tuple[str, str]:
    """Return (MD5, SHA-256) in one read and reject observed file changes."""
    # MD5 is used only to compare against the official LFS book checksum.
    md5 = hashlib.md5(usedforsecurity=False)
    sha256 = hashlib.sha256()
    before_path = path.lstat()
    if not stat.S_ISREG(before_path.st_mode):
        raise NonRegularSourceError("matching source path is not a regular file")

    with path.open("rb") as stream:
        before_fd = os.fstat(stream.fileno())
        if (
            not stat.S_ISREG(before_fd.st_mode)
            or _file_signature(before_path) != _file_signature(before_fd)
        ):
            raise SourceFileChangedError("source path changed before hashing began")
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            md5.update(block)
            sha256.update(block)
        after_fd = os.fstat(stream.fileno())

    after_path = path.lstat()
    before_signature = _file_signature(before_path)
    if (
        before_signature != _file_signature(before_fd)
        or _file_signature(before_fd, include_change_time=True)
        != _file_signature(after_fd, include_change_time=True)
        or _file_signature(before_path, include_change_time=True)
        != _file_signature(after_path, include_change_time=True)
        or before_signature != _file_signature(after_path)
    ):
        raise SourceFileChangedError("source file changed while being hashed")
    return md5.hexdigest(), sha256.hexdigest()


def index_source_files(source_dir: Path) -> tuple[dict[str, list[Path]], list[str]]:
    """Index basenames recursively without following symlink directories."""
    candidates: dict[str, list[Path]] = {}
    scan_errors: list[str] = []

    def onerror(error: OSError) -> None:
        scan_errors.append(f"{error.filename or source_dir}: {error.strerror}")

    for directory, dirnames, filenames in os.walk(
        source_dir, followlinks=False, onerror=onerror
    ):
        parent = Path(directory)
        kept_directories = []
        for dirname in dirnames:
            child = parent / dirname
            if child.is_symlink():
                scan_errors.append(f"not following symlink directory: {child}")
            else:
                kept_directories.append(dirname)
        dirnames[:] = kept_directories
        for filename in filenames:
            candidates.setdefault(filename, []).append(parent / filename)
    return candidates, scan_errors


def verify_sources(
    entries: list[dict[str, Any]], source_dir: Path
) -> tuple[list[dict[str, Any]], dict[str, int], list[str]]:
    """Hash expected source files and return per-file results and counts."""
    candidates, scan_errors = index_source_files(source_dir)
    results: list[dict[str, Any]] = []
    counts = {
        "matched": 0,
        "missing": 0,
        "duplicate": 0,
        "mismatch": 0,
        "invalid": 0,
        "changed": 0,
        "read_error": 0,
    }

    for entry in entries:
        archive = entry["archive"]
        paths = candidates.get(archive, [])
        result: dict[str, Any] = {
            "index": entry["index"],
            "package": entry["package"],
            "archive": archive,
            "expected_md5": entry["md5"],
        }
        if not paths:
            result["status"] = "MISSING"
            counts["missing"] += 1
        elif len(paths) > 1:
            result["status"] = "DUPLICATE"
            result["paths"] = [str(path) for path in sorted(paths)]
            counts["duplicate"] += 1
        else:
            path = paths[0]
            result["path"] = str(path)
            try:
                actual_md5, actual_sha256 = digest_source_file(path)
            except NonRegularSourceError as error:
                result["status"] = "INVALID"
                result["error"] = str(error)
                counts["invalid"] += 1
            except SourceFileChangedError as error:
                result["status"] = "CHANGED"
                result["error"] = str(error)
                counts["changed"] += 1
            except OSError as error:
                result["status"] = "READ_ERROR"
                result["error"] = str(error)
                counts["read_error"] += 1
            else:
                result["actual_md5"] = actual_md5
                result["actual_sha256"] = actual_sha256
                if actual_md5 == entry["md5"]:
                    result["status"] = "MATCH"
                    counts["matched"] += 1
                else:
                    result["status"] = "MISMATCH"
                    counts["mismatch"] += 1
        results.append(result)
    return results, counts, scan_errors


def emit_report(
    results: list[dict[str, Any]],
    counts: dict[str, int],
    scan_errors: list[str],
    output: TextIO,
) -> None:
    for result in results:
        output.write(json.dumps(result, ensure_ascii=False, sort_keys=True) + "\n")
    summary = {
        "type": "summary",
        "expected": len(results),
        **counts,
        "scan_errors": scan_errors,
    }
    output.write(json.dumps(summary, ensure_ascii=False, sort_keys=True) + "\n")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source-dir",
        required=True,
        type=Path,
        help="read-only directory containing source archives (searched recursively)",
    )
    parser.add_argument(
        "--manifest", type=Path, default=DEFAULT_MANIFEST,
        help=f"pinned official checksum manifest (default: {DEFAULT_MANIFEST})",
    )
    parser.add_argument(
        "--coverage", type=Path, default=DEFAULT_COVERAGE,
        help="ordered M04 Chapter 8 package table used to validate the manifest",
    )
    args = parser.parse_args(argv)

    if not args.source_dir.is_dir():
        parser.error(f"source directory does not exist or is not a directory: {args.source_dir}")
    try:
        manifest = load_manifest(args.manifest, args.coverage)
    except VerificationError as error:
        print(f"manifest error: {error}", file=sys.stderr)
        return 2

    results, counts, scan_errors = verify_sources(manifest["entries"], args.source_dir)
    emit_report(results, counts, scan_errors, sys.stdout)
    failures = any(value for key, value in counts.items() if key != "matched")
    return 1 if scan_errors or failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
