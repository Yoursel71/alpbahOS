#!/bin/bash
# Round 46: the user's design 4 as the Welcome app (Main only), emoji font, VA-API driver (libva, intel-media-driver,
# gmmlib), iio-sensor-proxy, Turkish installer text (calamares-tr-r46), /etc/avahi/services check. Rows: lane2 (L1, I2)
# -> APPS3 (new files present) -> PRINT (now with systemsettings output and a coredump backtrace) -> lane1 (I1) ->
# Welcome -> B2. Runs as the build user (nohup); sudo for the ISO build.
set -u
B=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
L=$B/lfs13-logs/iso-beta-0.9/r46
ISO=$B/images/alpbahos-beta-0.9-2026-11-09-r46.iso
cd "$WT"
mkdir -p "$B/r46" "$L"
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
[ -e "$B/test-secrets/r46.pw" ] || (umask 077; cp "$B/test-secrets/r21.pw" "$B/test-secrets/r46.pw")
if [ ! -s "$ISO" ]; then
    sudo ls "$B/r4-root/tmp" > "$B/r46/r4-tmp-before.txt" 2>&1
    [ -e "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r45" ] \
        || sudo mv "$B/lfs13-snapshots/r4-iso-src-2026-11-09" "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r45"
    log "ISO build (nice 10)"
    sudo nice -n 10 env TAG=r46 bash scripts/rebuild/iso/build-iso.sh > "$B/r46/build-r46.log" 2>&1 || { log "ISO build failed"; exit 1; }
    log "ISO built: $(du -h "$ISO" | cut -f1)"
fi
MD=$L/matrix; mkdir -p "$MD"
gate 1 40; log "lane2 (L1 live UEFI, I2 UEFI install)"
DRIVERS_PAGE=1 ROUND=r46 bash scripts/rebuild/r20/r20-lanes.sh "$ISO" lane2 > "$L/lane2.log" 2>&1; gap
gate 1 25; log "matrix APPS3"; env MROUND=r46 bash scripts/rebuild/r21/matrix-r21.sh apps3 > "$MD/run-APPS3.out" 2>&1; gap
gate 1 25; log "matrix PRINT"; env MROUND=r46 bash scripts/rebuild/r21/matrix-r21.sh print > "$MD/run-PRINT.out" 2>&1; gap
gate 1 40; log "lane1 (I1 BIOS install)"
DRIVERS_PAGE=1 ROUND=r46 bash scripts/rebuild/r20/r20-lanes.sh "$ISO" lane1 > "$L/lane1.log" 2>&1; gap
R25() { ROUND=r46 bash scripts/rebuild/r25/run-r25.sh "$ISO" "$@" >> "$B/r46/run-r46.out" 2>&1; }
gate 1; log "welcome"; R25 welcome; gap
gate 1 25; log "matrix B2"; env MROUND=r46 bash scripts/rebuild/r21/matrix-r21.sh diag B2 > "$MD/run-B2.out" 2>&1
log "r46 done"
