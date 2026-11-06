#!/usr/bin/env python3
"""Experimental, fixture-only package install transaction writer for M04.

SAFETY BOUNDARY: this program accepts only a disposable directory containing
the exact marker `.m04-fixture-root` with the expected contents. It refuses
`/mnt/lfs`, `/`, and unmarked directories. It is not an Alp integration and
does not authenticate source archives or recipe hashes. Never use it against a
real root filesystem.

The prototype installs regular files and symlinks only. It refuses hardlinks,
nonempty xattrs (including file capabilities), special files, symlinked path
components, and missing target parent directories. Directories remain shared
and unowned. A differing existing object needs a policy entry that pins its
old fingerprint and current ledger owner. Journals and backups are kept in the
fixture root for idempotent crash recovery.
"""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
import re
import shutil
import stat
import sys
import tempfile
import uuid
from contextlib import contextmanager
from pathlib import Path, PurePosixPath
from typing import Any, Callable


MARKER = ".m04-fixture-root"
MARKER_TEXT = "DISPOSABLE M04 TRANSACTION FIXTURE ONLY v1\n"
JOURNAL_DIR = ".m04-transactions"
LEDGER_NAME = ".m04-ownership-ledger.json"
LOCK_NAME = ".m04-transaction.lock"
SCHEMA = "alpbahOS.m04-fixture-ownership/v1"
TX_SCHEMA = "alpbahOS.m04-fixture-transaction/v1"
NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9+_.-]{0,127}$")
SHA_RE = re.compile(r"^[0-9a-f]{64}$")
RESERVED = {MARKER, JOURNAL_DIR, LEDGER_NAME, LOCK_NAME}


class TransactionError(RuntimeError):
    pass


class InjectedCrash(BaseException):
    """Test-only abrupt-stop signal; deliberately bypasses normal error cleanup."""


