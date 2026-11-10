#!/bin/bash
# Round 25 (LIVE-PROFILE-01 fix after the round 24 live session): record alpbahos-desktop-profile-r25 0.9-r25 in r4-root.
# It takes over /etc/xdg/kdeglobals (now with the alpbah-dark colour groups) and the look-and-feel defaults
# ([plasmarc][Theme] name=breeze-dark), and adds /etc/xdg/plasmarc (breeze-dark) and /etc/xdg/plasma-welcomerc
# (LastSeenVersion=6.7.4: the KDE Welcome Center does not open by itself; the kded6rc switch alone did not stop it).
# Run as root on the host.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=$SB/r4-root
ST=$SB/r25/stage-profile
rm -rf "$ST"; mkdir -p "$ST/etc/xdg" "$ST/usr/share/plasma/look-and-feel/org.alpbahos.solid.desktop/contents"
install -m 644 "$WT/profiles/desktop/xdg/kdeglobals" "$WT/profiles/desktop/xdg/plasmarc" \
    "$WT/profiles/desktop/xdg/plasma-welcomerc" "$ST/etc/xdg/"
install -m 644 "$WT/profiles/desktop/lookandfeel/org.alpbahos.solid.desktop/contents/defaults" \
    "$ST/usr/share/plasma/look-and-feel/org.alpbahos.solid.desktop/contents/defaults"
cd "$WT"
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-desktop-profile-r25 0.9-r25 \
    "$ST" alpbahos-desktop-profile-r25 0.9-r25
grep -c '^\[Colors:' "$R4/etc/xdg/kdeglobals"; cat "$R4/etc/xdg/plasmarc" "$R4/etc/xdg/plasma-welcomerc" | grep -v '^#'
