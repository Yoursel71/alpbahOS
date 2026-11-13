#!/bin/bash
# Round 47f: the full VM matrix on the round 47 ISO as the beta candidate (no rebuild): lane2 (L1 live UEFI, I2 UEFI
# install) -> lane1 (I1 BIOS install, NVIDIA picked) -> APPS2 -> APPS3 -> PRINT -> DRV -> W4 (Welcome design 4) ->
# timing (B1D/U1D with the boot hook) -> KSplash -> B2. One guest at a time; the test password is the r21 copy.
# Runs as the build user (nohup). Evidence: scratch-lfs-bench/lfs13-logs/iso-beta-0.9/r47f/.
set -u
B=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
RD=r47f
L=$B/lfs13-logs/iso-beta-0.9/$RD; MD=$L/matrix
ISO=$B/images/alpbahos-beta-0.9-2026-11-09-r47.iso
cd "$WT"; mkdir -p "$MD"
log() { echo "[$(date +%T)] $*" | tee -a "$L/run.log"; }
qn() { pgrep -c qemu-system; }
avail() { free -g | awk '/^Mem:/ {print $7}'; }
diskfree() { df -BG --output=avail /home | tail -1 | tr -dc 0-9; }
gate() { local n=0
  until [ "$(qn)" -le 0 ] && [ "$(avail)" -ge 9 ] && [ "$(diskfree)" -ge "${1:-20}" ]; do
    [ $((n % 10)) -eq 0 ] && log "gate wait: qemu=$(qn) avail=$(avail)G free=$(diskfree)G"; n=$((n + 1)); sleep 30
  done; log "gate ok: qemu=$(qn) avail=$(avail)G free=$(diskfree)G load=$(cut -d' ' -f1 /proc/loadavg)"; }
gap() { sleep 60; }
[ -e "$B/test-secrets/$RD.pw" ] || (umask 077; cp "$B/test-secrets/r21.pw" "$B/test-secrets/$RD.pw")
log "candidate ISO $(basename "$ISO") sha256 $(cut -d' ' -f1 "$ISO.sha256"); worktree $(git rev-parse --short HEAD)"
M() { env MROUND=$RD ISO_PATH="$ISO" bash scripts/rebuild/r21/matrix-r21.sh "$@"; }
R25() { ROUND=$RD bash scripts/rebuild/r25/run-r25.sh "$ISO" "$@" >> "$L/run-r25.out" 2>&1; }
gate 25; log "lane2 (L1 live UEFI, I2 UEFI install)"
DRIVERS_PAGE=1 ROUND=$RD bash scripts/rebuild/r20/r20-lanes.sh "$ISO" lane2 > "$L/lane2.log" 2>&1; gap
gate 25; log "lane1 (I1 BIOS install, NVIDIA picked)"
DRIVERS_PAGE=1 DRIVERS_CHOICE=nvidia ROUND=$RD bash scripts/rebuild/r20/r20-lanes.sh "$ISO" lane1 > "$L/lane1.log" 2>&1; gap
for row in apps2 apps3 print drv; do gate 5; log "matrix $row"; M $row > "$MD/run-$row.out" 2>&1; gap; done
gate 5; log "W4 (Welcome design 4)"; ROUND=$RD bash scripts/rebuild/r47/welcome4-r47.sh > "$L/run-w4.out" 2>&1; gap
gate 5; log "timing"; R25 timing; gap
gate 5; log "ksplash"; R25 ksplash; gap
gate 5; log "matrix B2"; M diag B2 > "$MD/run-B2.out" 2>&1
log "r47f done"
