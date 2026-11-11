#!/bin/bash
# Round 38: the r37 content plus VLC through Xwayland (vlc-alpbahos-desktop), xdg-utils (with lynx, xmlto and the
# DocBook catalog fix) and the regenerated mimeapps.list; installs, Welcome rows and timing (run-r25.sh), the matrix
# APPS row (apps in the session, alp trust rows, VLC through its desktop entry, xdg-settings) and B2 (idle memory at
# 4 GiB). Runs as the build user (nohup); sudo for the ISO build.
# Before the build: r4-root/tmp must hold no build tree (build-iso.sh empties /tmp in the live copy anyway).
set -u
B=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
cd "$WT"
mkdir -p "$B/r38"
[ -e "$B/test-secrets/r38.pw" ] || (umask 077; cp "$B/test-secrets/r21.pw" "$B/test-secrets/r38.pw")
sudo ls "$B/r4-root/tmp" > "$B/r38/r4-tmp-before.txt" 2>&1
sudo mv "$B/lfs13-snapshots/r4-iso-src-2026-11-09" "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r37" 2>/dev/null || true
sudo env TAG=r38 bash scripts/rebuild/iso/build-iso.sh > "$B/r38/build-r38.log" 2>&1 || { echo "ISO build failed"; exit 1; }
ROUND=r38 bash scripts/rebuild/r25/run-r25.sh "$B/images/alpbahos-beta-0.9-2026-11-09-r38.iso" installs welcome timing > "$B/r38/run-r38.out" 2>&1
MD=$B/lfs13-logs/iso-beta-0.9/r38/matrix; mkdir -p "$MD"
env MROUND=r38 bash scripts/rebuild/r21/matrix-r21.sh apps > "$MD/run-APPS.out" 2>&1
env MROUND=r38 bash scripts/rebuild/r21/matrix-r21.sh diag B2 > "$MD/run-B2.out" 2>&1
echo "r38 done $(date +%T)"
