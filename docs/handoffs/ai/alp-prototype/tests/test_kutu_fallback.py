"""D164 (ALP-KUTU-01): a name that neither the alp catalogue nor Flathub (exact match) has goes to the Debian box.

Nothing real runs: distrobox, podman, flatpak and runuser are answered by FakeBox; HOME is a temp directory.
"""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

import pytest

import alp

ENTER = ["distrobox", "enter", alp.KUTU_NAME, "--"]


class FakeBox:
    def __init__(self):
        self.calls: list[list[str]] = []
        self.exists = False
        self.flathub = ""
        self.policy = {"htop": "3.4.1-5", "cowsay": "3.03+dfsg2-8"}
        self.files = {
            "htop": ["/.", "/usr", "/usr/bin", "/usr/bin/htop", "/usr/share/applications",
                     "/usr/share/applications/htop.desktop", "/usr/share/doc/htop/copyright"],
            "cowsay": ["/usr/games", "/usr/games/cowsay", "/usr/games/cowthink", "/usr/share/cowsay/cows/default.cow"],
        }
        self.installed: set[str] = set()
        self.runuser = None

    def run(self, cmd, **kw):
        cmd = list(cmd)
        self.calls.append(cmd)

        def cp(rc=0, out=""):
            if kw.get("check") and rc:
                raise subprocess.CalledProcessError(rc, cmd)
            return subprocess.CompletedProcess(cmd, rc, stdout=out, stderr="")

        if cmd[:3] == ["podman", "container", "exists"]:
            return cp(0 if self.exists else 1) if not kw.get("check") else cp()
        if cmd[:2] == ["distrobox", "create"]:
            self.exists = True
            return cp()
        if cmd[:2] == ["flatpak", "search"]:
            return cp(0, self.flathub)
        if cmd[0] == "runuser":
            self.runuser = cmd
            return cp()
        assert cmd[:4] == ENTER, cmd
        inner = cmd[4:]
        if inner == ["true"] or inner[:2] == ["distrobox-export", "--bin"] or inner[:2] == ["distrobox-export", "--app"]:
            return cp()
        if "apt-cache" in inner:
            v = self.policy.get(inner[-1])
            return cp(0, f"{inner[-1]}:\n  Installed: (none)\n  Candidate: {v}\n" if v else "")
        if inner[-2:] == ["update", "-qq"]:
            return cp()
        if "install" in inner:
            self.installed.add(inner[-1])
            return cp()
        if "remove" in inner:
            self.installed.discard(inner[-1])
            return cp()
        if inner[:2] == ["dpkg", "-L"]:
            return cp(0, "\n".join(self.files[inner[2]]) + "\n")
        raise AssertionError(cmd)

    def inner_calls(self):
        return [c[4:] for c in self.calls if c[:4] == ENTER]


@pytest.fixture
def box(monkeypatch, tmp_path):
    fb = FakeBox()
    monkeypatch.setenv("HOME", str(tmp_path / "home"))
    monkeypatch.setattr(alp, "kutu_available", lambda: True)
    monkeypatch.setattr(alp, "_is_root", lambda: False)
    monkeypatch.setattr(alp, "_host_has_command", lambda name: name in ("ls", "cowthink"))
    monkeypatch.setattr(alp.shutil, "which", lambda name, **kw: "/usr/bin/flatpak" if name == "flatpak" else None)
    monkeypatch.setattr(alp.subprocess, "run", fb.run)
    return fb


@pytest.fixture
def paths(tmp_path: Path) -> alp.Paths:
    p = alp.Paths.resolve(str(tmp_path / "root"))
    p.ensure()
    return p


def _args(name, yes=True, dry_run=False, **kw):
    return argparse.Namespace(name=name, yes=yes, dry_run=dry_run, json=False, reinstall=False, cascade=False, **kw)


def _state(tmp_path):
    return alp.load_kutu(tmp_path / "home")["packages"]


