#!/bin/bash
# Round 41: the r40 fixes found after round 40 started: FW-DIRLINK-01 (linux-firmware-dirlinks), ALP-KUTU-01 (alp
# Debian box, apt/dnf/pacman hint, ~/.local/bin on PATH: alp-kutu-r40b, alpbahos-pm-hint-r40) and INSTALLER-UI-01 r41
# (summary strings in the future tense: calamares-r41). Rows: I1 and I2 installs with installer screenshots, the
# matrix KUTU row (also checks the gb206 firmware link) and B2. Same host sharing as r40-run.sh (gate, gap).
# Runs as the build user (nohup); sudo for the ISO build.
set -u
B=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
L=$B/lfs13-logs/iso-beta-0.9/r41
ISO=$B/images/alpbahos-beta-0.9-2026-11-09-r41.iso
cd "$WT"
mkdir -p "$B/r41" "$L"
log() { echo "[$(date +%T)] $*" | tee -a "$L/run.log"; }
qn() { pgrep -c qemu-system; }
avail() { free -g | awk '/^Mem:/ {print $7}'; }
gate() { local n=0
  until [ "$(qn)" -le "$1" ] && [ "$(avail)" -ge 9 ]; do
    [ $((n % 10)) -eq 0 ] && log "gate wait: qemu=$(qn) avail=$(avail)G"; n=$((n + 1)); sleep 30
  done; log "gate ok: qemu=$(qn) avail=$(avail)G"; }
gap() { sleep 75; }
[ -e "$B/test-secrets/r41.pw" ] || (umask 077; cp "$B/test-secrets/r21.pw" "$B/test-secrets/r41.pw")
if [ ! -s "$ISO" ]; then
    sudo ls "$B/r4-root/tmp" > "$B/r41/r4-tmp-before.txt" 2>&1
    [ -e "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r40" ] \
        || sudo mv "$B/lfs13-snapshots/r4-iso-src-2026-11-09" "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r40"
    log "ISO build (nice 10)"
    sudo nice -n 10 env TAG=r41 bash scripts/rebuild/iso/build-iso.sh > "$B/r41/build-r41.log" 2>&1 || { log "ISO build failed"; exit 1; }
    log "ISO built: $(du -h "$ISO" | cut -f1)"
fi
gate 1; log "lane1 (I1 BIOS install)"
ROUND=r41 bash scripts/rebuild/r20/r20-lanes.sh "$ISO" lane1 > "$L/lane1.log" 2>&1; gap
gate 1; log "lane2 (L1 live UEFI, I2 UEFI install)"
ROUND=r41 bash scripts/rebuild/r20/r20-lanes.sh "$ISO" lane2 > "$L/lane2.log" 2>&1; gap
MD=$L/matrix; mkdir -p "$MD"
gate 1; log "matrix KUTU"; env MROUND=r41 bash scripts/rebuild/r21/matrix-r21.sh kutu > "$MD/run-KUTU.out" 2>&1; gap
gate 1; log "matrix B2"; env MROUND=r41 bash scripts/rebuild/r21/matrix-r21.sh diag B2 > "$MD/run-B2.out" 2>&1
log "r41 done"
