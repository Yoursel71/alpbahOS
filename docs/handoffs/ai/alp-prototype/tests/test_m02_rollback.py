"""M02 tests: transactional rollback, `alp recover`, protected packages,
`alp update` and build cleanup.

Same rules as test_alp.py: no network, real tarballs and real files under
tmp_path. Failures are injected either by making a real write fail (a
read-only directory, POSIX non-root only) or by making _copy_entry raise the
OSError a full disk would.
"""

from __future__ import annotations

import argparse
import io
import json
import os
import sys
import tarfile
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import alp  # noqa: E402

POSIX_USER = os.name == "posix" and hasattr(os, "geteuid") and os.geteuid() != 0


def _make_archive(tmp_path: Path, name: str, version: str, files: dict[str, str], *, link: str | None = None) -> dict:
    """A core package shipping `files` (relative path -> text)."""
    archive = tmp_path / f"{name}-{version}.tar.gz"
    with tarfile.open(archive, "w:gz") as tf:
        seen: set[str] = set()
        for rel in files:
            parts = rel.split("/")
            for i in range(1, len(parts)):
                d = "/".join(parts[:i])
                if d not in seen:
                    seen.add(d)
                    info = tarfile.TarInfo(d)
                    info.type = tarfile.DIRTYPE
                    info.mode = 0o755
                    tf.addfile(info)
            data = files[rel].encode()
            info = tarfile.TarInfo(rel)
            info.size = len(data)
            info.mode = 0o644
            tf.addfile(info, io.BytesIO(data))
        if link:
            info = tarfile.TarInfo(link.split("->")[0].strip())
            info.type = tarfile.SYMTYPE
            info.linkname = link.split("->")[1].strip()
            tf.addfile(info)
    return {"method": "core", "name": name, "version": version, "url": archive.name, "sha256": alp.sha256_of(archive)}


@pytest.fixture
def paths(tmp_path: Path) -> alp.Paths:
    p = alp.Paths.resolve(str(tmp_path / "root"))
    p.ensure()
    return p


def _ns(**kw) -> argparse.Namespace:
    base = {"dry_run": False, "reinstall": False, "yes": True, "cascade": False, "name": None, "source": None, "sha256": None}
    base.update(kw)
    return argparse.Namespace(**base)


def _root(paths: alp.Paths, rel: str) -> Path:
    return paths.root / rel


def _snapshot(root: Path) -> dict[str, str]:
    """Everything under root except alp's own state, as {path: content|->link}."""
    out: dict[str, str] = {}
    for p in sorted(root.rglob("*")):
        rel = p.relative_to(root).as_posix()
        if rel.startswith("var/lib/alp") or rel.startswith("var/log/alp"):
            continue
        if p.is_symlink():
            out[rel] = "->" + os.readlink(p)
        elif p.is_dir():
            out[rel] = "<dir>"
        else:
            out[rel] = p.read_text()
    return out


def _fail_on_nth_copy(monkeypatch, n: int) -> None:
    real = alp._copy_entry
    calls = {"n": 0}

    def wrapper(src, dst):
        calls["n"] += 1
        if calls["n"] == n:
            raise OSError(28, "No space left on device")
        real(src, dst)

    monkeypatch.setattr(alp, "_copy_entry", wrapper)


V1_FILES = {"usr/bin/tool": "tool v1", "usr/share/tool/old.txt": "only in v1", "usr/share/tool/keep.txt": "keep v1"}
V2_FILES = {"usr/bin/tool": "tool v2", "usr/share/tool/keep.txt": "keep v2", "usr/share/tool/new.txt": "new in v2"}


def _install_v1_then_offer_v2(paths, tmp_path):
    entries = {"tool": _make_archive(tmp_path, "tool", "1.0.0", V1_FILES)}
    alp.cmd_install(_ns(name="tool"), paths, {"entries": entries}, tmp_path)
    entries["tool"] = _make_archive(tmp_path, "tool", "2.0.0", V2_FILES)
    return entries


# --------------------------------------------------------------------------
# rollback
# --------------------------------------------------------------------------

