#!/bin/bash
# Round 34: ISO with the round 33 greeter/PAM/colour records and the layout fix (pinned apps only when installed);
# installs, Welcome rows with Meta+L lock / password unlock, B1/U1 diagnostics (greeter login at the new position),
# KSplash. Runs as the build user (nohup). Logs: scratch-lfs-bench/r34/.
set -u
B=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
cd "$WT"
sudo mv "$B/lfs13-snapshots/r4-iso-src-2026-11-09" "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r33" 2>/dev/null || true
sudo env TAG=r34 bash scripts/rebuild/iso/build-iso.sh > "$B/r34/build-r34.log" 2>&1 || { echo "ISO build failed"; exit 1; }
ROUND=r34 bash scripts/rebuild/r25/run-r25.sh "$B/images/alpbahos-beta-0.9-2026-11-09-r34.iso" installs welcome timing ksplash > "$B/r34/run-r34.out" 2>&1
echo "r34 done $(date +%T)"
