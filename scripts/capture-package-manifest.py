#!/usr/bin/env python3
"""Capture an auditable package manifest from a completed staging tree.

This records what a staged install contains. It cannot reconstruct ownership
for packages that were previously installed directly into a root filesystem.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


SHA256_RE = re.compile(r"^[0-9a-fA-F]{64}$")


def sha256_file(path: str) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def entry_record(path: str, relative: str) -> dict[str, Any]:
    before = os.lstat(path)
    record: dict[str, Any] = {
        "path": "/" + relative,
        "mode": stat.S_IMODE(before.st_mode),
        "uid": before.st_uid,
        "gid": before.st_gid,
    }

    if stat.S_ISDIR(before.st_mode):
        record["type"] = "directory"
    elif stat.S_ISREG(before.st_mode):
        record["type"] = "file"
        record["size"] = before.st_size
        record["sha256"] = sha256_file(path)
        after = os.lstat(path)
        if (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns, before.st_mode) != (
            after.st_dev,
            after.st_ino,
            after.st_size,
            after.st_mtime_ns,
            after.st_mode,
        ):
            raise RuntimeError(f"file changed while hashing: {relative}")
    elif stat.S_ISLNK(before.st_mode):
        record["type"] = "symlink"
        record["target"] = os.readlink(path)
    elif stat.S_ISFIFO(before.st_mode):
        record["type"] = "fifo"
    elif stat.S_ISCHR(before.st_mode):
        record["type"] = "character-device"
        record["device_major"] = os.major(before.st_rdev)
        record["device_minor"] = os.minor(before.st_rdev)
    elif stat.S_ISBLK(before.st_mode):
        record["type"] = "block-device"
        record["device_major"] = os.major(before.st_rdev)
        record["device_minor"] = os.minor(before.st_rdev)
    elif stat.S_ISSOCK(before.st_mode):
        record["type"] = "socket"
    else:
        raise RuntimeError(f"unsupported filesystem entry: {relative}")
    return record


def capture_tree(root: Path) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []

    def visit(directory: Path, prefix: str = "") -> None:
        with os.scandir(directory) as iterator:
            children = sorted(iterator, key=lambda item: os.fsencode(item.name))
        for child in children:
            relative = f"{prefix}/{child.name}" if prefix else child.name
            record = entry_record(child.path, relative)
            entries.append(record)
            if record["type"] == "directory":
                visit(Path(child.path), relative)

    visit(root)
    return entries


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage", required=True, type=Path, help="completed package staging root")
    parser.add_argument("--name", required=True, help="package name")
    parser.add_argument("--version", required=True, help="package version")
    parser.add_argument("--source-url", required=True, help="source archive URL")
    parser.add_argument("--source-sha256", required=True, help="verified source archive SHA-256")
    parser.add_argument("--output", required=True, type=Path, help="manifest JSON output path")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not SHA256_RE.fullmatch(args.source_sha256):
        raise SystemExit("error: --source-sha256 must be 64 hexadecimal characters")

    stage_argument = args.stage.absolute()
    if stage_argument.is_symlink():
        raise SystemExit("error: --stage must not be a symlink")
    root = stage_argument.resolve(strict=True)
    if not root.is_dir():
        raise SystemExit("error: --stage must resolve to a real directory")
    if not args.name.strip() or not args.version.strip() or not args.source_url.strip():
        raise SystemExit("error: --name, --version and --source-url must be nonempty")
    output = args.output.resolve(strict=False)
    if output == root or root in output.parents:
        raise SystemExit("error: manifest output must be outside the staging tree")

    entries = capture_tree(root)
    if not entries:
        raise SystemExit("error: refusing to record an empty staging tree")

    manifest = {
        "schema": "alpbahOS.package-files/v1",
        "package": {
            "name": args.name,
            "version": args.version,
            "source": {
                "url": args.source_url,
                "sha256": args.source_sha256.lower(),
            },
        },
        "captured_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "entries": entries,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=output.name + ".", suffix=".tmp", dir=output.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(manifest, stream, indent=2, ensure_ascii=False, sort_keys=True)
            stream.write("\n")
        os.replace(temporary, output)
    except BaseException:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise

    counts: dict[str, int] = {}
    for entry in entries:
        kind = entry["type"]
        counts[kind] = counts.get(kind, 0) + 1
    print(f"manifest={output}")
    print(f"entries={len(entries)} types={json.dumps(counts, sort_keys=True)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