def test_failed_upgrade_restores_every_file_and_the_db(paths, tmp_path, monkeypatch):
    entries = _install_v1_then_offer_v2(paths, tmp_path)
    before = _snapshot(paths.root)
    _fail_on_nth_copy(monkeypatch, 2)  # dies after the first file of v2 was already written

    with pytest.raises(alp.AlpError):
        alp.cmd_upgrade(_ns(name="tool"), paths, {"entries": entries}, tmp_path)

    assert _snapshot(paths.root) == before
    assert alp.load_db(paths)["packages"]["tool"]["version"] == "1.0.0"
    assert not alp.pending_journals(paths)
    assert not (paths.state_dir / alp.ROLLBACK_DIR).exists() or not any((paths.state_dir / alp.ROLLBACK_DIR).iterdir())


def test_failed_fresh_install_leaves_no_partial_files_or_directories(paths, tmp_path, monkeypatch):
    entries = {"tool": _make_archive(tmp_path, "tool", "1.0.0", V1_FILES)}
    before = _snapshot(paths.root)
    _fail_on_nth_copy(monkeypatch, 2)

    with pytest.raises(alp.AlpError):
        alp.cmd_install(_ns(name="tool"), paths, {"entries": entries}, tmp_path)

    assert _snapshot(paths.root) == before  # not even the usr/... directories the merge created
    assert alp.load_db(paths)["packages"] == {}


def test_db_save_failure_after_files_were_written_rolls_files_back(paths, tmp_path, monkeypatch):
    entries = _install_v1_then_offer_v2(paths, tmp_path)
    before = _snapshot(paths.root)

    def boom(*a, **k):
        raise OSError(5, "I/O error")

    monkeypatch.setattr(alp, "save_db", boom)
    with pytest.raises(OSError):
        alp.cmd_upgrade(_ns(name="tool"), paths, {"entries": entries}, tmp_path)

    # v2 wrote new.txt, replaced two files and dropped old.txt -- all undone
    assert _snapshot(paths.root) == before
    monkeypatch.undo()
    assert alp.load_db(paths)["packages"]["tool"]["version"] == "1.0.0"


def test_failed_remove_restores_the_files(paths, tmp_path, monkeypatch):
    entries = {"tool": _make_archive(tmp_path, "tool", "1.0.0", V1_FILES)}
    alp.cmd_install(_ns(name="tool"), paths, {"entries": entries}, tmp_path)
    before = _snapshot(paths.root)

    real_save = alp.save_db
    monkeypatch.setattr(alp, "save_db", lambda *a, **k: (_ for _ in ()).throw(OSError(5, "I/O error")))
    with pytest.raises(OSError):
        alp.cmd_remove(_ns(name="tool"), paths, {"entries": entries})
    monkeypatch.setattr(alp, "save_db", real_save)

    assert _snapshot(paths.root) == before
    assert "tool" in alp.load_db(paths)["packages"]


@pytest.mark.skipif(os.name != "posix", reason="symlinks in tar archives need POSIX")
def test_rollback_restores_a_replaced_symlink(paths, tmp_path, monkeypatch):
    v1 = _make_archive(tmp_path, "tool", "1.0.0", {"usr/share/tool/a": "a"}, link="usr/share/tool/current -> a")
    entries = {"tool": v1}
    alp.cmd_install(_ns(name="tool"), paths, {"entries": entries}, tmp_path)
    entries["tool"] = _make_archive(tmp_path, "tool", "2.0.0", {"usr/share/tool/a": "a2", "usr/share/tool/b": "b"},
                                    link="usr/share/tool/current -> b")
    before = _snapshot(paths.root)
    assert before["usr/share/tool/current"] == "->a"
    _fail_on_nth_copy(monkeypatch, 3)

    with pytest.raises(alp.AlpError):
        alp.cmd_upgrade(_ns(name="tool"), paths, {"entries": entries}, tmp_path)

    assert _snapshot(paths.root) == before


