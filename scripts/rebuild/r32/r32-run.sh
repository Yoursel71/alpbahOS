#!/bin/bash
# Round 32: ISO with the Welcome tool that also sets the lock screen (THEME-01, SCREENLOCK-01); installs and the
# Welcome rows including Meta+L lock / password unlock. Runs as the build user (nohup). Logs: scratch-lfs-bench/r32/.
set -u
B=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
cd "$WT"
sudo mv "$B/lfs13-snapshots/r4-iso-src-2026-11-09" "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r31" 2>/dev/null || true
sudo env TAG=r32 bash scripts/rebuild/iso/build-iso.sh > "$B/r32/build-r32.log" 2>&1 || { echo "ISO build failed"; exit 1; }
ROUND=r32 bash scripts/rebuild/r25/run-r25.sh "$B/images/alpbahos-beta-0.9-2026-11-09-r32.iso" installs welcome > "$B/r32/run-r32.out" 2>&1
echo "r32 done $(date +%T)"
