#!/usr/bin/env python3
"""Read-only comparison of a staged package manifest with a root filesystem."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import stat
import sys
from pathlib import Path
from typing import Any


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def record_path(path: Path, relative: str) -> dict[str, Any]:
    info = os.lstat(path)
    record: dict[str, Any] = {
        "path": "/" + relative,
        "mode": stat.S_IMODE(info.st_mode),
        "uid": info.st_uid,
        "gid": info.st_gid,
    }
    if stat.S_ISDIR(info.st_mode):
        record["type"] = "directory"
    elif stat.S_ISREG(info.st_mode):
        record["type"] = "file"
        record["size"] = info.st_size
        record["sha256"] = sha256_file(path)
    elif stat.S_ISLNK(info.st_mode):
        record["type"] = "symlink"
        record["target"] = os.readlink(path)
    elif stat.S_ISFIFO(info.st_mode):
        record["type"] = "fifo"
    elif stat.S_ISCHR(info.st_mode):
        record["type"] = "character-device"
        record["device_major"] = os.major(info.st_rdev)
        record["device_minor"] = os.minor(info.st_rdev)
    elif stat.S_ISBLK(info.st_mode):
        record["type"] = "block-device"
        record["device_major"] = os.major(info.st_rdev)
        record["device_minor"] = os.minor(info.st_rdev)
    elif stat.S_ISSOCK(info.st_mode):
        record["type"] = "socket"
    else:
        raise ValueError(f"unsupported filesystem object: {path}")
    return record


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--root", required=True, type=Path, help="root filesystem to inspect")
    args = parser.parse_args()

    root = args.root.resolve(strict=True)
    if not root.is_dir():
        parser.error("--root must resolve to a directory")
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    entries = manifest.get("entries")
    if not isinstance(entries, list) or not entries:
        parser.error("manifest must contain a nonempty entries list")

    seen: set[str] = set()
    mismatches = 0
    for expected in entries:
        relative = expected.get("path")
        if not isinstance(relative, str) or not relative.startswith("/"):
            parser.error(f"invalid manifest path: {relative!r}")
        parts = Path(relative).parts[1:]
        if not parts or any(part in (".", "..") for part in parts):
            parser.error(f"unsafe manifest path: {relative!r}")
        if relative in seen:
            parser.error(f"duplicate manifest path: {relative}")
        seen.add(relative)
        target = root.joinpath(*parts)
        try:
            actual = record_path(target, "/".join(parts))
        except FileNotFoundError:
            actual = None
        if actual != expected:
            mismatches += 1
            print(f"MISMATCH {relative}")
            print(f"  expected: {json.dumps(expected, sort_keys=True)}")
            print(f"  actual:   {json.dumps(actual, sort_keys=True) if actual else 'MISSING'}")

    print(
        f"package={manifest.get('package', {}).get('name', '<unknown>')} "
        f"version={manifest.get('package', {}).get('version', '<unknown>')} "
        f"entries={len(entries)} matched={len(entries) - mismatches} mismatched={mismatches}"
    )
    return 1 if mismatches else 0


if __name__ == "__main__":
    sys.exit(main())
