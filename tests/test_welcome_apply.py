"""WELCOME-01 (D121): apply logic of the alpbahOS Welcome app with the real commands replaced by fakes on PATH.

The fakes log their arguments; kwriteconfig6/kreadconfig6 keep values in a small text store, so a later "durum"
reads back what "uygula" wrote.
"""
import json
import os
import stat
import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[1]
TOOL = REPO / "profiles" / "welcome" / "bin" / "alpbah-hosgeldin-uygula"

FAKES = {
    "kwriteconfig6": """#!/bin/sh
echo "kwriteconfig6 $*" >> "$FAKE_LOG"
printf '%s|%s|%s=%s\\n' "$2" "$4" "$6" "$7" >> "$FAKE_STORE"
""",
    "kreadconfig6": """#!/bin/sh
v=$(grep -F "$2|$4|$6=" "$FAKE_STORE" 2>/dev/null | tail -n 1 | cut -d= -f2-)
[ -n "$v" ] && echo "$v" || echo "$8"
""",
    "plasma-apply-wallpaperimage": """#!/bin/sh
echo "plasma-apply-wallpaperimage $*" >> "$FAKE_LOG"
""",
    "busctl": """#!/bin/sh
echo "busctl $1 $2 $3 $4 $5 $6 $7" >> "$FAKE_LOG"
printf '%s' "$8" > "$FAKE_SCRIPT"
""",
    "alpbah-gorunum": """#!/bin/sh
echo "alpbah-gorunum $*" >> "$FAKE_LOG"
if [ "$1" = durum ]; then
  echo "profil: solid"; echo "${FAKE_GLASS_LINE:-glass: uygun}"; exit 0
fi
if [ "$1" = glass ] && [ -n "$FAKE_GLASS_REFUSE" ]; then echo "Glass uygulanmadı: yazılım" >&2; exit 3; fi
exit 0
""",
}


@pytest.fixture
def env(tmp_path):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    for name, body in FAKES.items():
        p = bin_dir / name
        p.write_text(body)
        p.chmod(p.stat().st_mode | stat.S_IXUSR)
    cmdline = tmp_path / "cmdline"
    cmdline.write_text("BOOT_IMAGE=/boot/vmlinuz root=PARTUUID=x ro quiet splash\n")
    e = dict(os.environ)
    e.update(PATH=f"{bin_dir}:/usr/bin:/bin", XDG_CONFIG_HOME=str(tmp_path / "config"),
             FAKE_LOG=str(tmp_path / "log"), FAKE_STORE=str(tmp_path / "store"),
             FAKE_SCRIPT=str(tmp_path / "script.js"), ALPBAH_CMDLINE=str(cmdline))
    e.pop("FAKE_GLASS_REFUSE", None)
    return tmp_path, e


def run(env, *args):
    return subprocess.run([sys.executable, str(TOOL), *args], env=env, capture_output=True, text=True, timeout=30)


def log(tmp):
    p = tmp / "log"
    return p.read_text().splitlines() if p.exists() else []


def test_first_run_then_marker(env):
    tmp, e = env
    assert run(e, "ilk-acilis-mi").returncode == 0
    assert run(e, "gec").returncode == 0
    assert (tmp / "config" / "alpbah-hosgeldin.tamam").exists()
    assert run(e, "ilk-acilis-mi").returncode == 1
    assert log(tmp) == []  # "gec" changes nothing in the session


def test_live_session_never_first_run(env):
    tmp, e = env
    (tmp / "cmdline").write_text("root=live:CDLABEL=ALPBAHOS_BETA rd.live.image quiet\n")
    assert run(e, "ilk-acilis-mi").returncode == 1


@pytest.mark.parametrize("tema,path", [("alpbahos", "/usr/share/wallpapers/alpbahOS-Brand"),
                                       ("ataturk", "/usr/share/wallpapers/alpbahOS-Ataturk")])
def test_theme_sets_wallpaper(env, tema, path):
    tmp, e = env
    r = run(e, "uygula", "--tema", tema, "--gorunum", "solid", "--cubuk", "sol")
    assert r.returncode == 0, r.stderr
    assert f"plasma-apply-wallpaperimage {path}" in log(tmp)
    assert "SCREENLOCK-01" in r.stdout  # the lock screen part is not claimed
    assert (tmp / "config" / "alpbah-hosgeldin.tamam").exists()


@pytest.mark.parametrize("gorunum", ["solid", "glass"])
def test_look_calls_alpbah_gorunum(env, gorunum):
    tmp, e = env
    assert run(e, "uygula", "--tema", "alpbahos", "--gorunum", gorunum, "--cubuk", "sol").returncode == 0
    assert f"alpbah-gorunum {gorunum}" in log(tmp)


def test_glass_refused_fails_and_keeps_first_run(env):
    tmp, e = env
    e["FAKE_GLASS_REFUSE"] = "1"
    r = run(e, "uygula", "--tema", "alpbahos", "--gorunum", "glass", "--cubuk", "sol")
    assert r.returncode == 2
    assert "Görünüm uygulanmadı" in r.stderr
    assert not (tmp / "config" / "alpbah-hosgeldin.tamam").exists()


@pytest.mark.parametrize("cubuk,center,spacers", [("sol", "false", 0), ("orta", "true", 2)])
def test_bar_script(env, cubuk, center, spacers):
    tmp, e = env
    assert run(e, "uygula", "--tema", "alpbahos", "--gorunum", "solid", "--cubuk", cubuk).returncode == 0
    assert any(line.startswith("busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell "
                               "evaluateScript s") for line in log(tmp))
    script = (tmp / "script.js").read_text()
    assert f"var center = {center};" in script
    # the panel stays: no new Panel, widgets are only re-added to the existing bottom panel
    assert "new Panel" not in script and 'x.location == "bottom"' in script
    assert script.count("function spacer()") == 1 and script.count("spacer();") == 2  # called only when center
    assert 't.writeConfig("fill", !center);' in script


def test_durum_reads_back_choices_and_glass(env):
    tmp, e = env
    run(e, "uygula", "--tema", "ataturk", "--gorunum", "solid", "--cubuk", "orta")
    e["FAKE_GLASS_LINE"] = "glass: önerilmez -- yazılım rasterleştirici (llvmpipe)"
    r = run(e, "durum")
    assert r.returncode == 0, r.stderr
    d = json.loads(r.stdout)
    assert d["tema"] == "ataturk" and d["cubuk"] == "orta" and d["gorunum"] == "solid"
    assert d["glass_kullanilabilir"] is False
    assert d["glass_neden"] == "yazılım rasterleştirici (llvmpipe)"
    assert d["onizleme"]["alpbahos"].endswith("alpbahOS-Brand/contents/screenshot.png")


def test_durum_glass_ok(env):
    _tmp, e = env
    d = json.loads(run(e, "durum").stdout)
    assert d["glass_kullanilabilir"] is True and d["glass_neden"] == ""
    assert d["tema"] == "alpbahos" and d["gorunum"] == "solid" and d["cubuk"] == "sol"
