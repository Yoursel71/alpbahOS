"""SOURCE_DATE_EPOCH testleri: sabit build zamanıyla tekrarlanabilir db.json.

Kabul ölçütü (docs/handoffs/claude/infra-source-date-epoch-request-2026-10-01.md):
aynı SOURCE_DATE_EPOCH ile iki temiz kökün ham db.json baytları eşit olmalı;
epoch yokken gerçek saat, geçersiz epoch'ta ret (hiçbir şey yazılmadan).

Her "iki kök" testinde kökler FARKLI yollardadır ve kurulumlar arasında gerçek
saat >1 sn ilerler; böylece testler hem saat hem yol sızıntısını yakalar.
Gerçek ağa çıkılmaz. Gerçek `make` isteyen recipe testi make yoksa atlanır.
"""

from __future__ import annotations

import calendar
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import time
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import alp  # noqa: E402

ENV = "SOURCE_DATE_EPOCH"
EPOCH = 1_000_000_000
EPOCH_STAMP = "2001-09-09T01:46:40Z"
DB = "var/lib/alp/db.json"
SOURCE_SHA = "a" * 64
needs_make = pytest.mark.skipif(shutil.which("make") is None, reason="make yok")


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------

def _wall_gap() -> None:
    """Let the real clock move past the one-second timestamp resolution."""
    time.sleep(1.1)


def _stamp_seconds(stamp: str) -> int:
    return calendar.timegm(time.strptime(stamp, "%Y-%m-%dT%H:%M:%SZ"))


def _tar(path: Path, members: dict[str, bytes]) -> Path:
    with tarfile.open(path, "w:gz") as tf:
        made: set[str] = set()
        for rel, data in members.items():
            acc = ""
            for part in Path(rel).parts[:-1]:
                acc = f"{acc}/{part}" if acc else part
                if acc not in made:
                    made.add(acc)
                    d = tarfile.TarInfo(acc)
                    d.type, d.mode, d.mtime = tarfile.DIRTYPE, 0o755, 0
                    tf.addfile(d)
            info = tarfile.TarInfo(rel)
            info.size, info.mtime = len(data), 0
            tf.addfile(info, io.BytesIO(data))
    return path


def _core_index(tmp_path: Path, version: str = "1.0.0") -> Path:
    archive = _tar(tmp_path / f"demo-{version}.tar.gz", {
        "usr/share/demo/data.txt": f"data {version}\n".encode(),
        "usr/share/demo/more.txt": b"more\n",
    })
    index = tmp_path / f"index-{version}.json"
    index.write_text(json.dumps({"schema_version": 1, "entries": {"demo": {
        "method": "core", "name": "demo", "version": version,
        "url": archive.name, "sha256": alp.sha256_of(archive),
    }}}), encoding="utf-8")
    return index


def _alp(root: Path, index: Path, *argv: str) -> int:
    return alp.main(["--root", str(root), "--index", str(index), *argv])


def _db(root: Path) -> bytes:
    return (root / DB).read_bytes()


# --------------------------------------------------------------------------
# the acceptance criterion: raw db.json bytes
# --------------------------------------------------------------------------

def test_same_epoch_two_clean_roots_give_byte_identical_db(tmp_path, monkeypatch, capsys):
    monkeypatch.setenv(ENV, str(EPOCH))
    index = _core_index(tmp_path)
    root_a, root_b = tmp_path / "klon-a" / "kok", tmp_path / "baska-ad"
    assert _alp(root_a, index, "install", "demo") == 0
    _wall_gap()
    assert _alp(root_b, index, "install", "demo") == 0
    capsys.readouterr()

    assert _db(root_a) == _db(root_b)
    db = json.loads(_db(root_a))
    assert db["updated_at"] == EPOCH_STAMP
    assert db["packages"]["demo"]["installed_at"] == EPOCH_STAMP


def test_subprocess_cli_two_clean_roots_byte_identical(tmp_path):
    """The invocation Codex uses: a separate process with the variable in its environment."""
    index = _core_index(tmp_path)
    env = {**os.environ, ENV: "1756684800"}
    roots = [tmp_path / "ilk" / "kok", tmp_path / "ikinci"]
    for i, root in enumerate(roots):
        if i:
            _wall_gap()
        subprocess.run([sys.executable, alp.__file__, "--root", str(root), "--index", str(index), "install", "demo"],
                       check=True, env=env, capture_output=True)
    assert _db(roots[0]) == _db(roots[1])
    assert json.loads(_db(roots[0]))["updated_at"] == "2025-09-01T00:00:00Z"


def test_without_epoch_the_real_clock_is_used(tmp_path, monkeypatch, capsys):
    monkeypatch.delenv(ENV, raising=False)
    index = _core_index(tmp_path)
    root_a, root_b = tmp_path / "a", tmp_path / "b"
    before = int(time.time())
    assert _alp(root_a, index, "install", "demo") == 0
    after = int(time.time())
    _wall_gap()
    assert _alp(root_b, index, "install", "demo") == 0
    capsys.readouterr()

    db_a = json.loads(_db(root_a))
    assert before <= _stamp_seconds(db_a["packages"]["demo"]["installed_at"]) <= after
    assert before <= _stamp_seconds(db_a["updated_at"]) <= after
    # control: this is exactly the divergence the epoch removes
    assert _db(root_a) != _db(root_b)