@pytest.mark.skipif(not POSIX_USER, reason="needs POSIX permissions and a non-root user")
def test_real_permission_failure_mid_upgrade_rolls_back(paths, tmp_path):
    entries = _install_v1_then_offer_v2(paths, tmp_path)
    before = _snapshot(paths.root)
    locked = _root(paths, "usr/share/tool")  # v2 must write keep.txt and new.txt here
    os.chmod(locked, 0o555)
    try:
        with pytest.raises(alp.AlpError):
            alp.cmd_upgrade(_ns(name="tool"), paths, {"entries": entries}, tmp_path)
    finally:
        os.chmod(locked, 0o755)

    assert _snapshot(paths.root) == before
    assert alp.load_db(paths)["packages"]["tool"]["version"] == "1.0.0"


def test_successful_upgrade_leaves_no_journal_behind(paths, tmp_path):
    entries = _install_v1_then_offer_v2(paths, tmp_path)
    alp.cmd_upgrade(_ns(name="tool"), paths, {"entries": entries}, tmp_path)
    assert (_root(paths, "usr/bin/tool")).read_text() == "tool v2"
    assert not (_root(paths, "usr/share/tool/old.txt")).exists()
    assert not alp.pending_journals(paths)


# --------------------------------------------------------------------------
# recover: a process killed mid-transaction
# --------------------------------------------------------------------------

def _simulate_killed_upgrade(paths: alp.Paths, *, commit: bool) -> tuple[Path, dict]:
    target = paths.root / "usr" / "bin" / "tool"
    target.parent.mkdir(parents=True)
    target.write_text("old")
    fresh = paths.root / "usr" / "bin" / "fresh"
    before = _snapshot(paths.root)
    journal = alp.FileJournal(paths.state_dir / alp.ROLLBACK_DIR / "111-1-tool")
    journal.will_write(target)
    journal.will_write(fresh)
    # alp never writes in place: a temp sibling is renamed over the target, so
    # the backup (a hard link to the old inode) keeps the old content.
    tmp = alp._tmp_name(target)
    tmp.write_text("new")
    os.replace(tmp, target)
    fresh.write_text("brand new")
    if commit:
        journal.commit()
    journal.close()  # ...and the process dies here, no undo, no cleanup
    return target, before


def test_recover_undoes_a_killed_transaction(paths):
    _, before = _simulate_killed_upgrade(paths, commit=False)
    assert alp.pending_journals(paths)

    assert alp.cmd_recover(_ns(), paths) == 0

    assert _snapshot(paths.root) == before
    assert not alp.pending_journals(paths)


def test_recover_does_not_undo_a_committed_transaction(paths):
    target, _ = _simulate_killed_upgrade(paths, commit=True)
    assert alp.cmd_recover(_ns(), paths) == 0
    assert target.read_text() == "new"  # the db was saved before the commit marker: keep the new files


def test_journal_with_a_truncated_last_line_still_undoes_the_rest(paths):
    target, before = _simulate_killed_upgrade(paths, commit=False)
    log = paths.state_dir / alp.ROLLBACK_DIR / "111-1-tool" / alp.JOURNAL_NAME
    with open(log, "a", encoding="utf-8") as f:
        f.write('["created", "/half-writt')  # kill -9 in the middle of a line
    assert alp.undo_journal(log) == []
    assert _snapshot(paths.root) == before


def test_mutating_commands_refuse_while_a_journal_is_pending(paths, tmp_path):
    _simulate_killed_upgrade(paths, commit=False)
    entries = {"tool": _make_archive(tmp_path, "tool", "1.0.0", V1_FILES)}
    with pytest.raises(alp.AlpError, match="alp recover"):
        alp.cmd_install(_ns(name="tool"), paths, {"entries": entries}, tmp_path)
    with pytest.raises(alp.AlpError, match="alp recover"):
        alp.cmd_remove(_ns(name="tool"), paths, {"entries": entries})


def test_check_reports_a_pending_journal(paths, tmp_path, capsys):
    _simulate_killed_upgrade(paths, commit=False)
    assert alp.cmd_check(paths, {"entries": {}}, tmp_path) == 1
    assert "alp recover" in capsys.readouterr().out


def test_recover_with_nothing_pending_is_a_noop(paths, capsys):
    assert alp.cmd_recover(_ns(), paths) == 0
    assert "yok" in capsys.readouterr().out


# --------------------------------------------------------------------------
# protected packages
# --------------------------------------------------------------------------

