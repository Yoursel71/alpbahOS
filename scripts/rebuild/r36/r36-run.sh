#!/bin/bash
# Round 36: ISO with the Welcome launcher fallback (alpbahos-welcome-tool-r36); installs, Welcome rows (taskbar after
# "Uygula ve başla"), B1/U1 and the matrix B2 row (idle memory at 4 GiB). Runs as the build user (nohup).
set -u
B=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
cd "$WT"
[ -e "$B/test-secrets/r36.pw" ] || (umask 077; cp "$B/test-secrets/r21.pw" "$B/test-secrets/r36.pw")
sudo mv "$B/lfs13-snapshots/r4-iso-src-2026-11-09" "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r35" 2>/dev/null || true
sudo env TAG=r36 bash scripts/rebuild/iso/build-iso.sh > "$B/r36/build-r36.log" 2>&1 || { echo "ISO build failed"; exit 1; }
ROUND=r36 bash scripts/rebuild/r25/run-r25.sh "$B/images/alpbahos-beta-0.9-2026-11-09-r36.iso" installs welcome timing > "$B/r36/run-r36.out" 2>&1
MD=$B/lfs13-logs/iso-beta-0.9/r36/matrix; mkdir -p "$MD"
env MROUND=r36 bash scripts/rebuild/r21/matrix-r21.sh diag B2 > "$MD/run-B2.out" 2>&1
echo "r36 done $(date +%T)"
