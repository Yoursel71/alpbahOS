#!/usr/bin/env python3
"""Capture one M04 install event in a marked disposable Linux fixture.

This is deliberately not a Builder/rootfs installer. It requires a fixture
marked with .m04-fixture-root, strace, and bubblewrap. It configures bubblewrap
to expose the host filesystem read-only and only the fixture writable. Linux
integration must still verify those mount restrictions and trace coverage before
using the data as ownership evidence.
"""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import time
import uuid
from pathlib import Path
from typing import Any, Mapping, Sequence


MARKER = ".m04-fixture-root"
MARKER_TEXT = "DISPOSABLE M04 TRANSACTION FIXTURE ONLY v1\n"
CAPTURE_DIR = ".m04-capture"
SCHEMA = "alpbahOS.m04-install-event-capture/v1"
WRITE_SYSCALLS = {
    "creat", "link", "linkat", "mkdir", "mkdirat", "mknod", "mknodat",
    "open", "openat", "openat2", "rename", "renameat", "renameat2",
    "rmdir", "symlink", "symlinkat", "truncate", "unlink", "unlinkat",
    "utime", "utimes", "utimensat", "chmod", "fchmod", "fchmodat", "chown",
    "fchmodat2", "fchown", "ftruncate", "fallocate",
    "fchownat", "lchown", "setxattr", "lsetxattr", "removexattr",
    "fsetxattr", "fremovexattr", "lremovexattr", "write", "writev",
    "pwrite64", "pwritev", "pwritev2", "sendfile", "copy_file_range",
    "splice", "mmap", "mount", "umount2",
}
PATH_ARGUMENTS = {
    "creat": (0,), "link": (1,), "linkat": (3,), "mkdir": (0,),
    "mkdirat": (1,), "mknod": (0,), "mknodat": (1,), "open": (0,),
    "openat": (1,), "openat2": (1,), "rename": (0, 1),
    "renameat": (1, 3), "renameat2": (1, 3), "rmdir": (0,),
    "symlink": (1,), "symlinkat": (2,), "truncate": (0,),
    "unlink": (0,), "unlinkat": (1,), "utime": (0,), "utimes": (0,),
    "utimensat": (1,), "chmod": (0,), "fchmodat": (1,), "fchmodat2": (1,), "chown": (0,),
    "fchownat": (1,), "lchown": (0,), "setxattr": (0,), "lsetxattr": (0,),
    "removexattr": (0,), "lremovexattr": (0,),
}
DIRFD_ARGUMENTS = {
    "linkat": {1: 0, 3: 2}, "mkdirat": {1: 0}, "mknodat": {1: 0},
    "openat": {1: 0}, "openat2": {1: 0}, "renameat": {1: 0, 3: 2},
    "renameat2": {1: 0, 3: 2}, "symlinkat": {2: 1}, "unlinkat": {1: 0},
    "utimensat": {1: 0}, "fchmodat": {1: 0}, "fchmodat2": {1: 0}, "fchownat": {1: 0},
}
OPEN_WRITE_FLAGS = ("O_WRONLY", "O_RDWR", "O_CREAT", "O_TRUNC", "O_APPEND", "O_TMPFILE")
FD_WRITE_ARGUMENTS = {
    "fchmod": (0,), "fchown": (0,), "ftruncate": (0,), "fallocate": (0,),
    "fsetxattr": (0,), "fremovexattr": (0,), "write": (0,), "writev": (0,),
    "pwrite64": (0,), "pwritev": (0,), "pwritev2": (0,), "sendfile": (0,),
    "copy_file_range": (2,), "splice": (2,), "mmap": (4,),
}
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
SYSCALL_RE = re.compile(r"^\s*(?:\[pid\s+\d+\]\s*)?([a-zA-Z_][a-zA-Z0-9_]*)\((.*)")


class CaptureError(RuntimeError):
    pass


class InstallCommandFailed(CaptureError):
    def __init__(self, event: Mapping[str, Any]):
        self.event = event
        super().__init__(f"install command exited {event['exit_status']}; evidence: {event['event_dir']}")


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def _write_json(path: Path, value: Any) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _reject_symlink_ancestors(path: Path, *, allow_missing: bool = False) -> None:
    absolute = Path(os.path.abspath(os.fspath(path)))
    cursor = Path(absolute.anchor)
    for component in absolute.parts[1:]:
        cursor = cursor / component
        try:
            info = os.lstat(cursor)
        except FileNotFoundError as exc:
            if allow_missing:
                return
            raise CaptureError(f"path component does not exist: {cursor}") from exc
        if stat.S_ISLNK(info.st_mode):
            raise CaptureError(f"symlink path component refused: {cursor}")


