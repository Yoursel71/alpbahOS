"""Seviye 3 tests: version constraints, conflicts, reverse dependencies,
autoremove, full-system upgrade, `alp check` and the confirmation prompt.

Same rules as test_alp.py: no network, real tarballs under tmp_path.
"""

from __future__ import annotations

import argparse
import io
import sys
import tarfile
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import alp  # noqa: E402


def _entry(tmp_path: Path, name: str, version: str = "1.0.0", depends=None, conflicts=None) -> dict:
    archive = tmp_path / f"{name}-{version}.tar.gz"
    content = f"{name} {version}".encode()
    with tarfile.open(archive, "w:gz") as tf:
        for d in ("usr", "usr/share", f"usr/share/{name}"):
            info = tarfile.TarInfo(d)
            info.type = tarfile.DIRTYPE
            info.mode = 0o755
            tf.addfile(info)
        info = tarfile.TarInfo(f"usr/share/{name}/data")
        info.size = len(content)
        tf.addfile(info, io.BytesIO(content))
    entry = {"method": "core", "name": name, "version": version,
             "url": archive.name, "sha256": alp.sha256_of(archive)}
    if depends:
        entry["depends"] = depends
    if conflicts:
        entry["conflicts"] = conflicts
    return entry


@pytest.fixture
def paths(tmp_path: Path) -> alp.Paths:
    p = alp.Paths.resolve(str(tmp_path / "root"))
    p.ensure()
    return p


def _ns(**kw) -> argparse.Namespace:
    base = {"dry_run": False, "reinstall": False, "yes": True, "cascade": False, "name": None}
    base.update(kw)
    return argparse.Namespace(**base)


def _install(paths, tmp_path, entries, name, **kw):
    return alp.cmd_install(_ns(name=name, **kw), paths, {"entries": entries}, tmp_path)


def _db(paths) -> dict:
    return alp.load_db(paths)["packages"]


# --------------------------------------------------------------------------
# vercmp / parse_spec
# --------------------------------------------------------------------------

@pytest.mark.parametrize("a,b,expected", [
    ("1.0", "1.0", 0),
    ("1.10", "1.9", 1),
    ("2.0", "10.0", -1),
    ("1.0.1", "1.0", 1),
    ("1.0rc1", "1.0", -1),
    ("1.0a", "1.0b", -1),
    ("1.0.1", "1.0a", 1),
    ("01.2", "1.2", 0),
    ("3.3.0", "3.3.0", 0),
    ("1.7.1", "1.7", 1),
])
def test_vercmp(a, b, expected):
    assert alp.vercmp(a, b) == expected
    assert alp.vercmp(b, a) == -expected


def test_parse_spec_plain_name():
    spec = alp.parse_spec("libfoo")
    assert spec.name == "libfoo" and spec.clauses == ()
    assert spec.allows("0.1")


def test_parse_spec_range():
    spec = alp.parse_spec("libfoo>=2.0,<3")
    assert spec.name == "libfoo"
    assert spec.allows("2.0") and spec.allows("2.9.9")
    assert not spec.allows("1.9") and not spec.allows("3.0")


def test_parse_spec_hyphenated_name_and_equals():
    spec = alp.parse_spec("alpbah-theme-solid = 1.0.0")
    assert spec.name == "alpbah-theme-solid"
    assert spec.allows("1.0.0") and not spec.allows("1.0.1")


@pytest.mark.parametrize("bad", ["", ">=1.0", "libfoo >= ", "libfoo ~> 1", "libfoo>=1,"])
def test_parse_spec_rejects_garbage(bad):
    with pytest.raises(alp.AlpError):
        alp.parse_spec(bad)


# --------------------------------------------------------------------------
# plan_transaction
# --------------------------------------------------------------------------

def test_plan_upgrades_installed_dependency_that_is_too_old(tmp_path: Path):
    index = {"entries": {
        "app": _entry(tmp_path, "app", depends=["lib>=2.0"]),
        "lib": _entry(tmp_path, "lib", "2.1"),
    }}
    installed = {"lib": {"version": "1.5", "method": "core", "reason": "dependency"}}
    steps = alp.plan_transaction(index, tmp_path, installed, ["app"])
    assert [(s.action, s.name, s.old_version, s.new_version) for s in steps] == [
        ("upgrade", "lib", "1.5", "2.1"),
        ("install", "app", None, "1.0.0"),
    ]
    assert steps[0].reason == "dependency"  # upgrade keeps the old reason