def test_install_remove_reinstall_cycle_is_reproducible(tmp_path, monkeypatch, capsys):
    """Same sequence in two roots -> same bytes. (Not compared with a single
    install: remove leaves /usr and /usr/share on disk, so a reinstall no longer
    records them as its own -- ownership of pre-existing directories, not time.)"""
    monkeypatch.setenv(ENV, str(EPOCH))
    index = _core_index(tmp_path)
    roots = [tmp_path / "dongu-a", tmp_path / "dongu-b" / "kok"]
    for i, root in enumerate(roots):
        if i:
            _wall_gap()
        assert _alp(root, index, "install", "demo") == 0
        assert _alp(root, index, "remove", "demo") == 0
        if not i:
            _wall_gap()
        assert _alp(root, index, "install", "demo") == 0
    capsys.readouterr()
    assert _db(roots[0]) == _db(roots[1])
    db = json.loads(_db(roots[0]))
    assert db["updated_at"] == db["packages"]["demo"]["installed_at"] == EPOCH_STAMP


def test_upgrade_path_is_reproducible(tmp_path, monkeypatch, capsys):
    monkeypatch.setenv(ENV, str(EPOCH))
    v1, v2 = _core_index(tmp_path, "1.0.0"), _core_index(tmp_path, "2.0.0")
    roots = [tmp_path / "x" / "kok", tmp_path / "y"]
    for i, root in enumerate(roots):
        if i:
            _wall_gap()
        assert _alp(root, v1, "install", "demo") == 0
        _wall_gap()
        assert _alp(root, v2, "upgrade", "demo") == 0
    capsys.readouterr()
    assert _db(roots[0]) == _db(roots[1])
    assert json.loads(_db(roots[0]))["packages"]["demo"]["version"] == "2.0.0"


def test_adopt_base_is_reproducible(tmp_path, monkeypatch, capsys):
    monkeypatch.setenv(ENV, str(EPOCH))
    roots = [tmp_path / "lfs-a" / "kok", tmp_path / "lfs-b"]
    for root in roots:
        (root / "usr/bin").mkdir(parents=True)
        (root / "usr/bin/tool").write_bytes(b"existing LFS tool\n")
        (root / "usr/bin/tool").chmod(0o755)
    st = (roots[0] / "usr/bin/tool").lstat()
    owner = {"uid": st.st_uid, "gid": st.st_gid}
    manifest = tmp_path / "manifest.json"
    manifest.write_text(json.dumps({
        "schema": alp.BASE_MANIFEST_SCHEMA, "captured_at": "2026-09-24T00:00:00Z",
        "package": {"name": "tool", "version": "1.0",
                    "source": {"url": "https://example.invalid/tool-1.0.tar.xz", "sha256": SOURCE_SHA}},
        "entries": [
            {"path": "/usr", "type": "directory", "mode": 0o755, **owner},
            {"path": "/usr/bin", "type": "directory", "mode": 0o755, **owner},
            {"path": "/usr/bin/tool", "type": "file", "mode": 0o755, "size": 18,
             "sha256": alp.sha256_of(roots[0] / "usr/bin/tool"), **owner},
        ],
    }), encoding="utf-8")
    for i, root in enumerate(roots):
        if i:
            _wall_gap()
        assert alp.main(["--root", str(root), "adopt-base", "--manifest", str(manifest), "--name", "tool",
                         "--version", "1.0", "--source-sha256", SOURCE_SHA]) == 0
    capsys.readouterr()
    assert _db(roots[0]) == _db(roots[1])
    assert json.loads(_db(roots[0]))["packages"]["tool"]["installed_at"] == EPOCH_STAMP


@needs_make
def test_recipe_install_is_reproducible_and_log_path_is_root_independent(tmp_path, monkeypatch, capsys):
    monkeypatch.setenv(ENV, str(EPOCH))
    makefile = ("prefix ?= /usr\n"
                "install:\n"
                "\tmkdir -p $(DESTDIR)$(prefix)/share/demo\n"
                "\tprintf 'data\\n' > $(DESTDIR)$(prefix)/share/demo/data.txt\n")
    archive = tmp_path / "demo.tar.gz"
    with tarfile.open(archive, "w:gz") as tf:
        info = tarfile.TarInfo("demo-1.0/Makefile")
        info.size, info.mtime = len(makefile.encode()), 0
        tf.addfile(info, io.BytesIO(makefile.encode()))
    (tmp_path / "demo.recipe.json").write_text(json.dumps({
        "name": "demo", "version": "1.0", "source_url": archive.name, "sha256": alp.sha256_of(archive),
        "build": {"configure": ["true"], "make": ["true"], "make_install": ["make", "install"]},
    }), encoding="utf-8")
    index = tmp_path / "index.json"
    index.write_text(json.dumps({"schema_version": 1, "entries": {"demo": {
        "method": "recipe", "name": "demo", "version": "1.0", "recipe": "demo.recipe.json"}}}), encoding="utf-8")

    roots = [tmp_path / "rcp-a" / "kok", tmp_path / "rcp-b"]
    for i, root in enumerate(roots):
        if i:
            _wall_gap()
        assert _alp(root, index, "install", "demo") == 0
    capsys.readouterr()

    assert _db(roots[0]) == _db(roots[1])
    record = json.loads(_db(roots[0]))["packages"]["demo"]
    assert record["installed_at"] == EPOCH_STAMP
    assert record["build"]["log_path"] == "/var/log/alp/demo-1.0.build.log"
    assert (roots[0] / "var/log/alp/demo-1.0.build.log").is_file()  # the recorded path is valid inside the root


