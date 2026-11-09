#!/usr/bin/env python3
"""REBUILD-R5 autologin record (alp): /etc/pam.d/sddm-autologin, the stack that autologged the live user on the
alpha ISO (sddm-config-r4fix content). Recorded as alp package "autologin-r5fix" (13.1-r5fix), which takes the
file from session-r5fix (transfer). Run as root. Usage: autologin-r5fix.py <R4_ROOT> <ALP_PY> <LEDGER_DIR>

Why this file is not the one in session-r5fix: that revision added pam_succeed_if and pam_exec (live-medium check)
to the autologin stack, and sddm-helper then failed the autologin (exit 9) on the DEBUG live ISO (2026-11-09).
The stack is therefore kept as on the alpha ISO. The live-only restriction is in the sddm configuration instead:
the autologin User=live exists only in the live image (build-iso.sh), and target-cleanup.sh removes it.
"""
import datetime
import hashlib
import json
import os
import shutil
import stat
import sys

R4, ALP, LEDGER = sys.argv[1], sys.argv[2], sys.argv[3]
NAME = "autologin-r5fix"
VER = "13.1-r5fix"
REPO_SRC = "https://github.com/alperenyardim30-hash/alpbahOS/blob/claude/t2-kisayol-2026-11-05/scripts/rebuild/r5/autologin-r5fix.py"
REL = "etc/pam.d/sddm-autologin"

CONTENT = """#%PAM-1.0
# REBUILD-R5: the autologin stack of the alpha ISO (unchanged). The live-only restriction is the sddm
# configuration (User=live exists only in the live image).
auth        required    pam_env.so
auth        required    pam_faillock.so preauth
auth        required    pam_shells.so
auth        required    pam_nologin.so
auth        required    pam_permit.so
-auth       optional    pam_gnome_keyring.so
-auth       optional    pam_kwallet5.so
account     include     system-account
password    include     system-password
session     include     system-session
-session    optional    pam_gnome_keyring.so auto_start
-session    optional    pam_kwallet5.so auto_start
"""

os.makedirs(LEDGER, exist_ok=True)
p = os.path.join(R4, REL)
bak = os.path.join(LEDGER, REL.replace("/", "_") + ".before")
if os.path.exists(p) and not os.path.exists(bak):
    shutil.copy2(p, bak)
with open(p, "w") as f:
    f.write(CONTENT)
os.chmod(p, 0o644)
os.chown(p, 0, 0)
st = os.lstat(p)
entries = [{"path": "/" + REL, "type": "file", "mode": stat.S_IMODE(st.st_mode), "uid": 0, "gid": 0,
            "size": st.st_size, "sha256": hashlib.sha256(open(p, "rb").read()).hexdigest()}]
src_sha = hashlib.sha256(open(os.path.abspath(__file__), "rb").read()).hexdigest()
doc = {"schema": "alpbahOS.package-files/v1",
       "captured_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
       "package": {"name": NAME, "version": VER, "source": {"url": REPO_SRC, "sha256": src_sha}},
       "entries": entries}
man = os.path.join(LEDGER, "manifest.json")
json.dump(doc, open(man, "w"), indent=1, sort_keys=True)
print("entries", len(entries))
print("manifest", man)
