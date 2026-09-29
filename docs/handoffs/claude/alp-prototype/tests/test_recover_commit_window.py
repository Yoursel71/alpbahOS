"""`alp recover` must agree with db.json about a transaction that was cut short.

Found in the 29 Sep 2026 audit (handoff 020): a transaction saves db.json first
and writes the journal's `commit` marker afterwards. A process that died in
that window left a journal without a marker, so `alp recover` deleted the files
of a package db.json still listed (`alp list` showed it, `alp check` said
"sorun yok", `alp install` said "zaten kurulu"); a full disk on the commit
write did the same. Removal had the mirror image: recover put back the files of
a package the db no longer knew.

The db record is now announced in the journal (`FileJournal.expect_db`) right
before save_db, and recover treats the transaction as committed when db.json
already holds that record. `alp check` also reports owned files that are gone.
"""

from __future__ import annotations

import errno
import io
import json
import os
import sys
import tarfile
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import alp  # noqa: E402


class Crash(BaseException):
    """Stands in for kill -9: not an Exception, so no handler cleans up."""


def _catalog(tmp_path: Path) -> Path:
    archive = tmp_path / "demo-1.tar.gz"
    with tarfile.open(archive, "w:gz") as tf:
        for name in ("usr", "usr/share", "usr/share/demo"):
            info = tarfile.TarInfo(name)
            info.type = tarfile.DIRTYPE
            info.mode = 0o755
            tf.addfile(info)
        data = b"hello\n"
        info = tarfile.TarInfo("usr/share/demo/data.txt")
        info.size = len(data)
        info.mode = 0o644
        tf.addfile(info, io.BytesIO(data))
    index = tmp_path / "index.json"
    index.write_text(json.dumps({"entries": {"demo": {
        "method": "core", "name": "demo", "version": "1",
        "url": archive.name, "sha256": alp.sha256_of(archive),
    }}}), encoding="utf-8")
    return index


def _alp(tmp_path: Path, index: Path, *argv: str) -> int:
    return alp.main(["--root", str(tmp_path / "root"), "--index", str(index), *argv])


def _installed(tmp_path: Path) -> bool:
    db = tmp_path / "root" / "var" / "lib" / "alp" / "db.json"
    return "demo" in json.loads(db.read_text(encoding="utf-8"))["packages"]


def _file(tmp_path: Path) -> Path:
    return tmp_path / "root" / "usr" / "share" / "demo" / "data.txt"


def _crash_at_commit(monkeypatch) -> None:
    def die(self):
        raise Crash

    monkeypatch.setattr(alp.FileJournal, "commit", die)


def test_crash_between_db_save_and_commit_keeps_the_install(tmp_path, monkeypatch, capsys):
    index = _catalog(tmp_path)
    with monkeypatch.context() as m:
        _crash_at_commit(m)
        with pytest.raises(Crash):
            _alp(tmp_path, index, "install", "--yes", "demo")
    assert _installed(tmp_path) and _file(tmp_path).exists()

    assert _alp(tmp_path, index, "recover") == 0

    assert _installed(tmp_path), "db.json still lists the package"
    assert _file(tmp_path).exists(), "recover must not delete the files of a package db.json lists"
    assert alp.pending_journals(alp.Paths.resolve(str(tmp_path / "root"))) == []
    assert _alp(tmp_path, index, "check") == 0


def test_crash_before_db_save_is_still_rolled_back(tmp_path, monkeypatch):
    index = _catalog(tmp_path)

    def crash_on_save(paths, db):
        raise Crash

    with monkeypatch.context() as m:
        m.setattr(alp, "save_db", crash_on_save)
        m.setattr(alp, "undo_journal", lambda *a, **k: ["simulated kill: nothing was undone"])
        with pytest.raises(Crash):
            _alp(tmp_path, index, "install", "--yes", "demo")
    assert _file(tmp_path).exists(), "the files were written before the simulated kill"

    assert _alp(tmp_path, index, "recover") == 0

    assert not _file(tmp_path).exists()
    db = tmp_path / "root" / "var" / "lib" / "alp" / "db.json"
    assert not db.exists() or "demo" not in json.loads(db.read_text(encoding="utf-8"))["packages"]


def test_crash_between_db_save_and_commit_keeps_the_removal(tmp_path, monkeypatch):
    index = _catalog(tmp_path)
    assert _alp(tmp_path, index, "install", "--yes", "demo") == 0
    with monkeypatch.context() as m:
        _crash_at_commit(m)
        with pytest.raises(Crash):
            _alp(tmp_path, index, "remove", "--yes", "demo")
    assert not _installed(tmp_path) and not _file(tmp_path).exists()

    assert _alp(tmp_path, index, "recover") == 0

    assert not _installed(tmp_path)
    assert not _file(tmp_path).exists(), "recover must not resurrect the files of a package the db no longer lists"


def test_commit_write_failure_after_db_save_does_not_undo_the_install(tmp_path, monkeypatch):
    index = _catalog(tmp_path)

    def disk_full(self):
        raise OSError(errno.ENOSPC, "No space left on device")

    with monkeypatch.context() as m:
        m.setattr(alp.FileJournal, "commit", disk_full)
        assert _alp(tmp_path, index, "install", "--yes", "demo") == 0

    assert _installed(tmp_path) and _file(tmp_path).exists()
    assert alp.pending_journals(alp.Paths.resolve(str(tmp_path / "root"))) == []


def test_recover_ignores_a_later_protect_flag(tmp_path, monkeypatch):
    """`alp protect` does not wait for pending journals and rewrites the record;
    recover must still recognise its own transaction."""
    index = _catalog(tmp_path)
    with monkeypatch.context() as m:
        _crash_at_commit(m)
        with pytest.raises(Crash):
            _alp(tmp_path, index, "install", "--yes", "demo")
    assert _alp(tmp_path, index, "protect", "demo") == 0

    assert _alp(tmp_path, index, "recover") == 0

    assert _installed(tmp_path) and _file(tmp_path).exists()


def test_check_reports_owned_files_that_are_gone(tmp_path, capsys):
    index = _catalog(tmp_path)
    assert _alp(tmp_path, index, "install", "--yes", "demo") == 0
    assert _alp(tmp_path, index, "check") == 0

    _file(tmp_path).unlink()
    capsys.readouterr()
    assert _alp(tmp_path, index, "check") == 1

    out = capsys.readouterr().out
    assert "SORUN" in out and "demo" in out and "/usr/share/demo/data.txt" in out


@pytest.mark.skipif(os.name != "posix", reason="POSIX only")
def test_check_counts_a_dangling_symlink_as_present(tmp_path):
    index = _catalog(tmp_path)
    assert _alp(tmp_path, index, "install", "--yes", "demo") == 0
    db_path = tmp_path / "root" / "var" / "lib" / "alp" / "db.json"
    db = json.loads(db_path.read_text(encoding="utf-8"))
    link = tmp_path / "root" / "usr" / "share" / "demo" / "dangling"
    os.symlink("/nonexistent/target", link)
    db["packages"]["demo"]["files"].append("/usr/share/demo/dangling")
    db["packages"]["demo"]["symlinks"] = ["/usr/share/demo/dangling"]
    db_path.write_text(json.dumps(db), encoding="utf-8")

    assert _alp(tmp_path, index, "check") == 0
