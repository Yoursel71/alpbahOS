#!/usr/bin/env python3
"""Read-only identity and mount-boundary preflight for a D34 candidate root.

This tool does not install packages or modify the candidate. It takes the
shared LFS writer lock while validating the expected Btrfs identities, then
releases it at process exit. A future replay runner must hold this same lock
for its entire transaction and use this module's checks before each phase.
"""

from __future__ import annotations

import argparse
import fcntl
import json
import os
import re
import stat
import subprocess
import sys
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator


DEFAULT_LOCK = Path("/mnt/alpbahOS-data/alpbahOS-build/locks/lfs-build-writer.lock")
MNT_LFS = Path("/mnt/lfs")


class CandidatePreflightError(RuntimeError):
    pass


def _run(argv: list[str]) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(argv, check=True, capture_output=True, text=True)
    except (OSError, subprocess.CalledProcessError) as exc:
        detail = getattr(exc, "stderr", "") or str(exc)
        raise CandidatePreflightError(f"command failed: {argv[0]}: {detail.strip()}") from exc


def _refuse_symlink_components(path: Path) -> Path:
    raw = Path(os.path.abspath(os.fspath(path)))
    cursor = Path(raw.anchor)
    for component in raw.parts[1:]:
        cursor /= component
        try:
            info = os.lstat(cursor)
        except FileNotFoundError as exc:
            raise CandidatePreflightError(f"candidate path component is missing: {cursor}") from exc
        if stat.S_ISLNK(info.st_mode):
            raise CandidatePreflightError(f"candidate path contains symlink component: {cursor}")
    return raw


def _decode_mountinfo_path(raw: str) -> Path:
    # proc(5) encodes space, tab, newline and backslash as octal escapes.
    decoded = re.sub(r"\\(040|011|012|134)", lambda match: chr(int(match.group(1), 8)), raw)
    return Path(decoded)


def _nested_mounts(root: Path) -> list[dict[str, str]]:
    nested = []
    try:
        lines = Path("/proc/self/mountinfo").read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        raise CandidatePreflightError(f"cannot read mount table: {exc}") from exc
    for line in lines:
        fields = line.split()
        if len(fields) < 7:
            raise CandidatePreflightError("malformed /proc/self/mountinfo record")
        mount_id, mountpoint = fields[0], _decode_mountinfo_path(fields[4])
        try:
            relative = mountpoint.relative_to(root)
        except ValueError:
            continue
        if relative.parts:
            nested.append({"mount_id": mount_id, "mountpoint": str(mountpoint)})
    return nested


def inspect_candidate(root_arg: Path, expected_fs_uuid: str,
                      expected_subvolume_uuid: str) -> dict[str, object]:
    root = _refuse_symlink_components(root_arg)
    if root == Path("/") or root == MNT_LFS or MNT_LFS in root.parents:
        raise CandidatePreflightError("refusing /, /mnt/lfs, or any descendant of /mnt/lfs")
    if not root.is_dir():
        raise CandidatePreflightError("candidate root must be a directory")

    mount_data = json.loads(_run([
        "findmnt", "--json", "--target", str(root), "--output",
        "ID,SOURCE,FSTYPE,UUID,TARGET,FSROOT",
    ]).stdout)
    filesystems = mount_data.get("filesystems")
    if not isinstance(filesystems, list) or len(filesystems) != 1:
        raise CandidatePreflightError("findmnt did not return exactly one containing mount")
    mount = filesystems[0]
    if mount.get("fstype") != "btrfs":
        raise CandidatePreflightError(f"candidate filesystem is {mount.get('fstype')!r}, not btrfs")
    if mount.get("uuid") != expected_fs_uuid:
        raise CandidatePreflightError(
            f"candidate filesystem UUID mismatch: expected {expected_fs_uuid}, got {mount.get('uuid')}"
        )

    subvolume_text = _run(["sudo", "-n", "btrfs", "subvolume", "show", str(root)]).stdout
    subvolume_id_match = re.search(r"^\s*Subvolume ID:\s+(\d+)\s*$", subvolume_text, re.MULTILINE)
    subvolume_uuid_match = re.search(r"^\s*UUID:\s+([0-9a-f-]{36})\s*$", subvolume_text, re.MULTILINE)
    if not subvolume_id_match or not subvolume_uuid_match:
        raise CandidatePreflightError("candidate path is not a Btrfs subvolume root")
    subvolume_uuid = subvolume_uuid_match.group(1)
    if subvolume_uuid != expected_subvolume_uuid:
        raise CandidatePreflightError(
            f"candidate subvolume UUID mismatch: expected {expected_subvolume_uuid}, got {subvolume_uuid}"
        )

    nested = _nested_mounts(root)
    if nested:
        raise CandidatePreflightError(f"nested mounts under candidate root: {nested}")
    info = os.stat(root, follow_symlinks=False)
    return {
        "schema": "alpbahOS.d34-candidate-preflight/v1",
        "root": str(root),
        "root_device": info.st_dev,
        "root_inode": info.st_ino,
        "filesystem": {
            "type": mount["fstype"], "uuid": mount["uuid"],
            "source": mount["source"], "mount_id": mount["id"],
            "mountpoint": mount["target"], "fsroot": mount["fsroot"],
        },
        "subvolume": {"uuid": subvolume_uuid, "id": int(subvolume_id_match.group(1))},
        "nested_mounts": nested,
        "rootfs_mutated": False,
        "capture_or_install_performed": False,
    }


@contextmanager
def exclusive_writer_lock(path: Path) -> Iterator[None]:
    path = Path(os.path.abspath(path))
    _refuse_symlink_components(path.parent)
    if path.exists():
        _refuse_symlink_components(path)
    flags = os.O_RDWR | os.O_CREAT | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
    try:
        fd = os.open(path, flags, 0o600)
    except OSError as exc:
        raise CandidatePreflightError(f"cannot open exclusive writer lock {path}: {exc}") from exc
    try:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise CandidatePreflightError(f"candidate writer lock is busy: {path}") from exc
        yield
    finally:
        os.close(fd)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--expected-filesystem-uuid", required=True)
    parser.add_argument("--expected-subvolume-uuid", required=True)
    parser.add_argument("--lock-file", type=Path, default=DEFAULT_LOCK)
    args = parser.parse_args(argv)
    try:
        with exclusive_writer_lock(args.lock_file):
            evidence = inspect_candidate(args.root, args.expected_filesystem_uuid,
                                         args.expected_subvolume_uuid)
        evidence["writer_lock"] = "acquired exclusively for this read-only preflight"
        print(json.dumps(evidence, indent=2, sort_keys=True))
    except (CandidatePreflightError, json.JSONDecodeError) as exc:
        print(f"preflight rejected: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