def _validate_root(root_arg: Path) -> Path:
    if sys.platform != "linux":
        raise CaptureError("install-event capture is Linux-only")
    if ".." in root_arg.parts:
        raise CaptureError("fixture root must not contain '..'")
    _reject_symlink_ancestors(root_arg)
    root = Path(os.path.abspath(os.fspath(root_arg)))
    if root == Path("/") or root == Path("/mnt/lfs") or Path("/mnt/lfs") in root.parents:
        raise CaptureError("refusing /, /mnt/lfs, or a descendant of /mnt/lfs")
    if not root.is_dir():
        raise CaptureError("fixture root must be a directory")
    marker = root / MARKER
    if marker.is_symlink() or not marker.is_file() or marker.read_text(encoding="utf-8") != MARKER_TEXT:
        raise CaptureError(f"fixture root requires exact disposable marker {MARKER}")
    return root


def _inside(root: Path, path: Path, *, must_exist: bool = True) -> Path:
    raw = Path(os.path.abspath(os.fspath(path)))
    try:
        raw.relative_to(root)
    except ValueError as exc:
        raise CaptureError(f"path is outside fixture root: {path}") from exc
    _reject_symlink_ancestors(raw if must_exist else raw.parent)
    if must_exist and not raw.exists():
        raise CaptureError(f"path does not exist: {path}")
    return raw


def _fingerprint(path: Path, root: Path) -> dict[str, Any]:
    info = os.lstat(path)
    result: dict[str, Any] = {
        "mode": stat.S_IMODE(info.st_mode), "uid": info.st_uid, "gid": info.st_gid,
    }
    if stat.S_ISREG(info.st_mode):
        result.update(type="file", size=info.st_size, sha256=_sha256(path))
    elif stat.S_ISDIR(info.st_mode):
        result["type"] = "directory"
    elif stat.S_ISLNK(info.st_mode):
        target = os.readlink(path)
        # Treat absolute links as fixture-root-relative and reject lexical escapes.
        components = list((target.lstrip("/") if os.path.isabs(target) else target).split("/"))
        depth = 0 if os.path.isabs(target) else len(path.parent.relative_to(root).parts)
        for part in components:
            if part in ("", "."):
                continue
            if part == "..":
                depth -= 1
            else:
                depth += 1
            if depth < 0:
                raise CaptureError(f"symlink target escapes fixture: {path} -> {target}")
        result.update(type="symlink", target=target)
    else:
        result.update(type="special", rdev=info.st_rdev)
    return result


def _snapshot(root: Path) -> dict[str, Any]:
    entries: dict[str, Any] = {}
    for base, dirs, files in os.walk(root, topdown=True, followlinks=False):
        base_path = Path(base)
        dirs[:] = sorted(d for d in dirs if not (base_path == root and d == CAPTURE_DIR))
        names = sorted(dirs + files)
        for name in names:
            path = base_path / name
            rel = "/" + path.relative_to(root).as_posix()
            entries[rel] = _fingerprint(path, root)
    return {"schema": "alpbahOS.m04-root-snapshot/v1", "entries": entries}


def _hash_inputs(paths: Sequence[Path]) -> list[dict[str, str]]:
    result = []
    for path in paths:
        if path.is_symlink() or not path.is_file():
            raise CaptureError(f"source/recipe input must be a regular non-symlink file: {path}")
        result.append({"path": str(path.resolve(strict=True)), "sha256": _sha256(path)})
    return result


def _split_strace_arguments(body: str) -> list[str]:
    args: list[str] = []
    start = 0
    stack: list[str] = []
    quote = False
    escaped = False
    matching = {")": "(", "}": "{", "]": "["}
    for index, char in enumerate(body):
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                quote = False
            continue
        if char == '"':
            quote = True
        elif char in "({[":
            stack.append(char)
        elif char in ")}]":
            if not stack:
                if char == ")":
                    args.append(body[start:index].strip())
                    return args
            elif stack[-1] == matching[char]:
                stack.pop()
        elif char == "," and not stack:
            args.append(body[start:index].strip())
            start = index + 1
    if start < len(body):
        args.append(body[start:].strip())
    return args


def _decode_trace_path(args: Sequence[str], index: int) -> str | None:
    if index >= len(args):
        return None
    try:
        value = ast.literal_eval(args[index])
    except (SyntaxError, ValueError):
        return None
    return value if isinstance(value, str) else None


def _trace_open_writes(syscall: str, args: Sequence[str]) -> bool:
    flags_index = {"open": 1, "openat": 2, "openat2": 2}[syscall]
    if flags_index >= len(args):
        return True
    return any(flag in args[flags_index] for flag in OPEN_WRITE_FLAGS)


def _trace_mmap_writes(args: Sequence[str]) -> bool:
    return len(args) > 4 and "MAP_SHARED" in args[3] and "PROT_WRITE" in args[2]


