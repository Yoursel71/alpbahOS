#!/bin/bash
# Round 35 (D155): the brand wallpaper carries the live wordmark instead of the logo's navy one (unreadable on the dark
# wallpaper, seen in round 34). Record alpbahos-wallpaper-r35 takes over the alpbahOS-Brand images and preview and the
# SDDM theme background (a copy of the 1920x1080 image). Run as root on the host.
set -euo pipefail
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
ST=$SB/r35/stage-wallpaper
SRC=$WT/branding/alpbahos-brand/wallpaper/alpbahOS-Brand/contents
rm -rf "$ST"; D=$ST/usr/share/wallpapers/alpbahOS-Brand/contents
install -d -m 755 "$D/images" "$ST/usr/share/sddm/themes/alpbahos"
install -m 644 "$SRC"/images/*.png "$D/images/"; install -m 644 "$SRC/screenshot.png" "$D/screenshot.png"
install -m 644 "$SRC/images/1920x1080.png" "$ST/usr/share/sddm/themes/alpbahos/background.png"
cd "$WT"
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-wallpaper-r35 0.9-r35 "$ST" alpbahos-wallpaper-r35 0.9-r35
chown -R yrslf: "$SB/r35"