def _two_packages(paths, tmp_path, **extra_lib):
    lib = _make_archive(tmp_path, "libbase", "1.0.0", {"usr/lib/libbase.txt": "lib"})
    lib.update(extra_lib)
    app = _make_archive(tmp_path, "app", "1.0.0", {"usr/bin/app": "app"})
    app["depends"] = ["libbase"]
    entries = {"libbase": lib, "app": app}
    alp.cmd_install(_ns(name="app"), paths, {"entries": entries}, tmp_path)
    return entries


def test_protected_package_cannot_be_removed(paths, tmp_path):
    entries = {"tool": _make_archive(tmp_path, "tool", "1.0.0", V1_FILES, ) | {"protected": True}}
    alp.cmd_install(_ns(name="tool"), paths, {"entries": entries}, tmp_path)
    assert alp.load_db(paths)["packages"]["tool"]["protected"] is True

    with pytest.raises(alp.AlpError, match="korumalı"):
        alp.cmd_remove(_ns(name="tool"), paths, {"entries": entries})
    assert (_root(paths, "usr/bin/tool")).exists()


def test_cascade_refuses_when_a_dependent_is_protected(paths, tmp_path):
    entries = _two_packages(paths, tmp_path)
    alp.cmd_protect(_ns(name="app"), paths, protect=True)

    with pytest.raises(alp.AlpError, match="app korumalı"):
        alp.cmd_remove(_ns(name="libbase", cascade=True), paths, {"entries": entries})
    assert (_root(paths, "usr/lib/libbase.txt")).exists()


def test_unprotect_allows_removal_again(paths, tmp_path):
    entries = {"tool": _make_archive(tmp_path, "tool", "1.0.0", V1_FILES)}
    alp.cmd_install(_ns(name="tool"), paths, {"entries": entries}, tmp_path)
    alp.cmd_protect(_ns(name="tool"), paths, protect=True)
    with pytest.raises(alp.AlpError):
        alp.cmd_remove(_ns(name="tool"), paths, {"entries": entries})
    alp.cmd_protect(_ns(name="tool"), paths, protect=False)
    alp.cmd_remove(_ns(name="tool"), paths, {"entries": entries})
    assert alp.load_db(paths)["packages"] == {}


def test_autoremove_skips_a_protected_orphan(paths, tmp_path):
    entries = _two_packages(paths, tmp_path)
    alp.cmd_protect(_ns(name="libbase"), paths, protect=True)
    alp.cmd_remove(_ns(name="app"), paths, {"entries": entries})  # libbase is now an orphan dependency

    alp.cmd_autoremove(_ns(), paths, {"entries": entries})

    assert "libbase" in alp.load_db(paths)["packages"]


def test_protect_of_a_missing_package_is_an_error(paths):
    with pytest.raises(alp.AlpError, match="Kurulu değil"):
        alp.cmd_protect(_ns(name="nope"), paths, protect=True)


def test_protected_survives_upgrade_and_list_json_only_shows_it_when_true(paths, tmp_path, capsys):
    entries = _install_v1_then_offer_v2(paths, tmp_path)
    alp.cmd_protect(_ns(name="tool"), paths, protect=True)
    alp.cmd_upgrade(_ns(name="tool"), paths, {"entries": entries}, tmp_path)
    assert alp.load_db(paths)["packages"]["tool"]["protected"] is True

    capsys.readouterr()  # drop the upgrade's own output
    alp.cmd_list(alp.load_db(paths), as_json=True)
    rows = json.loads(capsys.readouterr().out)
    assert rows[0]["protected"] is True
    alp.cmd_protect(_ns(name="tool"), paths, protect=False)
    capsys.readouterr()  # drop the "no longer protected" message
    alp.cmd_list(alp.load_db(paths), as_json=True)
    assert "protected" not in json.loads(capsys.readouterr().out)[0]  # JSON contract unchanged


# --------------------------------------------------------------------------
# update
# --------------------------------------------------------------------------

def _catalog_dir(tmp_path: Path, name: str, entries: dict) -> Path:
    d = tmp_path / name
    d.mkdir()
    (d / "index.json").write_text(json.dumps({"schema_version": 1, "entries": entries}))
    return d