def test_plan_leaves_satisfying_dependency_alone_even_if_catalog_is_newer(tmp_path: Path):
    index = {"entries": {
        "app": _entry(tmp_path, "app", depends=["lib>=1.0"]),
        "lib": _entry(tmp_path, "lib", "2.0"),
    }}
    installed = {"lib": {"version": "1.5", "method": "core"}}
    assert [s.name for s in alp.plan_transaction(index, tmp_path, installed, ["app"])] == ["app"]


def test_plan_refuses_when_catalog_cannot_satisfy(tmp_path: Path):
    index = {"entries": {
        "app": _entry(tmp_path, "app", depends=["lib>=3"]),
        "lib": _entry(tmp_path, "lib", "2.0"),
    }}
    with pytest.raises(alp.AlpError, match=r"app şunu gerektiriyor: lib>=3.*katalogdaki lib 2.0"):
        alp.plan_transaction(index, tmp_path, {}, ["app"])


def test_plan_refuses_contradictory_constraints_in_one_transaction(tmp_path: Path):
    index = {"entries": {
        "app": _entry(tmp_path, "app", depends=["a", "b"]),
        "a": _entry(tmp_path, "a", depends=["lib>=2"]),
        "b": _entry(tmp_path, "b", depends=["lib<2"]),
        "lib": _entry(tmp_path, "lib", "2.0"),
    }}
    with pytest.raises(alp.AlpError, match="lib<2"):
        alp.plan_transaction(index, tmp_path, {}, ["app"])


def test_plan_recipe_version_is_read_from_recipe_file(tmp_path: Path):
    (tmp_path / "recipes").mkdir()
    (tmp_path / "recipes/tool.recipe.json").write_text('{"name": "tool", "version": "4.2"}', encoding="utf-8")
    index = {"entries": {
        "app": _entry(tmp_path, "app", depends=["tool>=4"]),
        "tool": {"method": "recipe", "recipe": "recipes/tool.recipe.json"},
    }}
    steps = alp.plan_transaction(index, tmp_path, {}, ["app"])
    assert (steps[0].name, steps[0].new_version) == ("tool", "4.2")


# --------------------------------------------------------------------------
# cmd_install: whole-transaction refusal, nothing written
# --------------------------------------------------------------------------

def test_install_refused_when_upgrade_would_break_installed_dependent(paths, tmp_path: Path):
    entries_v1 = {
        "old-app": _entry(tmp_path, "old-app", depends=["lib<2"]),
        "lib": _entry(tmp_path, "lib", "1.0"),
    }
    assert _install(paths, tmp_path, entries_v1, "old-app") == 0

    entries_v2 = dict(entries_v1)
    entries_v2["lib"] = _entry(tmp_path, "lib", "2.0")
    entries_v2["new-app"] = _entry(tmp_path, "new-app", depends=["lib>=2"])
    with pytest.raises(alp.AlpError, match=r"old-app lib<2 gerektiriyor, lib 2.0 olur"):
        _install(paths, tmp_path, entries_v2, "new-app")

    db = _db(paths)
    assert db["lib"]["version"] == "1.0"
    assert "new-app" not in db
    assert (paths.root / "usr/share/lib/data").read_bytes() == b"lib 1.0"


def test_install_refused_on_conflict_declared_by_new_package(paths, tmp_path: Path):
    entries = {
        "vim": _entry(tmp_path, "vim"),
        "neovim": _entry(tmp_path, "neovim", conflicts=["vim"]),
    }
    _install(paths, tmp_path, entries, "vim")
    with pytest.raises(alp.AlpError, match="neovim ile vim 1.0.0 çakışıyor"):
        _install(paths, tmp_path, entries, "neovim")
    assert "neovim" not in _db(paths)


