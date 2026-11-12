#!/bin/bash
# APPS-02 (round 43): /etc/xdg/mimeapps.list regenerated from profiles/apps/apps.json; the header now names the KDE apps
# that are in the image (Okular, Gwenview, Ark, KWrite). Record alpbahos-mimeapps-apps02 takes the file over (REPLACE=1).
# Run as root.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
cd "$WT"
python3 profiles/apps/generate_mimeapps.py --check
ST=$SB/r43/stage-mimeapps
rm -rf "$ST" && install -D -m 644 profiles/apps/generated/mimeapps.list "$ST/etc/xdg/mimeapps.list"
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-mimeapps-apps02 0.9-apps02 \
    "$ST" alpbahos-mimeapps-apps02 0.9-apps02
echo "mimeapps-apps02 done $(date +%T)"
