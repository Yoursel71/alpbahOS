"""LIVE-PROFILE-01: system-wide KDE defaults shipped by the desktop profile (round 25)."""
import configparser
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
XDG = REPO / "profiles" / "desktop" / "xdg"


def ini(path):
    cp = configparser.ConfigParser(interpolation=None, strict=False)
    cp.optionxform = str
    cp.read(path, encoding="utf-8")
    return cp


def test_kdeglobals_is_generated_from_the_scheme():
    r = subprocess.run([sys.executable, "-B", str(REPO / "profiles/desktop/tools/build_xdg_kdeglobals.py"), "--check"])
    assert r.returncode == 0


def test_kdeglobals_carries_the_dark_colours():
    k = ini(XDG / "kdeglobals")
    s = ini(REPO / "profiles/desktop/colorscheme/alpbah-dark.colors")
    assert k["KDE"]["LookAndFeelPackage"] == "org.alpbahos.solid.desktop"
    assert k["General"]["ColorScheme"] == "alpbah-dark"
    for sec in ("Colors:Window", "Colors:View", "Colors:Button", "Colors:Selection", "WM"):
        assert dict(k[sec]) == dict(s[sec])


def test_dark_plasma_style_and_no_kde_welcome_center():
    assert ini(XDG / "plasmarc")["Theme"]["name"] == "breeze-dark"
    defaults = (REPO / "profiles/desktop/lookandfeel/org.alpbahos.solid.desktop/contents/defaults").read_text()
    assert "[plasmarc][Theme]\nname=breeze-dark\n" in defaults
    assert ini(XDG / "plasma-welcomerc")["General"]["LastSeenVersion"].startswith("6.")