def test_install_refused_on_conflict_declared_by_installed_package(paths, tmp_path: Path):
    entries = {
        "a": _entry(tmp_path, "a", conflicts=["b<2"]),
        "b": _entry(tmp_path, "b", "1.5"),
    }
    _install(paths, tmp_path, entries, "a")
    with pytest.raises(alp.AlpError, match="a ile b 1.5 çakışıyor"):
        _install(paths, tmp_path, entries, "b")


def test_conflict_with_non_matching_version_is_allowed(paths, tmp_path: Path):
    entries = {
        "a": _entry(tmp_path, "a", conflicts=["b<2"]),
        "b": _entry(tmp_path, "b", "2.0"),
    }
    _install(paths, tmp_path, entries, "a")
    assert _install(paths, tmp_path, entries, "b") == 0


def test_install_records_depends_conflicts_and_reason(paths, tmp_path: Path):
    entries = {
        "app": _entry(tmp_path, "app", depends=["lib>=1"], conflicts=["other"]),
        "lib": _entry(tmp_path, "lib"),
    }
    _install(paths, tmp_path, entries, "app")
    db = _db(paths)
    assert db["app"]["reason"] == "explicit"
    assert db["app"]["depends"] == ["lib>=1"]
    assert db["app"]["conflicts"] == ["other"]
    assert db["lib"]["reason"] == "dependency"


def test_explicit_install_of_existing_dependency_marks_it_explicit(paths, tmp_path: Path, capsys):
    entries = {"app": _entry(tmp_path, "app", depends=["lib"]), "lib": _entry(tmp_path, "lib")}
    _install(paths, tmp_path, entries, "app")
    capsys.readouterr()
    assert _install(paths, tmp_path, entries, "lib") == 0
    assert "açıkça kurulmuş" in capsys.readouterr().out
    assert _db(paths)["lib"]["reason"] == "explicit"


# --------------------------------------------------------------------------
# remove / autoremove
# --------------------------------------------------------------------------

def test_remove_refuses_when_other_packages_depend_on_it(paths, tmp_path: Path):
    entries = {"app": _entry(tmp_path, "app", depends=["lib"]), "lib": _entry(tmp_path, "lib")}
    _install(paths, tmp_path, entries, "app")
    with pytest.raises(alp.AlpError, match=r"lib kaldırılamaz.*app.*--cascade"):
        alp.cmd_remove(_ns(name="lib"), paths, {"entries": entries})
    assert (paths.root / "usr/share/lib/data").exists()


def test_remove_cascade_removes_dependents_first(paths, tmp_path: Path, capsys):
    entries = {
        "app": _entry(tmp_path, "app", depends=["mid"]),
        "mid": _entry(tmp_path, "mid", depends=["lib"]),
        "lib": _entry(tmp_path, "lib"),
    }
    _install(paths, tmp_path, entries, "app")
    capsys.readouterr()
    assert alp.cmd_remove(_ns(name="lib", cascade=True), paths, {"entries": entries}) == 0
    out = capsys.readouterr().out
    assert out.index("app kaldırıldı") < out.index("mid kaldırıldı") < out.index("lib kaldırıldı")
    assert _db(paths) == {}
    assert not (paths.root / "usr/share/app").exists()


def test_remove_then_autoremove_cleans_orphaned_dependencies(paths, tmp_path: Path, capsys):
    entries = {
        "app": _entry(tmp_path, "app", depends=["mid"]),
        "mid": _entry(tmp_path, "mid", depends=["lib"]),
        "lib": _entry(tmp_path, "lib"),
        "keep": _entry(tmp_path, "keep"),
    }
    index = {"entries": entries}
    _install(paths, tmp_path, entries, "app")
    _install(paths, tmp_path, entries, "keep")
    capsys.readouterr()

    alp.cmd_remove(_ns(name="app"), paths, index)
    assert "lib, mid" in capsys.readouterr().out  # orphan hint

    assert alp.cmd_autoremove(_ns(), paths, index) == 0
    out = capsys.readouterr().out
    assert out.index("mid kaldırıldı") < out.index("lib kaldırıldı")
    assert set(_db(paths)) == {"keep"}


