#!/bin/bash
# Round 45: PRINT-01 fixes (avahi-r45 without the BLFS race patch, so this machine sees its own DNS-SD services;
# alpbahos-cups-admin-r45, root may administer CUPS) and the Welcome app on Qt Quick's software renderer (D135).
# Rows: lane2 (L1, I2) -> PRINT (ippeveprinter found by avahi-browse/ippfind, own .local name, IPP Everywhere queue,
# a PDF printed) -> lane1 (I1) -> Welcome (software renderer looks the same) -> timing (idle memory with the screen
# lock off in the measurement copies) -> B2. APPS2 and KSplash unchanged since round 44, not repeated.
# Runs as the build user (nohup); sudo for the ISO build.
set -u
B=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
L=$B/lfs13-logs/iso-beta-0.9/r45
ISO=$B/images/alpbahos-beta-0.9-2026-11-09-r45.iso
cd "$WT"
mkdir -p "$B/r45" "$L"
log() { echo "[$(date +%T)] $*" | tee -a "$L/run.log"; }
qn() { pgrep -c qemu-system; }
avail() { free -g | awk '/^Mem:/ {print $7}'; }
diskfree() { df -BG --output=avail /home | tail -1 | tr -dc 0-9; }
gate() { # gate MAXQEMU [MIN_FREE_GIB]
  local n=0
  until [ "$(qn)" -le "$1" ] && [ "$(avail)" -ge 9 ] && [ "$(diskfree)" -ge "${2:-20}" ]; do
    [ $((n % 10)) -eq 0 ] && log "gate wait: qemu=$(qn) avail=$(avail)G free=$(diskfree)G"; n=$((n + 1)); sleep 30
  done; log "gate ok: qemu=$(qn) avail=$(avail)G free=$(diskfree)G"; }
gap() { sleep 75; }
[ -e "$B/test-secrets/r45.pw" ] || (umask 077; cp "$B/test-secrets/r21.pw" "$B/test-secrets/r45.pw")
if [ ! -s "$ISO" ]; then
    sudo ls "$B/r4-root/tmp" > "$B/r45/r4-tmp-before.txt" 2>&1
    [ -e "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r44" ] \
        || sudo mv "$B/lfs13-snapshots/r4-iso-src-2026-11-09" "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r44"
    log "ISO build (nice 10)"
    sudo nice -n 10 env TAG=r45 bash scripts/rebuild/iso/build-iso.sh > "$B/r45/build-r45.log" 2>&1 || { log "ISO build failed"; exit 1; }
    log "ISO built: $(du -h "$ISO" | cut -f1)"
fi
MD=$L/matrix; mkdir -p "$MD"
gate 1 40; log "lane2 (L1 live UEFI, I2 UEFI install)"
DRIVERS_PAGE=1 ROUND=r45 bash scripts/rebuild/r20/r20-lanes.sh "$ISO" lane2 > "$L/lane2.log" 2>&1; gap
gate 1 25; log "matrix PRINT"; env MROUND=r45 bash scripts/rebuild/r21/matrix-r21.sh print > "$MD/run-PRINT.out" 2>&1; gap
gate 1 40; log "lane1 (I1 BIOS install)"
DRIVERS_PAGE=1 ROUND=r45 bash scripts/rebuild/r20/r20-lanes.sh "$ISO" lane1 > "$L/lane1.log" 2>&1; gap
R25() { ROUND=r45 bash scripts/rebuild/r25/run-r25.sh "$ISO" "$@" >> "$B/r45/run-r45.out" 2>&1; }
gate 1; log "welcome"; R25 welcome; gap
w=0; while [ "$(qn)" -gt 0 ] && [ $w -lt 90 ]; do sleep 30; w=$((w + 1)); done
gate 1; log "timing (other QEMU at start: $(qn))"; R25 timing; gap
gate 1 25; log "matrix B2"; env MROUND=r45 bash scripts/rebuild/r21/matrix-r21.sh diag B2 > "$MD/run-B2.out" 2>&1
log "r45 done"
