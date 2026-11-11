#!/bin/bash
# THEME-01 / SCREENLOCK-01 (round 32): the Welcome apply tool also sets the lock screen wallpaper (kscreenlockerrc,
# image plugin, same package as the desktop). KScreenLocker itself is already in the rebuild base (libkwin links
# libKScreenLocker; kscreenlocker 6.7.4). Record alpbahos-welcome-tool-r32 takes /usr/bin/alpbah-hosgeldin-uygula over.
# Run as root on the host.
set -euo pipefail
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
ST=$SB/r32/stage-tool
rm -rf "$ST"; mkdir -p "$SB/r32"
install -D -m 755 "$WT/profiles/welcome/bin/alpbah-hosgeldin-uygula" "$ST/usr/bin/alpbah-hosgeldin-uygula"
cd "$WT"
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-welcome-tool-r32 0.9-r32 "$ST" \
    alpbahos-welcome-tool-r32 0.9-r32
chown yrslf: "$SB/r32"
