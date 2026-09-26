"""Türkçe yardım ekranı ve CLI hata mesajları."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import alp  # noqa: E402


@pytest.mark.parametrize("argv", [[], ["help"], ["--help"], ["-h"]])
def test_bare_alp_and_help_show_turkish_screen(argv, capsys):
    assert alp.main(argv) == 0
    out = capsys.readouterr().out
    assert "Kullanım: alp <komut>" in out
    for command in ("search", "install", "remove", "upgrade", "update", "recover"):
        assert command in out
    assert "\033[" not in out  # renk yalnız terminalde


def test_help_developer_topic(capsys):
    assert alp.main(["help", "gelistirici"]) == 0
    assert "--relocate" in capsys.readouterr().out


def test_command_help_is_turkish(capsys):
    with pytest.raises(SystemExit) as exc:
        alp.main(["install", "--help"])
    assert exc.value.code == 0
    out = capsys.readouterr().out
    assert out.startswith("Kullanım: alp install <paket> [seçenekler]")
    assert "Seçenekler:" in out and "usage:" not in out


def test_mistyped_command_suggests_closest(capsys):
    with pytest.raises(SystemExit) as exc:
        alp.main(["instal", "figlet"])
    assert exc.value.code == 2
    assert "Bunu mu demek istediniz: alp install" in capsys.readouterr().err


def test_missing_argument_is_short_and_turkish(capsys):
    with pytest.raises(SystemExit):
        alp.main(["install"])
    err = capsys.readouterr().err
    assert "eksik: paket" in err and "alp install --help" in err


def test_global_options_work_before_and_after_command():
    parser = alp.build_parser()
    before = parser.parse_args(["--dry-run", "--root", "/r", "install", "x"])
    after = parser.parse_args(["install", "x", "--dry-run", "--root", "/r"])
    for args in (before, after):
        assert args.dry_run is True and args.root == "/r" and args.name == "x"
    plain = parser.parse_args(["install", "x"])
    assert plain.dry_run is False and plain.root is None and plain.index is None


def test_search_matches_description(capsys):
    index = {"entries": {
        "nano": {"method": "recipe", "description": "Kolay terminal metin düzenleyici"},
        "vlc": {"method": "flatpak", "description": "Video oynatıcı"},
    }}
    assert alp.cmd_search(index, "DÜZENLEYİCİ") == 0
    out = capsys.readouterr().out
    assert "nano" in out and "Kolay terminal metin düzenleyici" in out and "vlc" not in out
    assert alp.cmd_search(index, "video", as_json=True) == 0
    assert '"description": "Video oynatıcı"' in capsys.readouterr().out


def test_flatpak_version_read_from_flatpak_list():
    from unittest import mock
    listing = "org.other.App\t1.0\ncom.github.tchx84.Flatseal\t2.4.1\n"
    done = mock.Mock(stdout=listing)
    with mock.patch.object(alp.subprocess, "run", return_value=done):
        assert alp._flatpak_installed_version("com.github.tchx84.Flatseal") == "2.4.1"
        assert alp._flatpak_installed_version("org.missing.App") is None
    with mock.patch.object(alp.subprocess, "run", side_effect=FileNotFoundError):
        assert alp._flatpak_installed_version("x") is None


def test_plan_hides_unknown_flatpak_version(capsys):
    step = alp.PlanStep(name="vlc", action="install", old_version=None, new_version="unknown", reason="explicit")
    alp._print_plan([step], {"entries": {"vlc": {"method": "flatpak"}}})
    out = capsys.readouterr().out
    assert "vlc [flatpak]" in out and "unknown" not in out