# --------------------------------------------------------------------------
# validation: a bad value stops alp before anything is written
# --------------------------------------------------------------------------

@pytest.mark.parametrize("bad", [
    "", " 1", "1 ", "1\n", "-1", "+1", "1.5", "1e9", "0x10", "abc", "١٢٣",  # not plain ASCII digits
    "253402300800",  # one second past 9999-12-31T23:59:59Z
    "1" * 13,
])
def test_malformed_epoch_is_rejected_before_anything_is_written(tmp_path, monkeypatch, capsys, bad):
    monkeypatch.setenv(ENV, bad)
    index = _core_index(tmp_path)
    root = tmp_path / "root"
    assert _alp(root, index, "install", "demo") == 1
    assert f"{ENV} geçersiz" in capsys.readouterr().err
    assert not root.exists()  # no state dir, no db, no lock, no installed file


def test_malformed_epoch_also_stops_read_only_commands_but_not_help(tmp_path, monkeypatch, capsys):
    monkeypatch.setenv(ENV, "yarin")
    index = _core_index(tmp_path)
    assert _alp(tmp_path / "root", index, "list") == 1
    assert f"{ENV} geçersiz" in capsys.readouterr().err
    assert alp.main(["help", "gelistirici"]) == 0
    assert ENV in capsys.readouterr().out  # the variable is documented in the developer help


def test_subprocess_malformed_epoch_exits_1_without_writing(tmp_path):
    index = _core_index(tmp_path)
    root = tmp_path / "root"
    proc = subprocess.run([sys.executable, alp.__file__, "--root", str(root), "--index", str(index), "install", "demo"],
                          env={**os.environ, ENV: "-5"}, capture_output=True, text=True)
    assert proc.returncode == 1
    assert f"{ENV} geçersiz" in proc.stderr
    assert not root.exists()


@pytest.mark.parametrize("value, stamp", [
    ("0", "1970-01-01T00:00:00Z"),
    (str(EPOCH), EPOCH_STAMP),
    ("253402300799", "9999-12-31T23:59:59Z"),
])
def test_valid_epoch_bounds(monkeypatch, value, stamp):
    monkeypatch.setenv(ENV, value)
    assert alp.source_date_epoch() == int(value)
    assert alp._now() == stamp


def test_unset_means_real_clock(monkeypatch):
    monkeypatch.delenv(ENV, raising=False)
    assert alp.source_date_epoch() is None
    assert abs(_stamp_seconds(alp._now()) - time.time()) < 5


# --------------------------------------------------------------------------
# what must NOT follow the fixed clock
# --------------------------------------------------------------------------

def test_lock_holder_line_keeps_the_real_clock(tmp_path, monkeypatch):
    monkeypatch.setenv(ENV, str(EPOCH))
    paths = alp.Paths.resolve(str(tmp_path / "root"))
    paths.ensure()
    with alp.DbLock(paths.lock_file):
        holder = paths.lock_file.read_text(encoding="utf-8")
    stamp = re.search(r"ts=(\S+)", holder).group(1)
    assert stamp != EPOCH_STAMP
    assert abs(_stamp_seconds(stamp) - time.time()) < 5


def test_rollback_journal_dir_name_ignores_the_fixed_clock(tmp_path, monkeypatch):
    """The name is a uniqueness key; frozen at the epoch it would repeat."""
    monkeypatch.setenv(ENV, str(EPOCH))
    paths = alp.Paths.resolve(str(tmp_path / "root"))
    paths.ensure()
    before_ms = int(time.time() * 1000)
    with alp._transaction(paths, "demo") as journal:
        first_field = int(journal.dir.name.split("-")[0])
    assert first_field >= before_ms


def test_target_path_is_the_path_inside_the_root(tmp_path):
    real = alp.Paths.resolve("/")
    assert alp._target_path(real, real.log_dir / "x.build.log") == "/var/log/alp/x.build.log"
    scratch = alp.Paths.resolve(str(tmp_path / "root"))
    assert alp._target_path(scratch, scratch.log_dir / "x.build.log") == "/var/log/alp/x.build.log"
