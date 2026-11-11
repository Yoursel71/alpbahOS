"""D123/D164: /usr/bin/apt (and apt-get, dnf, pacman, ...) is a link to pm-hint.sh: it prints the alp command and
exits 1, also under sudo, and never runs anything."""

import os
import subprocess
from pathlib import Path

import pytest

HINT = Path(__file__).resolve().parent.parent / "pm-hint.sh"
LOCALBIN = Path(__file__).resolve().parent.parent / "alp-local-bin.sh"


def run_as(tmp_path, prog, *args):
    link = tmp_path / prog
    if not link.exists():
        link.symlink_to(HINT)
    return subprocess.run([str(link), *args], capture_output=True, text=True)


@pytest.mark.parametrize("prog,args,line", [
    ("apt", ["install", "-y", "htop"], "sudo alp install htop"),
    ("apt-get", ["install", "nvidia-smi"], "sudo alp install nvidia-smi"),
    ("dnf", ["remove", "htop"], "sudo alp remove htop"),
    ("pacman", ["-S", "htop"], "sudo alp install htop"),
    ("pacman", ["-Syu"], "sudo alp update && sudo alp upgrade"),
    ("apt", ["search", "tema"], "alp search tema"),
    ("zypper", ["refresh"], "sudo alp update && sudo alp upgrade"),
    ("apt", [], "alp help"),
    ("yum", ["frobnicate"], "alp help"),
])
def test_hint_lines(tmp_path, prog, args, line):
    r = run_as(tmp_path, prog, *args)
    assert r.returncode == 1 and r.stdout == ""
    assert f"alpbahOS'ta '{prog}' yok" in r.stderr
    assert line in r.stderr.splitlines()[1:] or any(l.strip() == line for l in r.stderr.splitlines())
    assert "Sürücüler" in r.stderr


def test_every_package_gets_its_own_line(tmp_path):
    r = run_as(tmp_path, "apt", "install", "htop", "cowsay", "-y")
    lines = [l.strip() for l in r.stderr.splitlines()]
    assert "sudo alp install htop" in lines and "sudo alp install cowsay" in lines and "sudo alp install -y" not in lines


def test_hint_runs_nothing(tmp_path):
    marker = tmp_path / "ran"
    r = run_as(tmp_path, "apt", "install", f"$(touch {marker})", f";touch {marker}")
    assert r.returncode == 1 and not marker.exists()


def test_local_bin_is_appended_once_and_not_for_root(tmp_path):
    env = {"HOME": str(tmp_path), "PATH": "/usr/bin:/bin"}
    out = subprocess.run(["sh", "-c", f". {LOCALBIN}; . {LOCALBIN}; echo $PATH"], env=env, capture_output=True,
                         text=True).stdout.strip()
    if os.getuid() == 0:
        assert out == "/usr/bin:/bin"
    else:
        assert out == f"/usr/bin:/bin:{tmp_path}/.local/bin"
