#!/usr/bin/env python3
"""REBUILD-R5 round 2 record (alp): sddm starts after udev has settled.

Writes /etc/systemd/system/sddm.service.d/10-alpbahos-udev.conf into an R4 root and records it as alp package
"display-order-r5fix" (13.1-r5fix) with alp adopt-base. Run as root. Usage: display-order-r5fix.py <R4_ROOT> <ALP_PY> <LEDGER_DIR>

Why: on UEFI the live kernel starts on simpledrm (efifb handover) and the virtio-gpu DRM device appears about 30 s
after sddm has started. The sddm autologin helper of the Wayland session was killed (SIGKILL, "exited with 9") about
5 s after it started, and sddm fell back to the greeter. BIOS has no simpledrm and autologged. With
`udevadm settle` before sddm starts, UEFI autologin succeeded in the probe runs (see the record document).
"""
import datetime
import hashlib
import json
import os
import shutil
import stat
import sys

R4, ALP, LEDGER = sys.argv[1], sys.argv[2], sys.argv[3]
NAME = "display-order-r5fix"
VER = "13.1-r5fix"
REPO_SRC = "https://github.com/alperenyardim30-hash/alpbahOS/blob/ai/t2-kisayol-2026-11-05/scripts/rebuild/r5/display-order-r5fix.py"
REL = "etc/systemd/system/sddm.service.d/10-alpbahos-udev.conf"
CONTENT = """# REBUILD-R5 round 2 (alp package display-order-r5fix): sddm starts after udev has settled, so the DRM
# device (virtio-gpu on UEFI appears after simpledrm) exists before the autologin session starts.
[Unit]
After=systemd-udev-settle.service
[Service]
ExecStartPre=/usr/bin/udevadm settle --timeout=60
"""

os.makedirs(LEDGER, exist_ok=True)
p = os.path.join(R4, REL)
os.makedirs(os.path.dirname(p), exist_ok=True)
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
json.dump(doc, open(os.path.join(LEDGER, "manifest.json"), "w"), indent=1, sort_keys=True)
print("entries", len(entries))