def test_install_creates_box_installs_exports_and_records(box, tmp_path, capsys):
    assert alp._install_from_kutu(_args("htop")) == 0
    inner = box.inner_calls()
    assert ["true"] in inner  # the first entry set the box up
    assert ["sudo", "env", "DEBIAN_FRONTEND=noninteractive", "apt-get", "install", "-y", "htop"] in inner
    assert ["distrobox-export", "--bin", "/usr/bin/htop", "--export-path", str(tmp_path / "home/.local/bin")] in inner
    assert ["distrobox-export", "--app", "htop"] in inner
    rec = _state(tmp_path)["htop"]
    assert rec["version"] == "3.4.1-5" and rec["bins"] == ["/usr/bin/htop"] and rec["apps"] == ["htop"]
    out = capsys.readouterr().out
    assert "Kuruldu: htop 3.4.1-5" in out and "alp remove htop" in out


def test_existing_box_is_not_created_again(box, tmp_path):
    box.exists = True
    alp._install_from_kutu(_args("htop"))
    assert not any(c[:2] == ["distrobox", "create"] for c in box.calls)


def test_host_command_of_the_same_name_is_not_exported(box, tmp_path, capsys):
    alp._install_from_kutu(_args("cowsay"))
    rec = _state(tmp_path)["cowsay"]
    assert rec["bins"] == ["/usr/games/cowsay"]  # cowthink is on the host (fake), so it stays in the box
    assert "cowthink" in capsys.readouterr().out


def test_not_in_debian_returns_not_found_and_records_nothing(box, tmp_path):
    box.exists = True
    assert alp._install_from_kutu(_args("yokboylepaket")) == alp.KUTU_NOT_FOUND
    assert _state(tmp_path) == {}
    assert not any("install" in c for c in box.inner_calls())


@pytest.mark.parametrize("name", ["nvidia-smi", "nvidia-driver", "linux-image-amd64", "linux-headers-amd64",
                                  "firmware-misc-nonfree", "broadcom-sta-dkms", "dkms", "grub-efi-amd64"])
def test_driver_and_kernel_packages_are_refused(box, name):
    with pytest.raises(alp.AlpError, match="sürücü/çekirdek"):
        alp._install_from_kutu(_args(name))
    assert box.calls == []


def test_dry_run_creates_nothing(box, tmp_path, capsys):
    assert alp._install_from_kutu(_args("htop", dry_run=True)) == 0
    assert not any(c[:2] == ["distrobox", "create"] for c in box.calls)
    assert not any("install" in c or "update" in c for c in box.inner_calls())
    assert _state(tmp_path) == {}
    assert "[dry-run]" in capsys.readouterr().out


def test_root_without_a_sudo_user_is_refused(box, monkeypatch):
    monkeypatch.setattr(alp, "_is_root", lambda: True)
    monkeypatch.delenv("SUDO_USER", raising=False)
    with pytest.raises(alp.AlpError, match="root oturumundan"):
        alp._install_from_kutu(_args("htop"))
    assert box.calls == []


def test_sudo_runs_the_box_step_as_the_user(box, monkeypatch):
    import pwd as pwdmod
    monkeypatch.setattr(alp, "_is_root", lambda: True)
    monkeypatch.setenv("SUDO_USER", "testuser")
    monkeypatch.setattr(alp.pwd, "getpwnam",
                        lambda u: pwdmod.struct_passwd(("testuser", "x", 1000, 1000, "", "/home/testuser", "/bin/bash")))
    monkeypatch.setattr(alp.os.path, "isdir", lambda p: p == "/run/user/1000")
    assert alp._install_from_kutu(_args("htop", yes=True)) == 0
    cmd = box.runuser
    assert cmd[:5] == ["runuser", "-u", "testuser", "--", "env"]
    assert "XDG_RUNTIME_DIR=/run/user/1000" in cmd and "HOME=/home/testuser" in cmd
    assert cmd[-4:] == ["install", "htop", "--kutu", "--yes"]
    assert box.inner_calls() == []  # nothing ran as root


