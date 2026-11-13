"""SAFE-GFX-01 (round 50): the start counter, the start confirmation and the GRUB script of the safe-graphics fallback.

The three shell scripts (scripts/rebuild/r50/files/) take their paths from ALPBAHOS_* variables so that they run against a
fake grub-editenv, a fake loginctl and a fake /boot here. The image uses the defaults (/usr/bin/grub-editenv, /boot/grub/grubenv)."""
import json
import os
import subprocess
import textwrap
from pathlib import Path

import pytest

FILES = Path(__file__).resolve().parents[1] / "scripts" / "rebuild" / "r50" / "files"


def _write(path, text, mode=0o755):
    path.write_text(textwrap.dedent(text))
    path.chmod(mode)
    return path


@pytest.fixture()
def env(tmp_path):
    """Fake grub-editenv (a key=value file), fake loginctl (sessions from sessions.json), a cmdline file."""
    bindir = tmp_path / "bin"
    bindir.mkdir()
    grubenv = tmp_path / "grubenv"
    grubenv.write_text("# GRUB Environment Block\nsaved_entry=alpbahOS\n")
    _write(bindir / "grub-editenv", f"""\
        #!/usr/bin/env python3
        import sys
        f, cmd, *rest = sys.argv[1:]
        lines = [l.rstrip("\\n") for l in open(f)]
        kv = dict(l.split("=", 1) for l in lines if "=" in l and not l.startswith("#"))
        if cmd == "list":
            print("\\n".join(f"{{k}}={{v}}" for k, v in kv.items()))
        elif cmd == "set":
            for a in rest:
                k, v = a.split("=", 1); kv[k] = v
            open(f, "w").write("# GRUB Environment Block\\n" + "".join(f"{{k}}={{v}}\\n" for k, v in kv.items()))
        """)
    sessions = tmp_path / "sessions.json"
    sessions.write_text("{}")
    _write(bindir / "loginctl", f"""\
        #!/usr/bin/env python3
        import json, sys
        s = json.load(open({str(sessions)!r}))
        a = sys.argv[1:]
        if a[0] == "list-sessions":
            for sid in s: print(sid, 1000, "u", "seat0")
        elif a[0] == "show-session":
            print(s[a[1]][a[3].lower()])
        """)
    cmdline = tmp_path / "cmdline"
    cmdline.write_text("BOOT_IMAGE=/boot/vmlinuz root=/dev/vda2 ro quiet splash\n")
    e = dict(os.environ, PATH=f"{bindir}:{os.environ['PATH']}", ALPBAHOS_GRUB_EDITENV=str(bindir / "grub-editenv"),
             ALPBAHOS_GRUBENV=str(grubenv), ALPBAHOS_CMDLINE=str(cmdline), ALPBAHOS_OK_SLEEP="0")
    return e, grubenv, sessions, cmdline


def tries(grubenv):
    for line in grubenv.read_text().splitlines():
        if line.startswith("alpbahos_tries="):
            return line.split("=", 1)[1]
    return None


def run(script, e):
    return subprocess.run(["sh", str(FILES / script)], env=e, capture_output=True, text=True, timeout=30)


def test_boot_try_counts_each_normal_start_and_stops_at_two(env):
    e, grubenv, _, _ = env
    for want in ("x", "xx", "xx", "xx"):
        assert run("alpbahos-boot-try", e).returncode == 0
        assert tries(grubenv) == want


def test_boot_try_skips_the_safe_start(env):
    e, grubenv, _, cmdline = env
    cmdline.write_text("BOOT_IMAGE=/boot/vmlinuz root=/dev/vda2 ro alpbahos.safe=1\n")
    run("alpbahos-boot-try", e)
    assert tries(grubenv) is None
    assert "saved_entry=alpbahOS" in grubenv.read_text()          # the other variables are kept


def _ok_env(e, need="3", timeout="6"):
    return dict(e, ALPBAHOS_OK_STABLE=need, ALPBAHOS_OK_TIMEOUT=timeout)


def test_boot_ok_clears_the_counter_for_a_greeter_session(env):
    e, grubenv, sessions, _ = env
    run("alpbahos-boot-try", e); run("alpbahos-boot-try", e)
    assert tries(grubenv) == "xx"
    sessions.write_text(json.dumps({"c1": {"class": "greeter", "type": "wayland", "state": "active"}}))
    assert run("alpbahos-boot-ok", _ok_env(e)).returncode == 0
    assert tries(grubenv) == ""


def test_boot_ok_accepts_a_user_x11_session(env):
    e, grubenv, sessions, _ = env
    run("alpbahos-boot-try", e)
    sessions.write_text(json.dumps({"2": {"class": "user", "type": "x11", "state": "online"}}))
    assert run("alpbahos-boot-ok", _ok_env(e)).returncode == 0
    assert tries(grubenv) == ""


