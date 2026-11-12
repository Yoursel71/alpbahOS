#!/bin/bash
# Round 42: the first ISO with linux-headers, the nvidia catalogue offer (catalogue v4), alp-r42 (KUTU-LOCALE-01:
# canonical locale names for distrobox) and the installer's canonical locale list, on top of everything recorded in
# rounds 40-41 (GPU stack, netavark, plymouth fix, Debian box, hint, firmware links, installer strings).
# Order keeps one install on disk at a time where possible (host disk, handoff 041: an install is ~20 GiB; a new one
# starts only with >= 40 GiB free): lane2 (L1 live UEFI, I2 UEFI install) -> KUTU -> NVIDIA (real sandbox in the
# guest) -> lane1 (I1 BIOS install) -> Welcome, timing, KSplash -> B2. Same host sharing as r40-run.sh.
# Runs as the build user (nohup); sudo for the ISO build.
set -u
B=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
L=$B/lfs13-logs/iso-beta-0.9/r42
ISO=$B/images/alpbahos-beta-0.9-2026-11-09-r42.iso
cd "$WT"
mkdir -p "$B/r42" "$L"
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
[ -e "$B/test-secrets/r42.pw" ] || (umask 077; cp "$B/test-secrets/r21.pw" "$B/test-secrets/r42.pw")
if [ ! -s "$ISO" ]; then
    sudo ls "$B/r4-root/tmp" > "$B/r42/r4-tmp-before.txt" 2>&1
    [ -e "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r41" ] \
        || sudo mv "$B/lfs13-snapshots/r4-iso-src-2026-11-09" "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r41"
    log "ISO build (nice 10)"
    sudo nice -n 10 env TAG=r42 bash scripts/rebuild/iso/build-iso.sh > "$B/r42/build-r42.log" 2>&1 || { log "ISO build failed"; exit 1; }
    log "ISO built: $(du -h "$ISO" | cut -f1)"
fi
MD=$L/matrix; mkdir -p "$MD"
gate 1 40; log "lane2 (L1 live UEFI, I2 UEFI install)"
ROUND=r42 bash scripts/rebuild/r20/r20-lanes.sh "$ISO" lane2 > "$L/lane2.log" 2>&1; gap
gate 1 25; log "matrix KUTU"; env MROUND=r42 bash scripts/rebuild/r21/matrix-r21.sh kutu > "$MD/run-KUTU.out" 2>&1; gap
gate 1 25; log "matrix NVIDIA"; env MROUND=r42 bash scripts/rebuild/r21/matrix-r21.sh nvidia > "$MD/run-NVIDIA.out" 2>&1; gap
gate 1 40; log "lane1 (I1 BIOS install)"
ROUND=r42 bash scripts/rebuild/r20/r20-lanes.sh "$ISO" lane1 > "$L/lane1.log" 2>&1; gap
R25() { ROUND=r42 bash scripts/rebuild/r25/run-r25.sh "$ISO" "$@" >> "$B/r42/run-r42.out" 2>&1; }
gate 1; log "welcome"; R25 welcome; gap
w=0; while [ "$(qn)" -gt 0 ] && [ $w -lt 90 ]; do sleep 30; w=$((w + 1)); done
gate 1; log "timing (other QEMU at start: $(qn))"; R25 timing; gap
gate 1; log "ksplash"; R25 ksplash; gap
gate 1 25; log "matrix B2"; env MROUND=r42 bash scripts/rebuild/r21/matrix-r21.sh diag B2 > "$MD/run-B2.out" 2>&1
log "r42 done"