def test_unknown_name_prefers_an_exact_flathub_match(box, paths):
    box.flathub = "org.gnome.Htop\thtop\tflathub\n"
    installed = []
    alp_install = alp.install_flatpak
    try:
        alp.install_flatpak = lambda entry, dry_run: installed.append(entry["flatpak_ref"]) or {
            "name": entry["flatpak_ref"], "version": "1", "method": "flatpak", "status": "installed", "files": []}
        assert alp.cmd_install(_args("htop"), paths, {"entries": {}}, paths.root) == 0
    finally:
        alp.install_flatpak = alp_install
    assert installed == ["org.gnome.Htop"]
    assert box.inner_calls() == []


def test_unknown_name_without_flathub_goes_to_the_box(box, paths, tmp_path):
    assert alp.cmd_install(_args("htop"), paths, {"entries": {}}, paths.root) == 0
    assert "htop" in _state(tmp_path)


def test_fuzzy_flathub_matches_come_after_the_box(box, paths):
    box.exists = True
    box.flathub = "org.example.YokStudio\tYokboyle Studio\tflathub\norg.example.YokTwo\tYokboyle Two\tflathub\n"
    with pytest.raises(alp.AlpError, match="uygulama kimliğini"):
        alp.cmd_install(_args("yokboyle"), paths, {"entries": {}}, paths.root)
    assert any("apt-cache" in c for c in box.inner_calls())  # Debian was asked first


def test_nothing_anywhere_is_an_error(box, paths):
    box.exists = True
    with pytest.raises(alp.AlpError, match="Debian'da bulunamadı"):
        alp.cmd_install(_args("yokboyle"), paths, {"entries": {}}, paths.root)


def test_packagekit_never_reaches_the_box(box, paths):
    # alp_packagekit_backend.py passes --no-flathub: no Flathub search, no container
    with pytest.raises(alp.AlpError, match="Bilinmeyen paket"):
        alp.cmd_install(_args("htop", no_flathub=True), paths, {"entries": {}}, paths.root)
    assert box.calls == []


def test_flathub_style_id_skips_the_box_in_fallback(box, paths):
    with pytest.raises(alp.AlpError, match="Bilinmeyen paket"):
        alp.cmd_install(_args("org.Example.App"), paths, {"entries": {}}, paths.root)
    assert box.inner_calls() == []


def test_remove_unexports_and_removes_from_the_box(box, paths, tmp_path, capsys):
    alp._install_from_kutu(_args("htop"))
    box.calls.clear()
    assert alp.cmd_remove(_args("htop"), paths) == 0
    inner = box.inner_calls()
    assert ["distrobox-export", "--app", "htop", "--delete"] in inner
    assert ["distrobox-export", "--bin", "/usr/bin/htop", "--export-path", str(tmp_path / "home/.local/bin"),
            "--delete"] in inner
    assert ["sudo", "env", "DEBIAN_FRONTEND=noninteractive", "apt-get", "remove", "-y", "htop"] in inner
    assert _state(tmp_path) == {}
    assert "Kaldırıldı: htop" in capsys.readouterr().out


def test_remove_of_an_unknown_name_keeps_the_old_error(box, paths):
    with pytest.raises(alp.AlpError, match="Kurulu değil"):
        alp.cmd_remove(_args("htop"), paths)


def test_list_shows_box_packages_in_text_only(box, paths, tmp_path, capsys):
    alp._install_from_kutu(_args("htop"))
    capsys.readouterr()
    alp.cmd_list(alp.load_db(paths), box=alp._box_packages_of_caller())
    assert "htop\t3.4.1-5\tkutu (alp-debian)" in capsys.readouterr().out
    alp.cmd_list(alp.load_db(paths), as_json=True, box=None)
    assert "htop" not in capsys.readouterr().out


def test_main_kutu_flag_needs_no_catalogue(box, tmp_path, capsys):
    rc = alp.main(["install", "htop", "--kutu", "--yes", "--root", str(tmp_path / "nocatalog")])
    assert rc == 0 and "htop" in _state(tmp_path)
