#!/bin/bash
# Round 39: the r38 content plus the real KSplash loading bar (alpbahos-loadingbar-r39, wallpaper without the line)
# and the user's ASCII logo in fastfetch (alpbahos-fastfetch-ascii-r39); installs, Welcome rows, timing and KSplash
# frames (run-r25.sh), the matrix APPS row and B2. This is the ISO for the real-PC USB test (BETA-01).
# Runs as the build user (nohup); sudo for the ISO build.
# Before the build: r4-root/tmp must hold no build tree (build-iso.sh empties /tmp in the live copy anyway).
set -u
B=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
cd "$WT"
mkdir -p "$B/r39"
[ -e "$B/test-secrets/r39.pw" ] || (umask 077; cp "$B/test-secrets/r21.pw" "$B/test-secrets/r39.pw")
sudo ls "$B/r4-root/tmp" > "$B/r39/r4-tmp-before.txt" 2>&1
sudo mv "$B/lfs13-snapshots/r4-iso-src-2026-11-09" "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r38" 2>/dev/null || true
sudo env TAG=r39 bash scripts/rebuild/iso/build-iso.sh > "$B/r39/build-r39.log" 2>&1 || { echo "ISO build failed"; exit 1; }
ROUND=r39 bash scripts/rebuild/r25/run-r25.sh "$B/images/alpbahos-beta-0.9-2026-11-09-r39.iso" installs welcome timing ksplash > "$B/r39/run-r39.out" 2>&1
MD=$B/lfs13-logs/iso-beta-0.9/r39/matrix; mkdir -p "$MD"
env MROUND=r39 bash scripts/rebuild/r21/matrix-r21.sh apps > "$MD/run-APPS.out" 2>&1
env MROUND=r39 bash scripts/rebuild/r21/matrix-r21.sh diag B2 > "$MD/run-B2.out" 2>&1
echo "r39 done $(date +%T)"