def _canonical_json(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode()


def _sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _sha_file(path: Path) -> str:
    digest = hashlib.sha256()
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(path, flags)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
            raise TransactionError(f"unsupported or hardlinked regular file: {path}")
        _require_no_xattrs(path)
        with os.fdopen(fd, "rb", closefd=False) as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
        after = os.fstat(fd)
        if (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns,
                info.st_mode, info.st_uid, info.st_gid) != (
            after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns, after.st_ctime_ns,
            after.st_mode, after.st_uid, after.st_gid
        ):
            raise TransactionError(f"file changed while hashing: {path}")
    finally:
        os.close(fd)
    return digest.hexdigest()


def _require_no_xattrs(path: Path, *, symlink: bool = False) -> None:
    try:
        attrs = os.listxattr(path, follow_symlinks=not symlink)
    except (AttributeError, NotImplementedError, OSError) as exc:
        raise TransactionError(f"cannot safely inspect xattrs for {path}: {exc}") from exc
    if attrs:
        raise TransactionError(f"unsupported xattrs/capabilities on {path}: {sorted(attrs)}")


def _require_fd_no_xattrs(fd: int, path: Path) -> None:
    try:
        attrs = os.listxattr(fd)
    except (AttributeError, NotImplementedError, OSError) as exc:
        raise TransactionError(f"cannot safely inspect xattrs for pinned file {path}: {exc}") from exc
    if attrs:
        raise TransactionError(f"unsupported xattrs/capabilities on {path}: {sorted(attrs)}")


def _safe_relative(raw: Any) -> tuple[str, tuple[str, ...]]:
    if not isinstance(raw, str) or not raw.startswith("/") or "\\" in raw or "\x00" in raw:
        raise TransactionError(f"unsafe package path: {raw!r}")
    parts = raw[1:].split("/")
    if not parts or any(part in ("", ".", "..") for part in parts):
        raise TransactionError(f"non-canonical package path: {raw!r}")
    if parts[0] in RESERVED:
        raise TransactionError(f"package path uses reserved transaction metadata: {raw}")
    if PurePosixPath(raw).as_posix() != raw:
        raise TransactionError(f"non-canonical package path: {raw!r}")
    return raw, tuple(parts)


def _root(root_arg: Path) -> Path:
    if ".." in root_arg.parts:
        raise TransactionError("fixture root must not contain '..'")
    root = Path(os.path.abspath(os.fspath(root_arg)))
    if root == Path(root.anchor) or root == Path("/mnt/lfs") or Path("/mnt/lfs") in root.parents:
        raise TransactionError("refusing a system root or /mnt/lfs path")
    cursor = Path(root.anchor)
    for component in root.parts[1:]:
        cursor = cursor / component
        info = os.lstat(cursor)
        if stat.S_ISLNK(info.st_mode):
            raise TransactionError(f"symlinked fixture-root ancestor: {cursor}")
        if cursor != root and not stat.S_ISDIR(info.st_mode):
            raise TransactionError(f"non-directory fixture-root ancestor: {cursor}")
    if not stat.S_ISDIR(os.lstat(root).st_mode):
        raise TransactionError("fixture root must be a real directory")
    marker = root / MARKER
    if marker.is_symlink() or not marker.is_file() or marker.read_text(encoding="utf-8") != MARKER_TEXT:
        raise TransactionError(f"fixture root requires exact disposable marker {MARKER}")
    return root


@contextmanager
def _lock(root: Path):
    fd = os.open(root / LOCK_NAME, os.O_CREAT | os.O_RDWR | getattr(os, "O_NOFOLLOW", 0), 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
        yield
    finally:
        fcntl.flock(fd, fcntl.LOCK_UN)
        os.close(fd)


def _atomic_write(path: Path, data: bytes, mode: int = 0o600) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, raw_tmp = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    tmp = Path(raw_tmp)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(tmp, mode)
        os.replace(tmp, path)
        _fsync_dir(path.parent)
    except BaseException:
        try:
            tmp.unlink()
        except FileNotFoundError:
            pass
        raise


def _fsync_dir(path: Path) -> None:
    fd = os.open(path, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def _ensure_private_dir(path: Path, parent: Path) -> None:
    created = False
    try:
        path.mkdir(mode=0o700)
        created = True
    except FileExistsError:
        pass
    info = os.lstat(path)
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid():
        raise TransactionError(f"private transaction directory is not a real owned directory: {path}")
    mode_changed = stat.S_IMODE(info.st_mode) != 0o700
    if mode_changed:
        os.chmod(path, 0o700)
    if created or mode_changed:
        _fsync_dir(parent)
        _fsync_dir(path)


def _assert_private_dir(path: Path) -> None:
    info = os.lstat(path)
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o700:
        raise TransactionError(f"transaction metadata directory must be owned mode 0700: {path}")


def _object(path: Path) -> dict[str, Any] | None:
    try:
        info = os.lstat(path)
    except FileNotFoundError:
        return None
    mode = stat.S_IMODE(info.st_mode)
    base = {"mode": mode, "uid": info.st_uid, "gid": info.st_gid}
    if stat.S_ISREG(info.st_mode):
        if info.st_nlink != 1:
            raise TransactionError(f"unsupported hardlinked file: {path}")
        _require_no_xattrs(path)
        return {**base, "type": "file", "size": info.st_size, "sha256": _sha_file(path), "mtime_ns": info.st_mtime_ns}
    if stat.S_ISLNK(info.st_mode):
        _require_no_xattrs(path, symlink=True)
        target = os.readlink(path)
        after = os.lstat(path)
        if (info.st_dev, info.st_ino, info.st_mtime_ns) != (after.st_dev, after.st_ino, after.st_mtime_ns):
            raise TransactionError(f"symlink changed while inspecting: {path}")
        return {**base, "type": "symlink", "target": target, "mtime_ns": info.st_mtime_ns}
    raise TransactionError(f"unsupported target type: {path}")


def _fingerprint(obj: dict[str, Any] | None) -> str:
    return _sha_bytes(_canonical_json(obj))


def _stage_entries(stage_arg: Path) -> tuple[Path, list[dict[str, Any]]]:
    stage = Path(os.path.abspath(os.fspath(stage_arg)))
    if stage.is_symlink() or not stage.is_dir():
        raise TransactionError("stage must be a real directory")
    entries: list[dict[str, Any]] = []

    def walk(directory: Path, prefix: str = "") -> None:
        with os.scandir(directory) as iterator:
            children = sorted(iterator, key=lambda item: os.fsencode(item.name))
        for child in children:
            rel = f"{prefix}/{child.name}" if prefix else child.name
            abs_path = "/" + rel.replace(os.sep, "/")
            _, parts = _safe_relative(abs_path)
            info = child.stat(follow_symlinks=False)
            base = {"path": abs_path, "mode": stat.S_IMODE(info.st_mode), "uid": info.st_uid, "gid": info.st_gid}
            p = Path(child.path)
            if stat.S_ISDIR(info.st_mode):
                entries.append({**base, "type": "directory"})
                walk(p, rel)
            elif stat.S_ISREG(info.st_mode):
                if info.st_nlink != 1:
                    raise TransactionError(f"unsupported hardlinked stage file: {p}")
                _require_no_xattrs(p)
                entries.append({**base, "type": "file", "size": info.st_size, "sha256": _sha_file(p), "mtime_ns": info.st_mtime_ns, "source": str(p)})
            elif stat.S_ISLNK(info.st_mode):
                _require_no_xattrs(p, symlink=True)
                entries.append({**base, "type": "symlink", "target": os.readlink(p), "mtime_ns": info.st_mtime_ns, "source": str(p)})
            else:
                raise TransactionError(f"unsupported stage object: {p}")

    walk(stage)
    owned = [entry for entry in entries if entry["type"] != "directory"]
    if not owned:
        raise TransactionError("stage contains no regular files or symlinks")
    seen: set[str] = set()
    for entry in entries:
        path = entry["path"]
        if path in seen:
            raise TransactionError(f"duplicate stage path: {path}")
        seen.add(path)
    return stage, entries


def _target(root: Path, raw_path: str) -> Path:
    _, parts = _safe_relative(raw_path)
    current = root
    for part in parts[:-1]:
        current = current / part
        try:
            info = os.lstat(current)
        except FileNotFoundError:
            raise TransactionError(f"target parent must already exist: {current}") from None
        if not stat.S_ISDIR(info.st_mode):
            raise TransactionError(f"target parent is not a real directory: {current}")
    return current / parts[-1]


def _load_json(path: Path, default: dict[str, Any]) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return default
    except (OSError, json.JSONDecodeError) as exc:
        raise TransactionError(f"invalid JSON at {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise TransactionError(f"JSON root at {path} must be an object")
    return value


def _ledger(root: Path) -> dict[str, Any]:
    ledger = _load_json(root / LEDGER_NAME, {"schema": SCHEMA, "records": []})
    if set(ledger) != {"schema", "records"} or ledger.get("schema") != SCHEMA or not isinstance(ledger.get("records"), list):
        raise TransactionError("fixture ownership ledger has invalid schema")
    return ledger


def _claims(ledger: dict[str, Any]) -> dict[str, dict[str, Any]]:
    claims: dict[str, dict[str, Any]] = {}
    for record in ledger["records"]:
        if not isinstance(record, dict) or not isinstance(record.get("entries"), list):
            raise TransactionError("malformed ownership ledger record")
        for entry in record["entries"]:
            path = entry.get("path") if isinstance(entry, dict) else None
            if not isinstance(path, str) or path in claims:
                raise TransactionError(f"duplicate or malformed ledger claim: {path!r}")
            claims[path] = record
    return claims


def _snapshot(stage_entry: dict[str, Any], payload_path: Path) -> dict[str, Any]:
    result = {key: stage_entry[key] for key in ("path", "type", "mode", "uid", "gid")}
    if stage_entry["type"] == "file":
        result.update(size=stage_entry["size"], sha256=stage_entry["sha256"], mtime_ns=stage_entry["mtime_ns"], payload=payload_path.name)
    else:
        result.update(target=stage_entry["target"], mtime_ns=stage_entry["mtime_ns"])
    return result


def _copy_payload(source: Path, destination: Path, expected: dict[str, Any]) -> None:
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
    src_fd = os.open(source, flags)
    try:
        before = os.fstat(src_fd)
        if not stat.S_ISREG(before.st_mode) or before.st_nlink != 1:
            raise TransactionError(f"stage file changed type/link count: {source}")
        if (before.st_size, before.st_mtime_ns, stat.S_IMODE(before.st_mode), before.st_uid, before.st_gid) != (
            expected["size"], expected["mtime_ns"], expected["mode"], expected["uid"], expected["gid"]
        ):
            raise TransactionError(f"stage file metadata changed after capture: {source}")
        _require_no_xattrs(source)
        out_fd = os.open(destination, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        try:
            with os.fdopen(src_fd, "rb", closefd=False) as src, os.fdopen(out_fd, "wb", closefd=False) as dst:
                shutil.copyfileobj(src, dst, 1024 * 1024)
                dst.flush()
                os.fsync(dst.fileno())
            after = os.fstat(src_fd)
        finally:
            os.close(out_fd)
        if (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns,
                before.st_ctime_ns, before.st_mode, before.st_uid, before.st_gid) != (
                after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns,
                after.st_ctime_ns, after.st_mode, after.st_uid, after.st_gid):
            raise TransactionError(f"stage file changed while snapshotting: {source}")
    finally:
        os.close(src_fd)
    if destination.stat().st_size != expected["size"] or _sha_file(destination) != expected["sha256"]:
        raise TransactionError(f"stage file changed between capture and snapshot: {source}")
    st = destination.stat()
    if (st.st_uid, st.st_gid) != (expected["uid"], expected["gid"]):
        try:
            os.chown(destination, expected["uid"], expected["gid"])
        except PermissionError as exc:
            raise TransactionError(f"cannot preserve staged uid/gid for {source}") from exc
    os.chmod(destination, expected["mode"])
    st = destination.stat()
    if (st.st_uid, st.st_gid, stat.S_IMODE(st.st_mode)) != (expected["uid"], expected["gid"], expected["mode"]):
        raise TransactionError(f"staged payload ownership/mode verification failed: {source}")
    os.utime(destination, ns=(expected["mtime_ns"], expected["mtime_ns"]))
    fd = os.open(destination, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
    try:
        os.fsync(fd)
    finally:
        os.close(fd)
    _fsync_dir(destination.parent)


def _copy_backup(source: Path, destination: Path, expected: dict[str, Any], *,
                 failpoint: Callable[[str], None] | None, point_index: int) -> dict[str, Any]:
    src_fd = os.open(source, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
    try:
        before = os.fstat(src_fd)
        if not stat.S_ISREG(before.st_mode) or before.st_nlink != 1:
            raise TransactionError(f"cannot back up unsupported/hardlinked target: {source}")
        _require_fd_no_xattrs(src_fd, source)
        source_metadata = (before.st_size, before.st_mtime_ns, stat.S_IMODE(before.st_mode), before.st_uid, before.st_gid)
        expected_metadata = (expected["size"], expected["mtime_ns"], expected["mode"], expected["uid"], expected["gid"])
        if source_metadata != expected_metadata:
            raise TransactionError(f"target changed before backup capture: {source}")
        out_fd = os.open(destination, os.O_CREAT | os.O_EXCL | os.O_WRONLY | getattr(os, "O_NOFOLLOW", 0), 0o600)
        digest = hashlib.sha256()
        copied = 0
        try:
            while True:
                block = os.read(src_fd, 1024 * 1024)
                if not block:
                    break
                copied += len(block)
                digest.update(block)
                view = memoryview(block)
                while view:
                    written = os.write(out_fd, view)
                    if written <= 0:
                        raise TransactionError(f"short write while saving backup for {source}")
                    view = view[written:]
            os.fsync(out_fd)
        finally:
            os.close(out_fd)
        after = os.fstat(src_fd)
        signature_before = (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns,
                            before.st_ctime_ns, before.st_mode, before.st_uid, before.st_gid)
        signature_after = (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns,
                           after.st_ctime_ns, after.st_mode, after.st_uid, after.st_gid)
        try:
            path_after = os.lstat(source)
        except FileNotFoundError:
            raise TransactionError(f"target disappeared during backup capture: {source}") from None
        signature_path = (path_after.st_dev, path_after.st_ino, path_after.st_size, path_after.st_mtime_ns,
                          path_after.st_ctime_ns, path_after.st_mode, path_after.st_uid, path_after.st_gid)
        if signature_before != signature_after or signature_before != signature_path:
            raise TransactionError(f"target changed during backup capture: {source}")
    finally:
        os.close(src_fd)

    os.chmod(destination, 0o600)
    backup_fd = os.open(destination, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
    try:
        os.fsync(backup_fd)
    finally:
        os.close(backup_fd)
    _fsync_dir(destination.parent)
    _fail(failpoint, f"after_backup_copy_{point_index}")
    backup_info = os.lstat(destination)
    if not stat.S_ISREG(backup_info.st_mode) or backup_info.st_nlink != 1:
        raise TransactionError(f"backup capture produced unsupported object: {destination}")
    _require_no_xattrs(destination)
    backup_hash = _sha_file(destination)
    if copied != expected["size"] or digest.hexdigest() != expected["sha256"]:
        raise TransactionError(f"source bytes changed during backup capture: {source}")
    if backup_info.st_size != expected["size"] or backup_hash != expected["sha256"]:
        raise TransactionError(f"backup copy verification failed: {destination}")
    backup_after = os.lstat(destination)
    if (backup_info.st_dev, backup_info.st_ino, backup_info.st_size, backup_info.st_mtime_ns,
            backup_info.st_ctime_ns, backup_info.st_mode, backup_info.st_uid, backup_info.st_gid) != (
            backup_after.st_dev, backup_after.st_ino, backup_after.st_size, backup_after.st_mtime_ns,
            backup_after.st_ctime_ns, backup_after.st_mode, backup_after.st_uid, backup_after.st_gid):
        raise TransactionError(f"backup changed while validating: {destination}")
    return {
        "mode": stat.S_IMODE(backup_info.st_mode), "uid": backup_info.st_uid,
        "gid": backup_info.st_gid, "mtime_ns": backup_info.st_mtime_ns,
    }


def _write_object(root: Path, item: dict[str, Any], payload_dir: Path) -> None:
    target = _target(root, item["path"])
    parent = target.parent
    tmp = parent / f".m04-tmp-{uuid.uuid4().hex}"
    if item["type"] == "file":
        payload = payload_dir / item["payload"]
        fd_in = os.open(payload, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
        fd_out = os.open(tmp, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        try:
            with os.fdopen(fd_in, "rb", closefd=False) as src, os.fdopen(fd_out, "wb", closefd=False) as dst:
                shutil.copyfileobj(src, dst, 1024 * 1024)
                dst.flush()
                os.fsync(dst.fileno())
        finally:
            os.close(fd_in)
            os.close(fd_out)
        if (tmp.stat().st_uid, tmp.stat().st_gid) != (item["uid"], item["gid"]):
            try:
                os.chown(tmp, item["uid"], item["gid"])
            except PermissionError as exc:
                tmp.unlink(missing_ok=True)
                raise TransactionError(f"cannot preserve uid/gid for {item['path']}") from exc
        os.chmod(tmp, item["mode"])
        st = tmp.stat()
        if (st.st_uid, st.st_gid, stat.S_IMODE(st.st_mode)) != (item["uid"], item["gid"], item["mode"]):
            tmp.unlink(missing_ok=True)
            raise TransactionError(f"target ownership/mode verification failed: {item['path']}")
        os.utime(tmp, ns=(item["mtime_ns"], item["mtime_ns"]))
        sync_fd = os.open(tmp, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
        try:
            os.fsync(sync_fd)
        finally:
            os.close(sync_fd)
    else:
        os.symlink(item["target"], tmp)
        if (os.lstat(tmp).st_uid, os.lstat(tmp).st_gid) != (item["uid"], item["gid"]):
            try:
                os.chown(tmp, item["uid"], item["gid"], follow_symlinks=False)
            except (PermissionError, NotImplementedError) as exc:
                tmp.unlink(missing_ok=True)
                raise TransactionError(f"cannot preserve symlink uid/gid for {item['path']}") from exc
        os.utime(tmp, ns=(item["mtime_ns"], item["mtime_ns"]), follow_symlinks=False)
    try:
        os.replace(tmp, target)
        _fsync_dir(parent)
    except BaseException:
        tmp.unlink(missing_ok=True)
        raise


def _restore(root: Path, action: dict[str, Any], backup_dir: Path) -> None:
    target = _target(root, action["path"])
    before = action["before"]
    current = _object(target)
    current_fingerprint = _fingerprint(current)
    if current_fingerprint == action["before_fingerprint"]:
        return
    after_fingerprint = _fingerprint(action["after"])
    if current_fingerprint != after_fingerprint:
        raise TransactionError(
            f"refusing rollback over an unexpected third-party object: {action['path']}"
        )
    if before is None:
        target.unlink(missing_ok=True)
        _fsync_dir(target.parent)
        return
    tmp = target.parent / f".m04-restore-{uuid.uuid4().hex}"
    if before["type"] == "file":
        backup = backup_dir / before["backup"]
        fd_in = os.open(backup, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
        fd_out = os.open(tmp, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        try:
            with os.fdopen(fd_in, "rb", closefd=False) as src, os.fdopen(fd_out, "wb", closefd=False) as dst:
                shutil.copyfileobj(src, dst, 1024 * 1024)
                dst.flush()
                os.fsync(dst.fileno())
        finally:
            os.close(fd_in)
            os.close(fd_out)
        if (tmp.stat().st_uid, tmp.stat().st_gid) != (before["uid"], before["gid"]):
            os.chown(tmp, before["uid"], before["gid"])
        os.chmod(tmp, before["mode"])
        st = tmp.stat()
        if (st.st_uid, st.st_gid, stat.S_IMODE(st.st_mode)) != (before["uid"], before["gid"], before["mode"]):
            tmp.unlink(missing_ok=True)
            raise TransactionError(f"rollback ownership/mode verification failed: {action['path']}")
        os.utime(tmp, ns=(before["mtime_ns"], before["mtime_ns"]))
        sync_fd = os.open(tmp, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
        try:
            os.fsync(sync_fd)
        finally:
            os.close(sync_fd)
    else:
        os.symlink(before["target"], tmp)
        if (os.lstat(tmp).st_uid, os.lstat(tmp).st_gid) != (before["uid"], before["gid"]):
            os.chown(tmp, before["uid"], before["gid"], follow_symlinks=False)
        os.utime(tmp, ns=(before["mtime_ns"], before["mtime_ns"]), follow_symlinks=False)
    os.replace(tmp, target)
    _fsync_dir(target.parent)
    if _fingerprint(_object(target)) != action["before_fingerprint"]:
        raise TransactionError(f"rollback did not restore exact recorded object: {action['path']}")


def _journal_path(root: Path, txid: str) -> Path:
    if not re.fullmatch(r"[0-9a-f]{32}", txid):
        raise TransactionError("invalid transaction id")
    return root / JOURNAL_DIR / txid / "journal.json"


def _save_journal(path: Path, journal: dict[str, Any]) -> None:
    _atomic_write(path, _canonical_json(journal))


def _verify_journal_backups(journal: dict[str, Any], backup_dir: Path) -> None:
    try:
        os.lstat(backup_dir)
    except FileNotFoundError:
        raise TransactionError("transaction backup directory is missing") from None
    _assert_private_dir(backup_dir.parent.parent)
    _assert_private_dir(backup_dir.parent)
    _assert_private_dir(backup_dir)
    _assert_private_dir(backup_dir.parent / "payloads")
    for index, action in enumerate(journal.get("actions", []), start=1):
        before = action.get("before")
        if before is None or before.get("type") != "file":
            continue
        backup_name = before.get("backup")
        if backup_name != f"{index:08d}.backup":
            raise TransactionError(f"invalid backup path in transaction journal: {backup_name!r}")
        metadata = before.get("backup_metadata")
        if not isinstance(metadata, dict) or set(metadata) != {"mode", "uid", "gid", "mtime_ns"}:
            raise TransactionError(f"invalid backup metadata in transaction journal: {action.get('path')}")
        backup = backup_dir / backup_name
        try:
            info = os.lstat(backup)
        except FileNotFoundError:
            raise TransactionError(f"required rollback backup is missing: {backup_name}") from None
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
            raise TransactionError(f"rollback backup is not a single-link regular file: {backup_name}")
        _require_no_xattrs(backup)
        actual_metadata = {
            "mode": stat.S_IMODE(info.st_mode), "uid": info.st_uid, "gid": info.st_gid,
            "mtime_ns": info.st_mtime_ns,
        }
        if actual_metadata != metadata:
            raise TransactionError(f"rollback backup metadata mismatch: {backup_name}")
        if info.st_size != before.get("size") or _sha_file(backup) != before.get("sha256"):
            raise TransactionError(f"rollback backup content mismatch: {backup_name}")


def _fail(hook: Callable[[str], None] | None, point: str) -> None:
    if hook:
        hook(point)


def _load_policy_snapshot(path: Path | None) -> tuple[dict[str, Any], str | None]:
    if path is None:
        return {"schema": "alpbahOS.m04-fixture-replace-policy/v1", "replacements": {}}, None
    fd = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
    try:
        before = os.fstat(fd)
        if not stat.S_ISREG(before.st_mode) or before.st_nlink != 1:
            raise TransactionError("replacement policy must be a single-link regular file")
        chunks: list[bytes] = []
        while True:
            block = os.read(fd, 1024 * 1024)
            if not block:
                break
            chunks.append(block)
        after = os.fstat(fd)
        try:
            path_after = os.lstat(path)
        except FileNotFoundError:
            raise TransactionError("replacement policy disappeared while being read") from None
        signature_before = (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns,
                            before.st_ctime_ns, before.st_mode, before.st_uid, before.st_gid)
        signature_after = (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns,
                           after.st_ctime_ns, after.st_mode, after.st_uid, after.st_gid)
        signature_path = (path_after.st_dev, path_after.st_ino, path_after.st_size, path_after.st_mtime_ns,
                          path_after.st_ctime_ns, path_after.st_mode, path_after.st_uid, path_after.st_gid)
        if signature_before != signature_after or signature_before != signature_path:
            raise TransactionError("replacement policy changed while being snapshotted")
        raw_policy = b"".join(chunks)
    finally:
        os.close(fd)
    try:
        policy = json.loads(raw_policy)
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise TransactionError(f"replacement policy is invalid JSON: {exc}") from exc
    if not isinstance(policy, dict) or set(policy) != {"schema", "replacements"} or policy.get("schema") != "alpbahOS.m04-fixture-replace-policy/v1" or not isinstance(policy.get("replacements"), dict):
        raise TransactionError("replacement policy has invalid schema")
    for raw_path, spec in policy["replacements"].items():
        _safe_relative(raw_path)
        if not isinstance(spec, dict) or set(spec) != {"old_fingerprint", "previous_owner"}:
            raise TransactionError(f"invalid replacement policy for {raw_path}")
        if not isinstance(spec["old_fingerprint"], str) or not SHA_RE.fullmatch(spec["old_fingerprint"]):
            raise TransactionError(f"invalid old fingerprint in replacement policy for {raw_path}")
        owner = spec["previous_owner"]
        if owner is not None and not isinstance(owner, str):
            raise TransactionError(f"invalid previous_owner in replacement policy for {raw_path}")
    return policy, _sha_bytes(raw_policy)


def install_transaction(root_arg: Path, stage_arg: Path, *, name: str, version: str,
                        source_sha256: str, recipe_sha256: str, policy_path: Path | None = None,
                        failpoint: Callable[[str], None] | None = None) -> str:
    if not NAME_RE.fullmatch(name) or not version or any(ch.isspace() for ch in version):
        raise TransactionError("invalid package name/version")
    for label, value in (("source", source_sha256), ("recipe", recipe_sha256)):
        if not SHA_RE.fullmatch(value):
            raise TransactionError(f"{label} SHA-256 must be lowercase hexadecimal")
    root = _root(root_arg)
    stage, captured = _stage_entries(stage_arg)
    policy, policy_sha256 = _load_policy_snapshot(policy_path)
    with _lock(root):
        ledger = _ledger(root)
        claims = _claims(ledger)
        if any(r.get("package", {}).get("name") == name for r in ledger["records"]):
            raise TransactionError(f"package already has a fixture ownership record: {name}")
        txid = uuid.uuid4().hex
        txdir = root / JOURNAL_DIR / txid
        payload_dir = txdir / "payloads"
        backup_dir = txdir / "backups"
        transactions_dir = root / JOURNAL_DIR
        _ensure_private_dir(transactions_dir, root)
        _ensure_private_dir(txdir, transactions_dir)
        _ensure_private_dir(payload_dir, txdir)
        _ensure_private_dir(backup_dir, txdir)
        _fsync_dir(txdir)
        actions: list[dict[str, Any]] = []
        owned_entries: list[dict[str, Any]] = []
        used_policy: set[str] = set()
        numbered = 0
        for entry in captured:
            if entry["type"] == "directory":
                continue
            target = _target(root, entry["path"])
            before = _object(target)
            prior_owner_record = claims.get(entry["path"])
            prior_owner = prior_owner_record.get("package", {}).get("name") if prior_owner_record else None
            spec = policy["replacements"].get(entry["path"])
            if before is not None and _fingerprint(before) != _fingerprint({k: v for k, v in entry.items() if k not in ("path", "source")}):
                if spec is None or spec["old_fingerprint"] != _fingerprint(before) or spec["previous_owner"] != prior_owner:
                    raise TransactionError(f"differing existing path requires exact replace policy: {entry['path']}")
            elif prior_owner is not None and spec is None:
                raise TransactionError(f"path already owned by {prior_owner}; explicit transfer policy required: {entry['path']}")
            if spec is not None:
                if before is None or spec["old_fingerprint"] != _fingerprint(before) or spec["previous_owner"] != prior_owner:
                    raise TransactionError(f"replacement policy no longer matches live path/owner: {entry['path']}")
                used_policy.add(entry["path"])
            numbered += 1
            payload_name = f"{numbered:08d}.payload"
            payload = payload_dir / payload_name
            if entry["type"] == "file":
                _copy_payload(Path(entry["source"]), payload, entry)
                after_spec = {k: entry[k] for k in ("type", "mode", "uid", "gid", "size", "sha256", "mtime_ns")}
            else:
                after_spec = {k: entry[k] for k in ("type", "mode", "uid", "gid", "target", "mtime_ns")}
            backup_spec: dict[str, Any] | None = None
            if before is not None:
                backup_spec = {k: v for k, v in before.items() if k not in ("sha256", "size", "mtime_ns")}
                backup_spec["mtime_ns"] = before["mtime_ns"]
                if before["type"] == "file":
                    backup_name = f"{numbered:08d}.backup"
                    backup_path = backup_dir / backup_name
                    backup_metadata = _copy_backup(
                        target, backup_path, before, failpoint=failpoint, point_index=numbered
                    )
                    backup_spec.update(size=before["size"], sha256=before["sha256"], backup=backup_name,
                                       backup_metadata=backup_metadata)
                else:
                    backup_spec["target"] = before["target"]
            actions.append({
                "path": entry["path"], "before": backup_spec,
                "before_fingerprint": _fingerprint(before), "after": after_spec,
                "payload": payload_name if entry["type"] == "file" else None,
                "previous_owner": prior_owner,
                "replacement_approved": spec is not None,
            })
            owned_entries.append({"path": entry["path"], "object": after_spec})
        unused_policy = set(policy["replacements"]) - used_policy
        if unused_policy:
            raise TransactionError(f"unused replacement policy entries: {sorted(unused_policy)}")
        _fsync_dir(payload_dir)
        _fsync_dir(backup_dir)
        ledger_before = (root / LEDGER_NAME).read_bytes() if (root / LEDGER_NAME).exists() else _canonical_json({"schema": SCHEMA, "records": []})
        ledger_backup = txdir / "ledger.before.json"
        _atomic_write(ledger_backup, ledger_before)
        journal = {
            "schema": TX_SCHEMA, "transaction_id": txid, "state": "prepared",
            "package": {"name": name, "version": version, "source_sha256": source_sha256, "recipe_sha256": recipe_sha256},
            "stage_manifest_sha256": _sha_bytes(_canonical_json({"entries": [{k: v for k, v in e.items() if k != "source"} for e in captured]})),
            "policy_sha256": policy_sha256,
            "ledger_before_sha256": _sha_bytes(ledger_before), "actions": actions,
        }
        journal_path = txdir / "journal.json"
        _save_journal(journal_path, journal)
        _fsync_dir(txdir)
        _fail(failpoint, "after_prepared")
        try:
            for index, action in enumerate(actions):
                journal["state"] = "applying"
                journal["active_index"] = index
                journal["actions"][index]["status"] = "intent"
                _save_journal(journal_path, journal)
                _fail(failpoint, f"before_apply_{index}")
                item = {**action["after"], "path": action["path"], "payload": action["payload"]}
                _write_object(root, item, payload_dir)
                _fail(failpoint, f"after_replace_{index}")
                journal["actions"][index]["status"] = "applied"
                _save_journal(journal_path, journal)
                _fail(failpoint, f"after_applied_{index}")
            for action in actions:
                actual = _object(_target(root, action["path"]))
                expected = action["after"]
                normalized = {k: actual[k] for k in expected}
                if normalized != expected:
                    raise TransactionError(f"live recapture mismatch: {action['path']}")
            _fail(failpoint, "after_live_verify")
            new_ledger = _ledger(root)
            for action in actions:
                path = action["path"]
                if action["previous_owner"] is not None:
                    for record in new_ledger["records"]:
                        if record.get("package", {}).get("name") == action["previous_owner"]:
                            record["entries"] = [e for e in record["entries"] if e.get("path") != path]
            record = {
                "transaction_id": txid,
                "package": journal["package"],
                "stage_manifest_sha256": journal["stage_manifest_sha256"],
                "pre_commit_journal_sha256": _sha_file(journal_path),
                "entries": owned_entries,
                "shared_directories_owned": False,
            }
            new_ledger["records"].append(record)
            ledger_after_bytes = _canonical_json(new_ledger)
            journal["ledger_after_sha256"] = _sha_bytes(ledger_after_bytes)
            _save_journal(journal_path, journal)
            _atomic_write(root / LEDGER_NAME, ledger_after_bytes)
            _fail(failpoint, "after_ledger_write")
            _fail(failpoint, "before_commit_marker")
            journal["state"] = "committed"
            journal["committed_ledger_sha256"] = _sha_file(root / LEDGER_NAME)
            _save_journal(journal_path, journal)
            _fsync_dir(journal_path.parent)
            return txid
        except Exception:
            _recover_locked(root, txid)
            raise


def _recover_locked(root: Path, txid: str) -> str:
    jp = _journal_path(root, txid)
    journal = _load_json(jp, {})
    if journal.get("schema") != TX_SCHEMA or journal.get("transaction_id") != txid:
        raise TransactionError("invalid transaction journal")
    if journal.get("state") in ("committed", "rolled_back"):
        return journal["state"]
    txdir = jp.parent
    _verify_journal_backups(journal, txdir / "backups")
    ledger_path = root / LEDGER_NAME
    ledger = _ledger(root)
    record = next((r for r in ledger["records"] if r.get("transaction_id") == txid), None)
    all_post = True
    for action in journal.get("actions", []):
        try:
            actual = _object(_target(root, action["path"]))
        except (FileNotFoundError, TransactionError):
            actual = None
        expected = action["after"]
        if actual is None or {k: actual[k] for k in expected} != expected:
            all_post = False
            break
    expected_record_entries = [
        {"path": action["path"], "object": action["after"]}
        for action in journal.get("actions", [])
    ]
    record_matches = bool(
        record is not None
        and record.get("package") == journal.get("package")
        and record.get("stage_manifest_sha256") == journal.get("stage_manifest_sha256")
        and record.get("entries") == expected_record_entries
    )
    empty_ledger_hash = _sha_bytes(_canonical_json({"schema": SCHEMA, "records": []}))
    live_ledger_hash = _sha_file(ledger_path) if ledger_path.exists() else empty_ledger_hash
    before_ledger_hash = journal.get("ledger_before_sha256")
    after_ledger_hash = journal.get("ledger_after_sha256")
    if live_ledger_hash not in (before_ledger_hash, after_ledger_hash):
        raise TransactionError("ownership ledger differs from both recorded transaction boundaries; refusing recovery")
    if record_matches and all_post and live_ledger_hash == after_ledger_hash:
        journal["state"] = "committed"
        journal["committed_ledger_sha256"] = live_ledger_hash
        _save_journal(jp, journal)
        return "committed"
    # Preflight every target before restoring either the ledger or any path, so
    # an unknown third-party edit cannot cause a partial rollback.
    for action in journal.get("actions", []):
        target = _target(root, action["path"])
        current_fingerprint = _fingerprint(_object(target))
        if current_fingerprint not in (action["before_fingerprint"], _fingerprint(action["after"])):
            raise TransactionError(f"refusing recovery over unexpected object: {action['path']}")
    before_bytes = (txdir / "ledger.before.json").read_bytes()
    if _sha_bytes(before_bytes) != journal.get("ledger_before_sha256"):
        raise TransactionError("ledger preimage backup hash mismatch; refusing recovery")
    if live_ledger_hash != before_ledger_hash:
        _atomic_write(ledger_path, before_bytes)
    for action in reversed(journal.get("actions", [])):
        _restore(root, action, txdir / "backups")
    journal["state"] = "rolled_back"
    _save_journal(jp, journal)
    _fsync_dir(jp.parent)
    return "rolled_back"


def recover_transaction(root_arg: Path, txid: str) -> str:
    root = _root(root_arg)
    with _lock(root):
        return _recover_locked(root, txid)


def _cli() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    install = sub.add_parser("install")
    install.add_argument("--root", required=True, type=Path)
    install.add_argument("--stage", required=True, type=Path)
    install.add_argument("--name", required=True)
    install.add_argument("--version", required=True)
    install.add_argument("--source-sha256", required=True)
    install.add_argument("--recipe-sha256", required=True)
    install.add_argument("--replace-policy", type=Path)
    recover = sub.add_parser("recover")
    recover.add_argument("--root", required=True, type=Path)
    recover.add_argument("--transaction-id", required=True)
    args = parser.parse_args()
    try:
        if args.command == "install":
            txid = install_transaction(args.root, args.stage, name=args.name, version=args.version,
                                       source_sha256=args.source_sha256, recipe_sha256=args.recipe_sha256,
                                       policy_path=args.replace_policy)
            print(f"FIXTURE_TRANSACTION_COMMITTED id={txid}")
        else:
            state = recover_transaction(args.root, args.transaction_id)
            print(f"FIXTURE_TRANSACTION_RECOVERY state={state} id={args.transaction_id}")
    except (TransactionError, OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(_cli())