def _bundle(tmp_path: Path, name: str, index: dict, extra: dict[str, bytes] | None = None) -> Path:
    out = tmp_path / f"{name}.tar.gz"
    with tarfile.open(out, "w:gz") as tf:
        data = json.dumps(index).encode()
        info = tarfile.TarInfo("index.json")
        info.size = len(data)
        tf.addfile(info, io.BytesIO(data))
        for rel, blob in (extra or {}).items():
            info = tarfile.TarInfo(rel)
            info.size = len(blob)
            tf.addfile(info, io.BytesIO(blob))
    return out


def test_update_from_a_bundle_replaces_index_and_reports_changes(paths, tmp_path, capsys):
    catalog = tmp_path / "cat"
    catalog.mkdir()
    old_entry = _make_archive(catalog, "tool", "1.0.0", V1_FILES)  # url is relative to the catalog dir
    (catalog / "index.json").write_text(json.dumps({"schema_version": 1, "entries": {"tool": old_entry}}))
    index_path = catalog / "index.json"
    alp.cmd_install(_ns(name="tool"), paths, alp.load_index(index_path), catalog)

    upstream = tmp_path / "upstream"
    upstream.mkdir()
    new_entry = _make_archive(upstream, "tool", "2.0.0", V2_FILES)
    other = _make_archive(upstream, "extra", "0.1.0", {"usr/share/extra": "x"})
    bundle = _bundle(tmp_path, "bundle", {"schema_version": 1, "entries": {"tool": new_entry, "extra": other}},
                     extra={new_entry["url"]: (upstream / new_entry["url"]).read_bytes(),
                            other["url"]: (upstream / other["url"]).read_bytes()})

    assert alp.cmd_update(_ns(source=str(bundle)), paths, index_path, alp.load_index(index_path)) == 0
    out = capsys.readouterr().out

    assert "değişti   tool 1.0.0 -> 2.0.0" in out
    assert "yeni      extra 0.1.0" in out
    assert "güncelleme var: tool 1.0.0 -> 2.0.0" in out
    now = alp.load_index(index_path)
    assert now["entries"]["tool"]["version"] == "2.0.0"
    assert (catalog / (index_path.name + ".prev")).exists()
    assert (catalog / new_entry["url"]).exists()
    assert not (catalog / ".alp-update").exists()  # work dir cleaned up
    # and the freshly updated catalog really upgrades
    alp.cmd_upgrade(_ns(name="tool"), paths, now, catalog)
    assert (_root(paths, "usr/bin/tool")).read_text() == "tool v2"


def test_update_dry_run_changes_nothing(paths, tmp_path, capsys):
    catalog = _catalog_dir(tmp_path, "cat", {"tool": _make_archive(tmp_path, "tool", "1.0.0", V1_FILES)})
    index_path = catalog / "index.json"
    before = index_path.read_text()
    newer = _make_archive(tmp_path, "tool", "2.0.0", V2_FILES)
    src = tmp_path / "new-index.json"
    src.write_text(json.dumps({"schema_version": 1, "entries": {"tool": newer}}))

    alp.cmd_update(_ns(source=str(src), dry_run=True), paths, index_path, alp.load_index(index_path))

    assert index_path.read_text() == before
    assert "dry-run" in capsys.readouterr().out


def test_update_plain_index_json(paths, tmp_path):
    catalog = _catalog_dir(tmp_path, "cat", {"tool": _make_archive(tmp_path, "tool", "1.0.0", V1_FILES)})
    index_path = catalog / "index.json"
    newer = _make_archive(tmp_path, "tool", "2.0.0", V2_FILES)
    src = tmp_path / "new-index.json"
    src.write_text(json.dumps({"schema_version": 1, "entries": {"tool": newer}}))

    alp.cmd_update(_ns(source=str(src)), paths, index_path, alp.load_index(index_path))

    assert alp.load_index(index_path)["entries"]["tool"]["version"] == "2.0.0"


