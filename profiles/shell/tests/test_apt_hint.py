"""D123: foreign package-manager commands print an alp hint and never run.

Runs the real zshrc.alpbah in a non-interactive zsh with a minimal PATH that
contains zsh, mv (needed by compinit) and a marker-writing fake `alp`. No
`apt` exists on that PATH, so only command_not_found_handler can answer.
If the handler ever executed `alp`, the marker file would appear.
"""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

import pytest

ZSH = shutil.which("zsh")
pytestmark = pytest.mark.skipif(ZSH is None, reason="zsh is not installed")

PROFILE = Path(__file__).resolve().parents[1] / "zshrc.alpbah"


@pytest.fixture
def sandbox(tmp_path):
    bindir = tmp_path / "bin"
    bindir.mkdir()
    home = tmp_path / "home"
    home.mkdir()
    marker = tmp_path / "ALP_RAN"
    os.symlink(ZSH, bindir / "zsh")
    mv = shutil.which("mv")
    os.symlink(mv, bindir / "mv")
    fake_alp = bindir / "alp"
    fake_alp.write_text(f"#!/bin/sh\ntouch '{marker}'\n", encoding="utf-8")
    fake_alp.chmod(0o755)
    return {"bin": bindir, "home": home, "marker": marker}


def run_zsh(sandbox, command: str):
    env = {"HOME": str(sandbox["home"]), "PATH": str(sandbox["bin"]), "LANG": "C.UTF-8"}
    script = f"source '{PROFILE}'; {command}"
    return subprocess.run(
        [str(sandbox["bin"] / "zsh"), "-f", "-c", script],
        env=env, capture_output=True, text=True, timeout=60,
    )


@pytest.mark.parametrize(
    "command, hint",
    [
        ("apt install firefox", "alp install firefox"),
        ("apt-get install -y firefox", "alp install -y firefox"),
        ("dnf remove htop", "alp remove htop"),
        ("yum purge htop", "alp remove htop"),
        ("zypper uninstall htop", "alp remove htop"),
        ("apt update", "alp update"),
        ("dnf upgrade", "alp update"),
        ("zypper refresh", "alp update"),
        ("apt search figlet", "alp search figlet"),
        ("snap info core", "alp info core"),
        ("apt show figlet", "alp info figlet"),
        ("apt frobnicate", "alp help"),
        ("apt", "alp help"),
    ],
)
def test_foreign_package_manager_prints_turkish_hint(sandbox, command, hint):
    result = run_zsh(sandbox, command)
    assert result.returncode == 127
    assert result.stdout == ""
    expected_cmd = command.split()[0]
    assert result.stderr.strip().splitlines()[-1] == (
        f"alpbahOS'ta '{expected_cmd}' yok. Bunun yerine: {hint}"
    )
    assert not sandbox["marker"].exists(), "hint must never execute anything"


def test_unknown_command_keeps_zsh_behaviour_in_turkish(sandbox):
    result = run_zsh(sandbox, "frobnicate-xyz --now")
    assert result.returncode == 127
    assert result.stderr.strip().splitlines()[-1] == "zsh: komut bulunamadı: frobnicate-xyz"
    assert not sandbox["marker"].exists()


def test_profile_still_sources_cleanly(sandbox):
    result = run_zsh(sandbox, "true")
    assert result.returncode == 0
    assert not sandbox["marker"].exists()
