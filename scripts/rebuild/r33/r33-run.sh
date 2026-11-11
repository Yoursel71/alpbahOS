#!/bin/bash
# Round 33: greeter colours, PAM kde service, logo, hibernate hidden; installs and the
# Welcome rows including Meta+L lock / password unlock. Runs as the build user (nohup). Logs: scratch-lfs-bench/r33/.
set -u
B=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
cd "$WT"
sudo mv "$B/lfs13-snapshots/r4-iso-src-2026-11-09" "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r32" 2>/dev/null || true
sudo env TAG=r33 bash scripts/rebuild/iso/build-iso.sh > "$B/r33/build-r33.log" 2>&1 || { echo "ISO build failed"; exit 1; }
ROUND=r33 bash scripts/rebuild/r25/run-r25.sh "$B/images/alpbahos-beta-0.9-2026-11-09-r33.iso" installs welcome > "$B/r33/run-r33.out" 2>&1
echo "r33 done $(date +%T)"