@pytest.mark.parametrize("sess", [
    {},                                                                                    # nothing started (the real-PC failure)
    {"1": {"class": "manager-early", "type": "unspecified", "state": "active"}},           # only the sddm manager session
    {"c1": {"class": "greeter", "type": "wayland", "state": "closing"}},                   # greeter died
    {"3": {"class": "user", "type": "tty", "state": "active"}},                            # a text login is not a desktop
])
def test_boot_ok_leaves_the_counter_when_there_is_no_graphical_session(env, sess):
    e, grubenv, sessions, _ = env
    run("alpbahos-boot-try", e)
    sessions.write_text(json.dumps(sess))
    r = run("alpbahos-boot-ok", _ok_env(e, timeout="4"))
    assert r.returncode == 1
    assert tries(grubenv) == "x"


@pytest.fixture()
def grubdir(tmp_path):
    lib = tmp_path / "grub"
    lib.mkdir()
    (lib / "grub-mkconfig_lib").write_text('prepare_grub_to_access_device() { echo "set root=fake"; }\n')
    boot = tmp_path / "boot"
    boot.mkdir()
    (boot / "vmlinuz-6.1.0-test").write_text("k")
    (boot / "initramfs-6.1.0-test.img").write_text("i")
    return lib, boot


def grub_output(grubdir, **extra):
    lib, boot = grubdir
    base = dict(pkgdatadir=str(lib), ALPBAHOS_BOOT_DIR=str(boot), GRUB_DEVICE="/dev/vda2", GRUB_DEVICE_BOOT="/dev/vda2",
                GRUB_DISABLE_LINUX_PARTUUID="false", GRUB_CMDLINE_LINUX="")
    base.update(extra)
    e = dict(os.environ, **base)
    r = subprocess.run(["sh", str(FILES / "42_alpbahos_safe")], env=e, capture_output=True, text=True, timeout=30)
    assert r.returncode == 0, r.stderr
    return r.stdout


def test_grub_script_switches_to_the_safe_entry_after_two_unconfirmed_starts(grubdir):
    out = grub_output(grubdir)
    assert 'if [ "${alpbahos_tries}" = "xx" ]; then' in out
    assert 'set default="alpbahos-safe"' in out and "save_env alpbahos_tries" in out
    assert "menuentry 'alpbahOS (güvenli grafik)'" in out and "'alpbahos-safe'" in out


def test_grub_safe_entry_blacklists_nvidia_and_uses_the_image_paths(grubdir):
    out = grub_output(grubdir)
    line = next(l for l in out.splitlines() if l.strip().startswith("linux"))
    assert "/boot/vmlinuz-6.1.0-test" in line and "alpbahos.safe=1" in line
    assert "module_blacklist=nvidia,nvidia_drm,nvidia_modeset,nvidia_uvm" in line
    assert "50_mesa.json" in line                                                           # Mesa EGL, not the NVIDIA vendor library
    assert "/boot/initramfs-6.1.0-test.img" in out and str(grubdir[1]) not in out           # the test directory never leaks into grub.cfg


def test_grub_safe_entry_keeps_the_encrypted_root_arguments(grubdir):
    out = grub_output(grubdir, GRUB_DEVICE="/dev/mapper/luks-1234", GRUB_DEVICE_PARTUUID="",
                      GRUB_CMDLINE_LINUX="rd.luks.uuid=1234 rd.luks.key=/crypto_keyfile.bin")
    line = next(l for l in out.splitlines() if l.strip().startswith("linux"))
    assert "root=/dev/mapper/luks-1234" in line and "root=PARTUUID=" not in line          # no empty PARTUUID (GRUB-ROOT-01)
    assert "rd.luks.uuid=1234" in line and "rd.luks.key=/crypto_keyfile.bin" in line


def test_grub_safe_entry_uses_partuuid_when_there_is_one(grubdir):
    out = grub_output(grubdir, GRUB_DEVICE_PARTUUID="abcd-01")
    assert "root=PARTUUID=abcd-01" in out


def test_grub_script_prints_nothing_without_a_kernel(tmp_path):
    lib = tmp_path / "grub"; lib.mkdir(); (lib / "grub-mkconfig_lib").write_text("")
    (tmp_path / "boot").mkdir()
    e = dict(os.environ, pkgdatadir=str(lib), ALPBAHOS_BOOT_DIR=str(tmp_path / "boot"))
    r = subprocess.run(["sh", str(FILES / "42_alpbahos_safe")], env=e, capture_output=True, text=True, timeout=30)
    assert r.returncode == 0 and r.stdout == ""
