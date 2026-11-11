#!/bin/bash
# Round 40: fixes from the first real-PC test (BETA-01): PIXBUF-01 (gdk-pixbuf loaders), GRUB-OTHERS-01, INSTALLER-UI-01
# (calamares-r40, branding logo), PORTAL-01 (GStreamer, gst-plugins-base, xdg-desktop-portal), ALP-FLATHUB-01 (D163);
# installs, Welcome rows, timing, KSplash (run-r25.sh), the matrix APPS row (with the round 40 checks) and B2.
# Runs as the build user (nohup); sudo for the ISO build.
# Before the build: r4-root/tmp must hold no build tree (build-iso.sh empties /tmp in the live copy anyway).
set -u
B=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
cd "$WT"
mkdir -p "$B/r40"
[ -e "$B/test-secrets/r40.pw" ] || (umask 077; cp "$B/test-secrets/r21.pw" "$B/test-secrets/r40.pw")
sudo ls "$B/r4-root/tmp" > "$B/r40/r4-tmp-before.txt" 2>&1
sudo mv "$B/lfs13-snapshots/r4-iso-src-2026-11-09" "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r39" 2>/dev/null || true
sudo env TAG=r40 bash scripts/rebuild/iso/build-iso.sh > "$B/r40/build-r40.log" 2>&1 || { echo "ISO build failed"; exit 1; }
ROUND=r40 bash scripts/rebuild/r25/run-r25.sh "$B/images/alpbahos-beta-0.9-2026-11-09-r40.iso" installs welcome timing ksplash > "$B/r40/run-r40.out" 2>&1
MD=$B/lfs13-logs/iso-beta-0.9/r40/matrix; mkdir -p "$MD"
env MROUND=r40 bash scripts/rebuild/r21/matrix-r21.sh apps > "$MD/run-APPS.out" 2>&1
env MROUND=r40 bash scripts/rebuild/r21/matrix-r21.sh diag B2 > "$MD/run-B2.out" 2>&1
echo "r40 done $(date +%T)"
