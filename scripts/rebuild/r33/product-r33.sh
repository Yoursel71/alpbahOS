#!/bin/bash
# Round 33: record alpbahos-pam-kde-r33, sddm-alpbahos-r33 and alpbahos-colors-r33 (product-r33.py) in r4-root.
# Run as root on the host.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=$SB/r4-root
ST=$SB/r33/stage
rm -rf "$ST"; mkdir -p "$SB/r33"; chown yrslf: "$SB/r33"
sudo -u yrslf python3 "$WT/scripts/rebuild/r33/product-r33.py" "$R4" "$ST"
chown -R root:root "$ST"
cd "$WT"
bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-pam-kde-r33 0.9-r33 "$ST/pam" alpbahos-pam-kde-r33 0.9-r33
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py sddm-alpbahos-r33 0.9-r33 "$ST/sddm" sddm-alpbahos-r33 0.9-r33
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-colors-r33 0.9-r33 "$ST/colors" alpbahos-colors-r33 0.9-r33
grep GreeterEnvironment "$R4/etc/sddm.conf"; ls -l "$R4/etc/pam.d/kde" "$R4/etc/pam.d/kscreensaver"
grep -c "Colors:Complementary" "$R4/etc/xdg/kdeglobals" "$R4/usr/share/color-schemes/alpbah-dark.colors"
chown -R yrslf: "$SB/r33"
