#!/usr/bin/env python3
"""REBUILD-R5 round 4 record (alp): /usr/bin/modprobe -> kmod.

The kernel's module helper path is CONFIG_MODPROBE_PATH = /usr/bin/modprobe (cat /proc/sys/kernel/modprobe on the
installed system). kmod installs /usr/bin/kmod and links /usr/sbin/modprobe -> ../bin/kmod, so the kernel's
request_module() cannot run the helper: the generic HDA codec (snd-hda-codec-generic) was never loaded in the
QEMU guest with hda-duplex, and no sound card appeared. This record adds the link where the kernel looks for it.
No kernel change. Run as root. Usage: modprobe-path-r5fix.py <R4_ROOT> <ALP_PY> <LEDGER_DIR>
"""
import datetime
import hashlib
import json
import os
import sys

R4, ALP, LEDGER = sys.argv[1], sys.argv[2], sys.argv[3]
NAME = "modprobe-path-r5fix"
VER = "13.1-r5fix"
REPO_SRC = "https://github.com/alperenyardim30-hash/alpbahOS/blob/ai/t2-kisayol-2026-11-05/scripts/rebuild/r5/modprobe-path-r5fix.py"
LINK = "usr/bin/modprobe"
TARGET = "kmod"

os.makedirs(LEDGER, exist_ok=True)
p = os.path.join(R4, LINK)
if os.path.lexists(p):
    raise SystemExit(f"{p} already exists")
os.symlink(TARGET, p)
st = os.lstat(p)
entries = [{"path": "/" + LINK, "type": "symlink", "target": TARGET, "mode": 0o777,
            "uid": st.st_uid, "gid": st.st_gid}]
src_sha = hashlib.sha256(open(os.path.abspath(__file__), "rb").read()).hexdigest()
doc = {"schema": "alpbahOS.package-files/v1",
       "captured_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
       "package": {"name": NAME, "version": VER, "source": {"url": REPO_SRC, "sha256": src_sha}},
       "entries": entries}
json.dump(doc, open(os.path.join(LEDGER, "manifest.json"), "w"), indent=1, sort_keys=True)
print("symlink", p, "->", TARGET)
