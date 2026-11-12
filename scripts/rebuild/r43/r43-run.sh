#!/bin/bash
# Round 43: the first ISO with APPS-02 (Kate, Okular, Gwenview, Ark, poppler, 7zip), SHELL-R4-01 (Zsh as the default
# user shell), DRIVERS-01 (the installer's "Sürücüler" page, D166; the first-boot service; SOF audio firmware) and the
# alp dry-run fix, on top of round 42. Rows: lane2 (L1, I2 with DRIVERS_PAGE=1: the lanes click through the new page)
# -> APPS2 (apps, 7z, zsh) -> DRV (first-boot driver service without an NVIDIA GPU) -> lane1 (I1) -> Welcome, timing,
# KSplash -> B2 (idle memory with the new process list). Same host sharing and disk gate as r42-run.sh.
# Runs as the build user (nohup); sudo for the ISO build.
set -u
B=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
L=$B/lfs13-logs/iso-beta-0.9/r43
ISO=$B/images/alpbahos-beta-0.9-2026-11-09-r43.iso
cd "$WT"
mkdir -p "$B/r43" "$L"
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
[ -e "$B/test-secrets/r43.pw" ] || (umask 077; cp "$B/test-secrets/r21.pw" "$B/test-secrets/r43.pw")
if [ ! -s "$ISO" ]; then
    sudo ls "$B/r4-root/tmp" > "$B/r43/r4-tmp-before.txt" 2>&1
    [ -e "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r42" ] \
        || sudo mv "$B/lfs13-snapshots/r4-iso-src-2026-11-09" "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r42"
    log "ISO build (nice 10)"
    sudo nice -n 10 env TAG=r43 bash scripts/rebuild/iso/build-iso.sh > "$B/r43/build-r43.log" 2>&1 || { log "ISO build failed"; exit 1; }
    log "ISO built: $(du -h "$ISO" | cut -f1)"
fi
MD=$L/matrix; mkdir -p "$MD"
gate 1 40; log "lane2 (L1 live UEFI, I2 UEFI install)"
DRIVERS_PAGE=1 ROUND=r43 bash scripts/rebuild/r20/r20-lanes.sh "$ISO" lane2 > "$L/lane2.log" 2>&1; gap
gate 1 25; log "matrix APPS2"; env MROUND=r43 bash scripts/rebuild/r21/matrix-r21.sh apps2 > "$MD/run-APPS2.out" 2>&1; gap
gate 1 25; log "matrix DRV"; env MROUND=r43 bash scripts/rebuild/r21/matrix-r21.sh drv > "$MD/run-DRV.out" 2>&1; gap
gate 1 40; log "lane1 (I1 BIOS install)"
DRIVERS_PAGE=1 ROUND=r43 bash scripts/rebuild/r20/r20-lanes.sh "$ISO" lane1 > "$L/lane1.log" 2>&1; gap
R25() { ROUND=r43 bash scripts/rebuild/r25/run-r25.sh "$ISO" "$@" >> "$B/r43/run-r43.out" 2>&1; }
gate 1; log "welcome"; R25 welcome; gap
w=0; while [ "$(qn)" -gt 0 ] && [ $w -lt 90 ]; do sleep 30; w=$((w + 1)); done
gate 1; log "timing (other QEMU at start: $(qn))"; R25 timing; gap
gate 1; log "ksplash"; R25 ksplash; gap
gate 1 25; log "matrix B2"; env MROUND=r43 bash scripts/rebuild/r21/matrix-r21.sh diag B2 > "$MD/run-B2.out" 2>&1
log "r43 done"
