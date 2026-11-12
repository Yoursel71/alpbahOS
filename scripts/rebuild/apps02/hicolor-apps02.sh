#!/bin/bash
# APPS-02 (round 43): the hicolor icon cache regenerated with the new apps' icons (Okular, Gwenview, Ark, Kate, ...);
# record hicolor-icon-cache-apps02 takes the file over from hicolor-icon-cache-apps01 (REPLACE=1; hicolor-cache-r8.sh
# makes it in a copy). A stale cache would hide the new icons from GTK and Qt programs. Run as root.
set -euo pipefail
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=${TARGET_ROOT:-$SB/r4-root}
cd "$WT"
HC=$SB/r43/stage-hicolor
rm -rf "$HC"
bash scripts/rebuild/r8/hicolor-cache-r8.sh "$R4" "$HC"
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py hicolor-icon-cache-apps02 0.9-apps02 \
    "$HC" hicolor-icon-cache-apps02 0.9-apps02
