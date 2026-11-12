#!/usr/bin/env python3
"""REBUILD-R5 session record (alp): user-session stop order, ksplash stop status, live-only autologin PAM.

Writes the files into an R4 root and records them as one alp package "session-r5fix" (13.1-r5fix) with
alp adopt-base. Run as root. Usage: session-r5fix.py <R4_ROOT> <ALP_PY> <LEDGER_DIR>

Why (see docs/verification/iso-beta-0.9-2026-11-09.md, section 2):
  * The user-session units had no ordering against the session D-Bus bus (dbus.service). At logout or
    power-off systemd stopped the bus in parallel with the Plasma units, so ksmserver and kded6 called
    dbus_pending_call_block on a disconnected connection (libdbus assertion, SIGABRT, core dump).
  * pipewire lost its X11 display (Xwayland of kwin) before it stopped, and its x11-bell module aborted
    (SIGABRT, core dump). pipewire now stops before kwin and before dbus.
  * plasma-ksplash is stopped with SIGTERM by the session; systemd counted that as a failure
    ("Failed with result 'signal'"). SIGTERM is now a successful stop status for that unit.
  * The autologin PAM stack is allowed only for the live user on the live medium (kernel argument
    rd.live.image). The installed system has no live user, so the check fails there.
"""
import datetime
import hashlib
import json
import os
import stat
import subprocess
import sys

R4, ALP, LEDGER = sys.argv[1], sys.argv[2], sys.argv[3]
NAME = "session-r5fix"
VER = "13.1-r5fix"
# Config record: there is no upstream archive. The source is this file in the repository; the sha256 is the
# sha256 of this file (computed below). adopt-base requires an https URL.
REPO_SRC = "https://github.com/alperenyardim30-hash/alpbahOS/blob/ai/t2-kisayol-2026-11-05/scripts/rebuild/r5/session-r5fix.py"
HERE = os.path.dirname(os.path.abspath(__file__))

PLASMA_UNITS = []
for n in sorted(os.listdir(os.path.join(R4, "usr/lib/systemd/user"))):
    if (n.startswith("plasma-") and n.endswith(".service")) or n == "at-spi-dbus-bus.service":
        PLASMA_UNITS.append(n)
PIPE_UNITS = ["pipewire.service", "pipewire-pulse.service", "wireplumber.service"]

HDR = "# REBUILD-R5 session-r5fix (alp package session-r5fix): stop order of the user session.\n"

files = {}   # path -> (content, mode)
for u in PLASMA_UNITS:
    if u in ("plasma-kwin_wayland.service", "plasma-kwin_x11.service"):
        after = "dbus.service"
    else:
        after = "dbus.service plasma-kwin_wayland.service"
    files[f"etc/systemd/user/{u}.d/10-alpbahos-stop-order.conf"] = (
        HDR + "# Stop before the session bus (and before the compositor) at logout or power-off.\n"
        f"[Unit]\nAfter={after}\n", 0o644)
for u in PIPE_UNITS:
    files[f"etc/systemd/user/{u}.d/10-alpbahos-stop-order.conf"] = (
        HDR + "# pipewire has an X11 bell client on the compositor's X display: stop before kwin and dbus.\n"
        "[Unit]\nAfter=dbus.service plasma-kwin_wayland.service\n", 0o644)
files["etc/systemd/user/plasma-ksplash.service.d/10-alpbahos-stop-status.conf"] = (
    HDR + "# The session stops the splash with SIGTERM; that is a normal stop.\n[Service]\nSuccessExitStatus=SIGTERM\n",
    0o644)
# (The sddm-autologin PAM stack is owned by autologin-r5fix; the live-medium helper was removed in R5 round 2.)

# /etc/pam.d/login: missing in the R4 root, so login(1) (the console getty) refused every login without
# asking for a password. The book's Linux-PAM login stack, with the system stacks of R4.
files["etc/pam.d/login"] = (
    "#%PAM-1.0\n"
    "# REBUILD-R5: /etc/pam.d/login (the book's Linux-PAM login stack). Without this file login(1) fails\n"
    "# without asking for a password (\"Login incorrect\"), so the console getty cannot log in.\n"
    "auth      optional    pam_faildelay.so  delay=3000\n"
    "auth      requisite   pam_nologin.so\n"
    "auth      include     system-auth\n"
    "account   include     system-account\n"
    "password  include     system-password\n"
    "session   required    pam_loginuid.so\n"
    "session   include     system-session\n"
    "session   optional    pam_motd.so\n", 0o644)

# Write files and collect the manifest (paths as alp sees them, owned by root).
os.makedirs(LEDGER, exist_ok=True)
entries = []
for rel, (content, mode) in sorted(files.items()):
    p = os.path.join(R4, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    if os.path.exists(p) and not os.path.exists(os.path.join(LEDGER, rel.replace("/", "_") + ".before")):
        subprocess.run(["cp", "-p", p, os.path.join(LEDGER, rel.replace("/", "_") + ".before")], check=False)
    with open(p, "w") as f:
        f.write(content)
    os.chmod(p, mode)
    os.chown(p, 0, 0)
    st = os.lstat(p)
    entries.append({"path": "/" + rel, "type": "file", "mode": stat.S_IMODE(st.st_mode),
                    "uid": 0, "gid": 0, "size": st.st_size,
                    "sha256": hashlib.sha256(open(p, "rb").read()).hexdigest()})

src_sha = hashlib.sha256(open(os.path.abspath(__file__), "rb").read()).hexdigest()
doc = {"schema": "alpbahOS.package-files/v1",
       "captured_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
       "package": {"name": NAME, "version": VER, "source": {"url": REPO_SRC, "sha256": src_sha}},
       "entries": entries}
man = os.path.join(LEDGER, "manifest.json")
json.dump(doc, open(man, "w"), indent=1, sort_keys=True)
print("entries", len(entries))
print("manifest", man)