def _trace_outside_writes(trace_path: Path, root: Path, cwd: Path) -> list[str]:
    violations: list[str] = []
    for line_no, line in enumerate(trace_path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        match = SYSCALL_RE.match(line)
        if not match or match.group(1) not in WRITE_SYSCALLS:
            continue
        syscall, body = match.groups()
        args = _split_strace_arguments(body)
        if syscall in {"open", "openat", "openat2"} and not _trace_open_writes(syscall, args):
            continue
        if syscall == "mmap" and not _trace_mmap_writes(args):
            continue
        path_indices = PATH_ARGUMENTS.get(syscall)
        if path_indices is None:
            for fd_index in FD_WRITE_ARGUMENTS.get(syscall, ()):
                fd_arg = args[fd_index] if fd_index < len(args) else ""
                fd_match = re.search(r"\d+<([^>]+)>", fd_arg)
                if not fd_match:
                    violations.append(f"line {line_no}: cannot resolve descriptor for {syscall}")
                    continue
                fd_path = fd_match.group(1)
                if fd_path.startswith(("pipe:[", "socket:[", "anon_inode:")):
                    continue
                candidate = Path(fd_path)
                if not candidate.is_absolute():
                    violations.append(f"line {line_no}: cannot resolve fd path for {syscall}")
                    continue
                try:
                    candidate.relative_to(root)
                except ValueError:
                    violations.append(f"line {line_no}: {syscall} fd path outside fixture: {candidate}")
            continue
        for path_index in path_indices:
            raw = _decode_trace_path(args, path_index)
            if raw is None:
                violations.append(f"line {line_no}: cannot decode {syscall} pathname argument {path_index}")
                continue
            dirfd_index = DIRFD_ARGUMENTS.get(syscall, {}).get(path_index)
            dirfd_arg = args[dirfd_index] if dirfd_index is not None and dirfd_index < len(args) else "AT_FDCWD"
            dirfd_match = re.fullmatch(r"\d+<([^>]+)>", dirfd_arg)
            if not os.path.isabs(raw) and dirfd_arg != "AT_FDCWD" and not dirfd_match:
                violations.append(f"line {line_no}: cannot resolve relative {syscall} dirfd {dirfd_arg!r}")
                continue
            dirfd_path = Path(dirfd_match.group(1)) if dirfd_match else cwd
            candidate = Path(raw) if os.path.isabs(raw) else dirfd_path / raw
            candidate = Path(os.path.abspath(os.fspath(candidate)))
            try:
                candidate.relative_to(root)
            except ValueError:
                violations.append(f"line {line_no}: {syscall} path outside fixture: {candidate}")
    return violations


def _execute(argv: Sequence[str], cwd: Path, env: Mapping[str, str], root: Path,
             trace_path: Path, strace: str, bwrap: str,
             stdout_path: Path, stderr_path: Path) -> int:
    # Request a read-only host and evidence store with only the fixture writable.
    # Effective isolation has not been verified by a real Linux integration run.
    event_store = root / CAPTURE_DIR / "events"
    traced = [strace, "-f", "-qq", "-yy", "-e", "trace=%file,%desc,mmap", "-o", str(trace_path),
              "--", bwrap, "--die-with-parent", "--unshare-all", "--ro-bind", "/", "/",
              "--bind", str(root), str(root), "--ro-bind", str(event_store), str(event_store),
              "--chdir", str(cwd), "--", *argv]
    with stdout_path.open("wb") as stdout, stderr_path.open("wb") as stderr:
        proc = subprocess.run(traced, cwd=str(cwd), env=dict(env), stdout=stdout,
                              stderr=stderr, check=False)
    return proc.returncode


def capture_install(root: Path, argv: Sequence[str], *, cwd: Path | None = None,
                    env_overrides: Mapping[str, str] | None = None,
                    input_paths: Sequence[Path] = (),
                    package: str = "fixture-package", version: str = "unknown") -> dict[str, Any]:
    root = _validate_root(root)
    if not argv or any(not isinstance(arg, str) or "\x00" in arg for arg in argv):
        raise CaptureError("argv must be a nonempty sequence of NUL-free strings")
    requested_cwd = cwd or root
    if not requested_cwd.is_absolute():
        requested_cwd = root / requested_cwd
    workdir = _inside(root, requested_cwd)
    if not workdir.is_dir():
        raise CaptureError("cwd must be a directory inside fixture root")
    strace, bwrap = shutil.which("strace"), shutil.which("bwrap")
    if not strace:
        raise CaptureError("strace is required; refusing uncaptured install")
    if not bwrap:
        raise CaptureError("bubblewrap (bwrap) is required to confine writes")
    event_id = f"{time.strftime('%Y%m%dT%H%M%SZ', time.gmtime())}-{uuid.uuid4().hex}"
    capture_root = root / CAPTURE_DIR
    event_root, work_root = capture_root / "events", capture_root / "work"
    event_dir = root / CAPTURE_DIR / "events" / event_id
    work_dir = work_root / event_id
    for path in (capture_root, event_root, work_root, event_dir, work_dir):
        _reject_symlink_ancestors(path, allow_missing=True)
    event_dir.mkdir(parents=True, mode=0o700)
    work_dir.mkdir(parents=True, mode=0o700)
    _inside(root, event_dir)
    before = _snapshot(root)
    hashed_inputs = _hash_inputs(input_paths)
    home_dir, temp_dir = work_dir / "home", work_dir / "tmp"
    home_dir.mkdir(parents=True, mode=0o700)
    temp_dir.mkdir(parents=True, mode=0o700)
    allowed = {"PATH": os.environ.get("PATH", "/usr/bin:/bin"), "LANG": "C", "LC_ALL": "C",
               "HOME": str(home_dir), "TMPDIR": str(temp_dir)}
    for key, value in (env_overrides or {}).items():
        if not re.fullmatch(r"[A-Z_][A-Z0-9_]*", key) or "\x00" in value or "=" in key:
            shutil.rmtree(work_dir, ignore_errors=True)
            raise CaptureError(f"invalid explicit environment entry: {key!r}")
        allowed[key] = value
    before_path = event_dir / "before.json"
    _write_json(before_path, before)
    trace_path = event_dir / "strace-file-writes.log"
    stdout_path, stderr_path = event_dir / "stdout.log", event_dir / "stderr.log"
    start_ns = time.time_ns()
    try:
        exit_status = _execute(argv, workdir, allowed, root, trace_path, strace, bwrap,
                               stdout_path, stderr_path)
    except OSError as exc:
        shutil.rmtree(work_dir, ignore_errors=True)
        raise CaptureError(f"could not start confined install command: {exc}") from exc
    try:
        shutil.rmtree(work_dir)
    except OSError as exc:
        raise CaptureError(f"could not clean command scratch directory {work_dir}: {exc}") from exc
    end_ns = time.time_ns()
    if not trace_path.is_file():
        raise CaptureError("strace did not produce its trace; event is incomplete")
    violations = _trace_outside_writes(trace_path, root, workdir)
    after = _snapshot(root)
    after_path = event_dir / "after.json"
    _write_json(after_path, after)
    changed = sorted(path for path in set(before["entries"]) | set(after["entries"])
                     if before["entries"].get(path) != after["entries"].get(path))
    files = {"before_snapshot": before_path, "after_snapshot": after_path,
             "stdout": stdout_path, "stderr": stderr_path, "strace": trace_path}
    event: dict[str, Any] = {
        "schema": SCHEMA, "event_id": event_id, "event_dir": str(event_dir.relative_to(root)),
        "package": package, "version": version,
        "argv": list(argv), "cwd": str(workdir), "environment": dict(sorted(allowed.items())),
        "started_unix_ns": start_ns, "ended_unix_ns": end_ns, "exit_status": exit_status,
        "changed_paths": changed, "outside_root_write_attempts": violations,
        "inputs": hashed_inputs, "artifacts": {
            name: {"path": str(path.relative_to(root)), "size": path.stat().st_size,
                   "sha256": _sha256(path)} for name, path in files.items()
        },
    }
    event_path = event_dir / "event.json"
    _write_json(event_path, event)
    event["event_manifest"] = {"path": str(event_path.relative_to(root)),
                               "sha256": _sha256(event_path)}
    if violations:
        raise CaptureError("trace contains writes outside the fixture; see " + str(event_path))
    if exit_status != 0:
        raise InstallCommandFailed(event)
    return event


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True, type=Path, help="marked disposable fixture root")
    parser.add_argument("--cwd", type=Path, help="command cwd; must be inside fixture root")
    parser.add_argument("--package", default="fixture-package")
    parser.add_argument("--version", default="unknown")
    parser.add_argument("--input", action="append", default=[], type=Path,
                        help="source or recipe file to hash (repeatable)")
    parser.add_argument("--env", action="append", default=[], metavar="KEY=VALUE",
                        help="explicit environment override; recorded verbatim")
    parser.add_argument("command", nargs=argparse.REMAINDER,
                        help="install command after --; exact argv is captured")
    args = parser.parse_args(argv)
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    env: dict[str, str] = {}
    for item in args.env:
        if "=" not in item:
            parser.error("--env expects KEY=VALUE")
        key, value = item.split("=", 1)
        env[key] = value
    try:
        event = capture_install(args.root, command, cwd=args.cwd, env_overrides=env,
                                input_paths=args.input, package=args.package, version=args.version)
    except InstallCommandFailed as exc:
        print(str(exc), file=sys.stderr)
        return int(exc.event["exit_status"])
    except CaptureError as exc:
        print(f"capture refused: {exc}", file=sys.stderr)
        return 2
    print(json.dumps(event, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
