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
        assert {key: k[sec][key] for key in s[sec]} == dict(s[sec])  # WM also gets activeFont (E1)


def test_dark_plasma_style_and_no_kde_welcome_center():
    assert ini(XDG / "plasmarc")["Theme"]["name"] == "default"
    defaults = (REPO / "profiles/desktop/lookandfeel/org.alpbahos.solid.desktop/contents/defaults").read_text()
    assert "[plasmarc][Theme]\nname=default\n" in defaults
    assert "[ksplashrc][KSplash]\nEngine=KSplashQML\nTheme=org.alpbahos.solid.desktop\n" in defaults
    assert ini(XDG / "plasma-welcomerc")["General"]["LastSeenVersion"].startswith("6.")


def test_fonts_inter_and_jetbrains_mono():
    k = ini(XDG / "kdeglobals")
    assert k["General"]["font"].startswith("Inter Variable,10,")
    assert k["General"]["fixed"].startswith("JetBrains Mono,10,")
    fc = (REPO / "profiles/desktop/fontconfig/60-alpbahos-fonts.conf").read_text()
    assert "<family>Inter Variable</family>" in fc and "<family>JetBrains Mono</family>" in fc