def test_autoremove_never_touches_explicit_or_pre_seviye3_records(paths, tmp_path: Path, capsys):
    entries = {"lib": _entry(tmp_path, "lib"), "legacy": _entry(tmp_path, "legacy")}
    _install(paths, tmp_path, entries, "lib")
    db = alp.load_db(paths)
    db["packages"]["legacy"] = {"version": "1.0.0", "method": "core", "files": []}  # no reason field
    alp.save_db(paths, db)
    capsys.readouterr()
    assert alp.cmd_autoremove(_ns(), paths, {"entries": entries}) == 0
    assert "sahipsiz bağımlılık yok" in capsys.readouterr().out
    assert set(_db(paths)) == {"lib", "legacy"}


def test_reverse_dependents_fall_back_to_catalog_for_old_records(tmp_path: Path):
    index = {"entries": {"app": _entry(tmp_path, "app", depends=["lib"]), "lib": _entry(tmp_path, "lib")}}
    installed = {"app": {"version": "1.0.0", "method": "core"}, "lib": {"version": "1.0.0", "method": "core"}}
    assert alp.reverse_dependents(index, installed, "lib") == ["app"]


# --------------------------------------------------------------------------
# upgrade (all) / check / info
# --------------------------------------------------------------------------

def test_upgrade_all_upgrades_outdated_and_pulls_new_dependency(paths, tmp_path: Path):
    v1 = {"app": _entry(tmp_path, "app", "1.0"), "tool": _entry(tmp_path, "tool", "1.0")}
    _install(paths, tmp_path, v1, "app")
    _install(paths, tmp_path, v1, "tool")

    v2 = {
        "app": _entry(tmp_path, "app", "2.0", depends=["newlib>=1"]),
        "tool": _entry(tmp_path, "tool", "1.0"),
        "newlib": _entry(tmp_path, "newlib", "1.0"),
    }
    assert alp.cmd_upgrade(_ns(), paths, {"entries": v2}, tmp_path) == 0
    db = _db(paths)
    assert db["app"]["version"] == "2.0"
    assert db["newlib"]["reason"] == "dependency"
    assert db["app"]["reason"] == "explicit"
    assert (paths.root / "usr/share/app/data").read_bytes() == b"app 2.0"


def test_upgrade_all_when_nothing_outdated(paths, tmp_path: Path, capsys):
    entries = {"app": _entry(tmp_path, "app")}
    _install(paths, tmp_path, entries, "app")
    capsys.readouterr()
    assert alp.cmd_upgrade(_ns(), paths, {"entries": entries}, tmp_path) == 0
    assert "Her şey güncel" in capsys.readouterr().out


def test_upgrade_refused_when_new_version_breaks_dependent(paths, tmp_path: Path):
    v1 = {"app": _entry(tmp_path, "app", depends=["lib<2"]), "lib": _entry(tmp_path, "lib", "1.0")}
    _install(paths, tmp_path, v1, "app")
    v2 = dict(v1, lib=_entry(tmp_path, "lib", "2.0"))
    with pytest.raises(alp.AlpError, match="app lib<2 gerektiriyor, lib 2.0 olur"):
        alp.cmd_upgrade(_ns(name="lib"), paths, {"entries": v2}, tmp_path)
    assert _db(paths)["lib"]["version"] == "1.0"


def test_check_reports_ok_and_broken_state(paths, tmp_path: Path, capsys):
    entries = {"app": _entry(tmp_path, "app", depends=["lib>=1"]), "lib": _entry(tmp_path, "lib")}
    index = {"entries": entries}
    _install(paths, tmp_path, entries, "app")
    capsys.readouterr()
    assert alp.cmd_check(paths, index, tmp_path) == 0
    assert "sorun yok" in capsys.readouterr().out

    db = alp.load_db(paths)
    del db["packages"]["lib"]
    alp.save_db(paths, db)
    assert alp.cmd_check(paths, index, tmp_path) == 1
    assert "SORUN: app lib>=1 gerektiriyor, lib kurulu değil" in capsys.readouterr().out


