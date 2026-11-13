#!/bin/bash
# Round 49 B2 rerun: the first B2 had no desktop session because the install used a generated password that the harness
# cannot type. Round id r49c = same r49 ISO, password file copied from r21.pw, BIOS install, then B2.
set -u
B=/home/yrslf/alpbahOS/scratch-lfs-bench; WT=/home/yrslf/alpbahOS/wt-t2-kisayol
L=$B/lfs13-logs/iso-beta-0.9/r49c; ISO=$B/images/alpbahos-beta-0.9-2026-11-09-r49.iso
cd "$WT"; mkdir -p "$L/matrix"
[ -e "$B/test-secrets/r49c.pw" ] || (umask 077; cp "$B/test-secrets/r21.pw" "$B/test-secrets/r49c.pw")
DRIVERS_PAGE=1 ROUND=r49c bash scripts/rebuild/r20/r20-lanes.sh "$ISO" lane1 > "$L/lane1.log" 2>&1
sleep 60
env MROUND=r49c bash scripts/rebuild/r21/matrix-r21.sh diag B2 > "$L/matrix/run-B2.out" 2>&1
echo "r49c done" >> "$L/run.log"
