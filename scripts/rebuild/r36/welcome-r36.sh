#!/bin/bash
# LAYOUT-01 (round 36): the Welcome panel script writes the installed alpbahOS launchers when it cannot read the old
# list (round 35: Plasma defaults with a blank Discover icon and Vim as the browser appeared).
# Run as root on the host.
set -euo pipefail
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
ST=$SB/r36/stage-tool
rm -rf "$ST"; mkdir -p "$SB/r36"
install -D -m 755 "$WT/profiles/welcome/bin/alpbah-hosgeldin-uygula" "$ST/usr/bin/alpbah-hosgeldin-uygula"
cd "$WT"
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-welcome-tool-r36 0.9-r36 "$ST" \
    alpbahos-welcome-tool-r36 0.9-r36
chown yrslf: "$SB/r36"
