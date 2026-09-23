"""Tests for alp_packagekit_backend.py's alp_* wrapper functions.

These are REAL integration tests -- they invoke the actual alp.py as a
subprocess (no mocking), because these wrapper functions have zero
PackageKit dependency; that's the whole point of separating them from
AlpPackageKitBackend (which cannot be imported/tested here -- no
`packagekit` module on this Windows host, see alp_packagekit_backend.py's
module docstring).

Known flakiness (Windows-only, environment/OS resource issue, not a code
bug): when the full test suite runs many subprocess-spawning tests back
to back on this Windows host, some runs hit `OSError: [WinError 6]`
(invalid handle) inside CPython's own subprocess module during handle
duplication. Every test in this file passes reliably when this file runs
alone (`pytest tests/test_packagekit_backend.py`), and the module under
test has no threads, no lingering handles, and no state that persists
between calls -- the flakiness is Windows' process/handle table under
rapid repeated subprocess creation in one pytest process, not alp.py or
alp_packagekit_backend.py. Re-run the file alone or re-run the suite if
you hit this.
"""

from __future__ import annotations

import io
import json
import os
import socket
import sys
import tarfile
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import alp  # noqa: E402
import alp_packagekit_backend as pkb  # noqa: E402

ALP_PY = Path(__file__).resolve().parent.parent / "alp.py"


def _make_tar(tmp_path: Path, name: str, members: dict[str, bytes]) -> Path:
    archive = tmp_path / name
    with tarfile.open(archive, "w:gz") as tf:
        for relpath, content in members.items():
            info = tarfile.TarInfo(relpath)
            info.size = len(content)
            tf.addfile(info, io.BytesIO(content))
    return archive


@pytest.fixture
def env(tmp_path: Path):
    root = tmp_path / "root"
    archive = _make_tar(tmp_path, "theme.tar.gz", {"usr/share/x": b"content"})
    index_path = tmp_path / "index.json"
    index_path.write_text(
        json.dumps({
            "schema_version": 1,
            "entries": {
                "theme": {
                    "method": "core", "name": "theme", "version": "1.0.0",
                    "url": "theme.tar.gz", "sha256": alp.sha256_of(archive),
                }
            },
        }),
        encoding="utf-8",
    )
    return {"root": root, "index": index_path}


def test_alp_search_finds_real_entry(env):
    hits = pkb.alp_search(ALP_PY, env["root"], env["index"], "the")
    assert hits == [{"name": "theme", "method": "core"}]


def test_alp_search_no_hits_returns_empty_list_not_error(env):
    hits = pkb.alp_search(ALP_PY, env["root"], env["index"], "zzz")
    assert hits == []


def test_alp_list_empty_before_install(env):
    assert pkb.alp_list(ALP_PY, env["root"], env["index"]) == []


def test_alp_install_list_info_remove_round_trip(env):
    pkb.alp_install(ALP_PY, env["root"], env["index"], "theme")

    listed = pkb.alp_list(ALP_PY, env["root"], env["index"])
    assert listed == [{"name": "theme", "version": "1.0.0", "method": "core", "status": "installed"}]

    info = pkb.alp_info(ALP_PY, env["root"], env["index"], "theme")
    assert info["version"] == "1.0.0"
    assert "/usr/share/x" in info["files"]

    pkb.alp_remove(ALP_PY, env["root"], env["index"], "theme")
    assert pkb.alp_list(ALP_PY, env["root"], env["index"]) == []


def test_alp_install_unknown_package_raises_backend_error(env):
    with pytest.raises(pkb.AlpBackendError, match="Bilinmeyen paket"):
        pkb.alp_install(ALP_PY, env["root"], env["index"], "ghost")


def test_alp_backend_error_detects_lock_contention(env):
    pkb.alp_install(ALP_PY, env["root"], env["index"], "theme")
    root = env["root"]
    lock_file = root / "var/lib/alp/alp.lock"
    lock_file.parent.mkdir(parents=True, exist_ok=True)
    # A live holder (this pytest process): a dead pid would now, correctly,
    # be cleared as a stale lock on POSIX instead of reported as contention.
    lock_file.write_text(f"pid={os.getpid()} host={socket.gethostname()} ts=fake\n", encoding="utf-8")
    try:
        with pytest.raises(pkb.AlpBackendError) as excinfo:
            pkb.alp_remove(ALP_PY, root, env["index"], "theme")
        assert excinfo.value.is_locked is True
    finally:
        lock_file.unlink(missing_ok=True)


def test_packagekit_glue_class_not_importable_here():
    """Documents, rather than hides, the real limitation: this environment
    has no `packagekit` module, so AlpPackageKitBackend is never defined.
    A real Linux/PackageKit environment (Codex's) must verify that class
    directly -- see alp_packagekit_backend.py's module docstring."""
    assert pkb.PACKAGEKIT_AVAILABLE is False
    assert not hasattr(pkb, "AlpPackageKitBackend")
