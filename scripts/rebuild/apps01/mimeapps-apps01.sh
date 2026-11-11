#!/bin/bash
# APPS-01: /etc/xdg/mimeapps.list regenerated from profiles/apps/apps.json (the associations are unchanged; the header
# no longer says the apps are missing). Record alpbahos-mimeapps-apps01 0.9-apps01 takes the file over from
# alpbahos-desktop-profile (REPLACE=1). Run as root.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
cd "$WT"
python3 profiles/apps/generate_mimeapps.py --check
ST=$SB/apps01/stage-mimeapps
rm -rf "$ST" && install -D -m 644 profiles/apps/generated/mimeapps.list "$ST/etc/xdg/mimeapps.list"
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-mimeapps-apps01 0.9-apps01 \
    "$ST" alpbahos-mimeapps-apps01 0.9-apps01
echo "mimeapps-apps01 done $(date +%T)"