def test_info_shows_required_by(paths, tmp_path: Path, capsys):
    entries = {"app": _entry(tmp_path, "app", depends=["lib"]), "lib": _entry(tmp_path, "lib")}
    _install(paths, tmp_path, entries, "app")
    capsys.readouterr()
    alp.cmd_info({"entries": entries}, alp.load_db(paths), "lib")
    assert '"required_by": [\n    "app"\n  ]' in capsys.readouterr().out


# --------------------------------------------------------------------------
# confirmation prompt
# --------------------------------------------------------------------------

class _Tty(io.StringIO):
    def isatty(self) -> bool:
        return True


def test_declining_prompt_changes_nothing(paths, tmp_path: Path, monkeypatch, capsys):
    entries = {"app": _entry(tmp_path, "app", depends=["lib"]), "lib": _entry(tmp_path, "lib")}
    monkeypatch.setattr(sys, "stdin", _Tty())
    monkeypatch.setattr("builtins.input", lambda prompt="": "h")
    assert _install(paths, tmp_path, entries, "app", yes=False) == 1
    assert "İptal edildi" in capsys.readouterr().out
    assert _db(paths) == {}
    assert not (paths.root / "usr/share/lib").exists()


def test_empty_answer_means_yes(paths, tmp_path: Path, monkeypatch):
    entries = {"app": _entry(tmp_path, "app")}
    monkeypatch.setattr(sys, "stdin", _Tty())
    monkeypatch.setattr("builtins.input", lambda prompt="": "")
    assert _install(paths, tmp_path, entries, "app", yes=False) == 0
    assert "app" in _db(paths)


def test_cli_end_to_end_via_main(paths, tmp_path: Path, capsys):
    import json
    entries = {"app": _entry(tmp_path, "app", depends=["lib>=1"]), "lib": _entry(tmp_path, "lib")}
    index_path = tmp_path / "index.json"
    index_path.write_text(json.dumps({"schema_version": 1, "entries": entries}), encoding="utf-8")
    base = ["--root", str(paths.root), "--index", str(index_path)]
    assert alp.main(base + ["install", "-y", "app"]) == 0
    assert alp.main(base + ["remove", "lib"]) == 1
    assert "kaldırılamaz" in capsys.readouterr().err
    assert alp.main(base + ["remove", "-y", "app"]) == 0
    assert alp.main(base + ["autoremove", "-y"]) == 0
    assert alp.main(base + ["check"]) == 0
    assert _db(paths) == {}


def test_upgrade_all_keeps_back_blocked_package_and_upgrades_the_rest(paths, tmp_path: Path, capsys):
    v1 = {
        "old-app": _entry(tmp_path, "old-app", depends=["lib<2"]),
        "lib": _entry(tmp_path, "lib", "1.0"),
        "tool": _entry(tmp_path, "tool", "1.0"),
    }
    _install(paths, tmp_path, v1, "old-app")
    _install(paths, tmp_path, v1, "tool")
    capsys.readouterr()

    v2 = dict(v1, lib=_entry(tmp_path, "lib", "2.0"), tool=_entry(tmp_path, "tool", "2.0"))
    assert alp.cmd_upgrade(_ns(), paths, {"entries": v2}, tmp_path) == 0
    out = capsys.readouterr().out
    assert "geri tutuldu: lib (old-app lib<2 gerektiriyor, lib 2.0 olur)" in out
    db = _db(paths)
    assert db["lib"]["version"] == "1.0"
    assert db["tool"]["version"] == "2.0"


def test_upgrade_all_only_kept_back_says_so(paths, tmp_path: Path, capsys):
    v1 = {"old-app": _entry(tmp_path, "old-app", depends=["lib<2"]), "lib": _entry(tmp_path, "lib", "1.0")}
    _install(paths, tmp_path, v1, "old-app")
    capsys.readouterr()
    v2 = dict(v1, lib=_entry(tmp_path, "lib", "2.0"))
    assert alp.cmd_upgrade(_ns(), paths, {"entries": v2}, tmp_path) == 0
    out = capsys.readouterr().out
    assert "geri tutuldu: lib" in out
    assert "Yükseltilebilecek başka paket yok." in out
