#!/bin/bash
# Round 40 (FW-DIRLINK-01, found after the real-PC test): the linux-firmware record (firmware-r20.sh, row 399) lost every
# WHENCE "Link:" whose target is a directory, because stage-record-r8.py took entries only from os.walk's file list and
# os.walk lists a symlink to a directory under the directory list. 16 links were missing, among them nvidia/gb206 ->
# gb202: nouveau could not load the GSP firmware of the user's RTX 5060 ("gsp: Failed to load required firmware") and the
# display ran on simpledrm. Also missing: tu104/tu106/tu117 gsp, ga103-ga107 gsp, ad103-ad107, gb102, gb203-gb207.
# stage-record-r8.py is fixed in the same round; this script adds the missing links as their own alp record
# (linux-firmware-dirlinks 20261019-r40), taken from the WHENCE that the linux-firmware record installed.
# Run as root. Env TARGET_ROOT/LEDGER_DIR (apply-r7.sh) for another root.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=${TARGET_ROOT:-$SB/r4-root}
ST=$SB/r40/stage-fw-dirlinks
cd "$WT"
[ -s "$R4/usr/lib/firmware/WHENCE" ] || { echo "no linux-firmware WHENCE in $R4"; exit 1; }
rm -rf "$ST" && install -d "$ST/usr/lib/firmware"
python3 -I - "$R4/usr/lib/firmware" "$ST/usr/lib/firmware" <<'EOF'
import os, sys
fw, st = sys.argv[1:3]
n = 0
for line in open(os.path.join(fw, "WHENCE"), encoding="utf-8", errors="replace"):
    if not line.startswith("Link:"):
        continue
    link, target = (x.strip() for x in line[5:].split(" -> "))
    if os.path.lexists(os.path.join(fw, link)):
        continue
    resolved = os.path.normpath(os.path.join(fw, os.path.dirname(link), target))
    if not os.path.isdir(resolved):
        continue  # file links are installed (as .zst); only directory links were lost
    os.makedirs(os.path.join(st, os.path.dirname(link)), exist_ok=True)
    os.symlink(target, os.path.join(st, link))
    print(f"link {link} -> {target}")
    n += 1
print(f"directory links to add: {n}")
EOF
[ -n "$(find "$ST" -type l)" ] || { echo "nothing to add"; exit 0; }
bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py linux-firmware-dirlinks 20261019-r40 "$ST" \
    linux-firmware-dirlinks 20261019-r40
for g in gb206 ad104 ga104 tu106; do
    f=$(ls "$R4/usr/lib/firmware/nvidia/$g/gsp/"gsp-*.bin.zst 2>/dev/null | head -1)
    [ -n "$f" ] && [ -s "$(readlink -f "$f")" ] && echo "check $g: $(basename "$f") resolves" || { echo "check $g: FAILED"; exit 1; }
done
