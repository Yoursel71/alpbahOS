#!/bin/bash
# Round 48 full follow-up: after r48-run.sh's short matrix, run the rest of the established matrix rows against
# the r48 ISO for a comprehensive pass (not just the round-47-style regression subset): lane1 (I1 BIOS install),
# apps, apps2, kutu, nvidia, drv, fpgui, s1, r1. Waits for r48-run.sh's own "r48 done" line first so the two don't
# fight over the same ISO build step; still respects the shared QEMU/disk gate.
set -u
B=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
L=$B/lfs13-logs/iso-beta-0.9/r48
ISO=$B/images/alpbahos-beta-0.9-2026-11-09-r48.iso
cd "$WT"
log() { echo "[$(date +%T)] $*" | tee -a "$L/run-full.log"; }
qn() { pgrep -c qemu-system; }
avail() { free -g | awk '/^Mem:/ {print $7}'; }
diskfree() { df -BG --output=avail /home | tail -1 | tr -dc 0-9; }
gate() {
  local n=0
  until [ "$(qn)" -le "$1" ] && [ "$(avail)" -ge 9 ] && [ "$(diskfree)" -ge "${2:-20}" ]; do
    [ $((n % 10)) -eq 0 ] && log "gate wait: qemu=$(qn) avail=$(avail)G free=$(diskfree)G"; n=$((n + 1)); sleep 30
  done; log "gate ok: qemu=$(qn) avail=$(avail)G free=$(diskfree)G"; }
gap() { sleep 75; }
log "waiting for r48-run.sh to finish its own short matrix"
until grep -q "^\[.*\] r48 done$" "$L/run.log" 2>/dev/null; do sleep 20; done
log "r48-run.sh done, starting the full follow-up"
MD=$L/matrix
gate 1 40; log "lane1 (I1 BIOS install)"
DRIVERS_PAGE=1 ROUND=r48 bash scripts/rebuild/r20/r20-lanes.sh "$ISO" lane1 > "$L/lane1.log" 2>&1; gap
gate 1 25; log "matrix apps"; env MROUND=r48 bash scripts/rebuild/r21/matrix-r21.sh apps > "$MD/run-APPS.out" 2>&1; gap
gate 1 25; log "matrix apps2"; env MROUND=r48 bash scripts/rebuild/r21/matrix-r21.sh apps2 > "$MD/run-APPS2.out" 2>&1; gap
gate 1 25; log "matrix kutu"; env MROUND=r48 bash scripts/rebuild/r21/matrix-r21.sh kutu > "$MD/run-KUTU.out" 2>&1; gap
gate 1 25; log "matrix nvidia"; env MROUND=r48 bash scripts/rebuild/r21/matrix-r21.sh nvidia > "$MD/run-NVIDIA.out" 2>&1; gap
gate 1 25; log "matrix drv"; env MROUND=r48 bash scripts/rebuild/r21/matrix-r21.sh drv > "$MD/run-DRV.out" 2>&1; gap
gate 1 25; log "matrix fpgui"; env MROUND=r48 bash scripts/rebuild/r21/matrix-r21.sh fpgui > "$MD/run-FPGUI.out" 2>&1; gap
gate 1 25; log "matrix s1"; env MROUND=r48 bash scripts/rebuild/r21/matrix-r21.sh s1 > "$MD/run-S1.out" 2>&1; gap
gate 1 25; log "matrix r1"; env MROUND=r48 bash scripts/rebuild/r21/matrix-r21.sh r1 > "$MD/run-R1.out" 2>&1; gap
log "r48 full follow-up done"
