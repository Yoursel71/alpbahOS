#!/usr/bin/env python3
"""NET-FW-01 acceptance check: firmware named by the Wi-Fi and GPU kernel modules is present in a root tree.

For every module of the listed driver directories, `modinfo -F firmware <ko>` gives the firmware names the driver may
request. A name counts as "shipped" when linux-firmware's WHENCE (File: or Link: lines, installed in the root as
usr/lib/firmware/WHENCE) lists it. Every shipped name must exist in the root as NAME, NAME.zst or NAME.xz (symlinks
followed). Names that linux-firmware does not ship are listed separately (normal for the newest iwlwifi API levels and
for optional files). Exit 1 when a shipped name is missing.
Runs on the host (modinfo reads the .ko files; no chroot). Usage: fw-coverage-r20.py <ROOT> <KVER>
"""
import glob
import os
import subprocess
import sys

ROOT, KVER = sys.argv[1], sys.argv[2]
FW = os.path.join(ROOT, "usr/lib/firmware")
KDIR = os.path.join(ROOT, "usr/lib/modules", KVER, "kernel/drivers")
GROUPS = {
    "iwlwifi": "net/wireless/intel/iwlwifi/**/*.ko*",
    "rtw88": "net/wireless/realtek/rtw88/**/*.ko*",
    "rtw89": "net/wireless/realtek/rtw89/**/*.ko*",
    "mt7921e": "net/wireless/mediatek/mt76/mt7921/**/*.ko*",
    "ath10k": "net/wireless/ath/ath10k/**/*.ko*",
    "amdgpu": "gpu/drm/amd/amdgpu/**/*.ko*",
    "i915": "gpu/drm/i915/**/*.ko*",
    "xe": "gpu/drm/xe/**/*.ko*",
}

shipped = set()
with open(os.path.join(FW, "WHENCE"), encoding="utf-8", errors="replace") as f:
    for line in f:
        if line.startswith("File:") or line.startswith("RawFile:"):
            shipped.add(line.split(":", 1)[1].strip().strip('"'))
        elif line.startswith("Link:"):
            shipped.add(line.split(":", 1)[1].split("->")[0].strip())


def present(name):
    return any(os.path.exists(os.path.join(FW, name + ext)) for ext in ("", ".zst", ".xz"))


bad = 0
print("group\tmodules\tnamed\tshipped\tpresent\tmissing_shipped\tnot_shipped")
for group, pattern in GROUPS.items():
    kos = sorted(glob.glob(os.path.join(KDIR, pattern), recursive=True))
    names = set()
    for ko in kos:
        out = subprocess.run(["modinfo", "-F", "firmware", ko], capture_output=True, text=True, check=True).stdout
        names.update(n.strip() for n in out.splitlines() if n.strip())
    sh = sorted(n for n in names if n in shipped)
    miss = [n for n in sh if not present(n)]
    not_sh = sorted(n for n in names if n not in shipped)
    print(f"{group}\t{len(kos)}\t{len(names)}\t{len(sh)}\t{len(sh) - len(miss)}\t{len(miss)}\t{len(not_sh)}")
    for n in miss:
        print(f"  MISSING (shipped by linux-firmware): {n}")
    for n in not_sh:
        print(f"  not shipped: {n}")
    if not kos:
        print(f"  NO MODULES FOUND for {group}")
        bad = 1
    bad |= bool(miss)
sys.exit(1 if bad else 0)