def test_update_refuses_http_without_even_downloading(paths, tmp_path, monkeypatch):
    catalog = _catalog_dir(tmp_path, "cat", {})
    index_path = catalog / "index.json"

    def must_not_download(*a, **k):
        raise AssertionError("http:// must be refused before any download")

    monkeypatch.setattr(alp, "_download_raw", must_not_download)
    with pytest.raises(alp.AlpError, match="güvensiz"):
        alp.cmd_update(_ns(source="http://example.invalid/index.json"), paths, index_path, alp.load_index(index_path))


def test_update_refuses_a_wrong_checksum_and_garbage(paths, tmp_path):
    catalog = _catalog_dir(tmp_path, "cat", {"tool": _make_archive(tmp_path, "tool", "1.0.0", V1_FILES)})
    index_path = catalog / "index.json"
    before = index_path.read_text()
    index = alp.load_index(index_path)

    good = tmp_path / "good.json"
    good.write_text(json.dumps({"schema_version": 1, "entries": {}}))
    with pytest.raises(alp.AlpError, match="Checksum"):
        alp.cmd_update(_ns(source=str(good), sha256="0" * 64), paths, index_path, index)

    junk = tmp_path / "junk.json"
    junk.write_text("<html>404</html>")
    with pytest.raises(alp.AlpError, match="JSON"):
        alp.cmd_update(_ns(source=str(junk)), paths, index_path, index)

    no_entries = tmp_path / "noent.json"
    no_entries.write_text("{}")
    with pytest.raises(alp.AlpError, match="entries"):
        alp.cmd_update(_ns(source=str(no_entries)), paths, index_path, index)

    assert index_path.read_text() == before  # every refusal left the local catalog alone
    assert not (catalog / ".alp-update").exists()


def test_update_accepts_a_matching_checksum(paths, tmp_path):
    catalog = _catalog_dir(tmp_path, "cat", {})
    index_path = catalog / "index.json"
    src = tmp_path / "new.json"
    src.write_text(json.dumps({"schema_version": 1, "entries": {}}))
    assert alp.cmd_update(_ns(source=str(src), sha256=alp.sha256_of(src)), paths, index_path,
                          alp.load_index(index_path)) == 0


def test_update_refuses_a_recipe_path_that_escapes_the_catalog(paths, tmp_path):
    catalog = _catalog_dir(tmp_path, "cat", {})
    index_path = catalog / "index.json"
    (tmp_path / "evil.recipe.json").write_text("{}")
    bad = {"schema_version": 1, "entries": {"evil": {"method": "recipe", "recipe": "../evil.recipe.json"}}}
    src = tmp_path / "bad.json"
    src.write_text(json.dumps(bad))
    with pytest.raises(alp.AlpError, match="katalog dışında|tarif dosyası"):
        alp.cmd_update(_ns(source=str(src)), paths, index_path, alp.load_index(index_path))
    assert alp.load_index(index_path)["entries"] == {}


def test_update_needs_a_source(paths, tmp_path):
    catalog = _catalog_dir(tmp_path, "cat", {})
    with pytest.raises(alp.AlpError, match="kaynağı yok"):
        alp.cmd_update(_ns(), paths, catalog / "index.json", alp.load_index(catalog / "index.json"))


def test_update_uses_the_source_field_of_the_current_index(paths, tmp_path):
    src = tmp_path / "upstream.json"
    src.write_text(json.dumps({"schema_version": 1, "entries": {}, "source": str(src)}))
    catalog = _catalog_dir(tmp_path, "cat", {})
    idx = json.loads((catalog / "index.json").read_text())
    idx["source"] = str(src)
    (catalog / "index.json").write_text(json.dumps(idx))
    alp.cmd_update(_ns(), paths, catalog / "index.json", alp.load_index(catalog / "index.json"))
    assert json.loads((catalog / "index.json").read_text())["source"] == str(src)


# --------------------------------------------------------------------------
# build cleanup
# --------------------------------------------------------------------------

def test_cleanup_build_removes_trees_unless_keep_build(paths):
    d = paths.cache_dir / "build-x"
    d.mkdir()
    (d / "f").write_text("x")
    alp._cleanup_build(paths, d)
    assert not d.exists()

    d.mkdir()
    paths.keep_build = True
    alp._cleanup_build(paths, d)
    assert d.exists()
