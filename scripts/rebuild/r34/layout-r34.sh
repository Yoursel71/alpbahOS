#!/bin/bash
# Round 34 (LAYOUT-01 follow-up): the default layout pins only launchers whose .desktop file exists
# (applicationExists), so the missing Firefox and LibreOffice no longer show blank icons on the taskbar.
# Record alpbahos-layout-r34 takes the look-and-feel layout script over. Run as root on the host.
set -euo pipefail
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
REL=usr/share/plasma/look-and-feel/org.alpbahos.solid.desktop/contents/layouts/org.kde.plasma.desktop-layout.js
ST=$SB/r34/stage-layout
rm -rf "$ST"; mkdir -p "$(dirname "$ST/$REL")"
install -m 644 "$WT/profiles/desktop/lookandfeel/org.alpbahos.solid.desktop/contents/layouts/org.kde.plasma.desktop-layout.js" "$ST/$REL"
cd "$WT"
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-layout-r34 0.9-r34 "$ST" alpbahos-layout-r34 0.9-r34
chown -R yrslf: "$SB/r34"
