#!/bin/bash
# Round 37: ISO with the APPS-01 apps (Firefox 153.2.0esr + Turkish language pack, VLC 3.0.23, LibreOffice 26.2.5.2
# and their dependencies); installs, Welcome rows and timing (run-r25.sh), the matrix APPS row (apps in the session,
# alp trust rows) and B2 (idle memory at 4 GiB). Runs as the build user (nohup); sudo for the ISO build.
# Before the build: r4-root/tmp must hold no build tree (build-iso.sh empties /tmp in the live copy anyway).
set -u
B=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
cd "$WT"
mkdir -p "$B/r37"
[ -e "$B/test-secrets/r37.pw" ] || (umask 077; cp "$B/test-secrets/r21.pw" "$B/test-secrets/r37.pw")
sudo ls "$B/r4-root/tmp" > "$B/r37/r4-tmp-before.txt" 2>&1
sudo mv "$B/lfs13-snapshots/r4-iso-src-2026-11-09" "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r36" 2>/dev/null || true
sudo env TAG=r37 bash scripts/rebuild/iso/build-iso.sh > "$B/r37/build-r37.log" 2>&1 || { echo "ISO build failed"; exit 1; }
ROUND=r37 bash scripts/rebuild/r25/run-r25.sh "$B/images/alpbahos-beta-0.9-2026-11-09-r37.iso" installs welcome timing > "$B/r37/run-r37.out" 2>&1
MD=$B/lfs13-logs/iso-beta-0.9/r37/matrix; mkdir -p "$MD"
env MROUND=r37 bash scripts/rebuild/r21/matrix-r21.sh apps > "$MD/run-APPS.out" 2>&1
env MROUND=r37 bash scripts/rebuild/r21/matrix-r21.sh diag B2 > "$MD/run-B2.out" 2>&1
echo "r37 done $(date +%T)"
