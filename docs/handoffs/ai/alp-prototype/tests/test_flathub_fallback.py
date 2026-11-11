"""D163 (ALP-FLATHUB-01): `alp install <name>` offers the Flathub app when the alp catalogue has no such package.

flatpak itself is never run here: `flatpak search` output and `install_flatpak`/`remove_flatpak` are replaced.
"""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

import pytest

import alp

SEARCH_OUT = (
    "org.mozilla.firefox\tFirefox\tflathub\n"
    "io.gitlab.librewolf-community\tLibreWolf\tflathub\n"
    "org.example.Firefoxy\tFirefoxy Tool\tother-remote\n"
)


@pytest.fixture
def paths(tmp_path: Path) -> alp.Paths:
    p = alp.Paths.resolve(str(tmp_path / "root"))
    p.ensure()
    return p


@pytest.fixture
def fake_flatpak(monkeypatch):
    calls = {"install": [], "remove": [], "search_out": SEARCH_OUT}

    def run(cmd, **kw):
        assert cmd[:2] == ["flatpak", "search"], cmd
        return subprocess.CompletedProcess(cmd, 0, stdout=calls["search_out"], stderr="")

    def install(entry, dry_run):
        calls["install"].append((entry["flatpak_ref"], dry_run))
        return {"name": entry["flatpak_ref"], "version": "1.0", "method": "flatpak", "status": "installed",
                "installed_at": "t", "installed_by": "alp/test", "source": {"remote": "flathub"}, "files": [],
                "flatpak_ref": entry["flatpak_ref"]}

    monkeypatch.setattr(alp.shutil, "which", lambda name: "/usr/bin/flatpak" if name == "flatpak" else None)
    monkeypatch.setattr(alp.subprocess, "run", run)
    monkeypatch.setattr(alp, "install_flatpak", install)
    monkeypatch.setattr(alp, "remove_flatpak", lambda ref, dry_run: calls["remove"].append((ref, dry_run)))
    return calls


def _args(name, yes=True, dry_run=False):
    return argparse.Namespace(name=name, yes=yes, dry_run=dry_run, json=False, reinstall=False, cascade=False)


def test_candidates_only_flathub_and_exact_first(fake_flatpak):
    cands = alp.flathub_candidates("firefox")
    assert cands[0] == ("org.mozilla.firefox", "Firefox")
    assert ("org.example.Firefoxy", "Firefoxy Tool") not in cands  # other remote


def test_candidates_empty_without_flatpak(monkeypatch):
    monkeypatch.setattr(alp.shutil, "which", lambda name: None)
    assert alp.flathub_candidates("firefox") == []


def test_install_unknown_name_installs_exact_flathub_app(paths, fake_flatpak, capsys):
    assert alp._install_from_flathub(_args("firefox"), paths) == 0
    assert fake_flatpak["install"] == [("org.mozilla.firefox", False)]
    db = alp.load_db(paths)
    rec = db["packages"]["org.mozilla.firefox"]
    assert rec["method"] == "flatpak" and rec["reason"] == "explicit"
    assert "Flathub" in capsys.readouterr().out


def test_install_by_application_id(paths, fake_flatpak):
    assert alp._install_from_flathub(_args("io.gitlab.librewolf-community"), paths) == 0
    assert fake_flatpak["install"] == [("io.gitlab.librewolf-community", False)]


def test_ambiguous_with_yes_is_refused(paths, fake_flatpak):
    fake_flatpak["search_out"] = "org.a.Office\tOffice One\tflathub\norg.b.Office\tOffice Two\tflathub\n"
    with pytest.raises(alp.AlpError, match="uygulama kimliğini"):
        alp._install_from_flathub(_args("ofis"), paths)
    assert fake_flatpak["install"] == []


def test_no_candidate_is_an_error(paths, fake_flatpak):
    fake_flatpak["search_out"] = "No matches found\n"
    with pytest.raises(alp.AlpError, match="Flathub'da da bulunamadı"):
        alp._install_from_flathub(_args("yokboyle"), paths)


def test_dry_run_records_nothing(paths, fake_flatpak):
    assert alp._install_from_flathub(_args("firefox", dry_run=True), paths) == 0
    assert fake_flatpak["install"] == [("org.mozilla.firefox", True)]
    assert "org.mozilla.firefox" not in alp.load_db(paths)["packages"]


def test_already_installed_is_not_installed_again(paths, fake_flatpak):
    alp._install_from_flathub(_args("firefox"), paths)
    fake_flatpak["install"].clear()
    assert alp._install_from_flathub(_args("firefox"), paths) == 0
    assert fake_flatpak["install"] == []


def test_installed_flathub_app_is_removed_by_alp_remove_and_check_is_clean(paths, fake_flatpak):
    alp._install_from_flathub(_args("firefox"), paths)
    db = alp.load_db(paths)
    assert alp.state_problems({"entries": {}}, db["packages"], [], only_touched=False) == []
    assert alp.cmd_remove(_args("org.mozilla.firefox"), paths) == 0
    assert fake_flatpak["remove"] == [("org.mozilla.firefox", False)]
    assert "org.mozilla.firefox" not in alp.load_db(paths)["packages"]
