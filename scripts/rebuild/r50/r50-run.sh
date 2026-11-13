#!/bin/bash
# Round 49: build the ISO from the r4-root with the r50 records (r50-root.sh), then the checks that matter for them:
# lane2 (L1 live UEFI + I2 UEFI install), PRINT-free short set, NVIDIA row with an SDDM look, B2. Runs as the build user.
set -u
B=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
L=$B/lfs13-logs/iso-beta-0.9/r50
ISO=$B/images/alpbahos-beta-0.9-2026-11-09-r50.iso
cd "$WT"; mkdir -p "$B/r50" "$L"
log() { echo "[$(date +%T)] $*" | tee -a "$L/run.log"; }
qn() { pgrep -c qemu-system; }
avail() { free -g | awk '/^Mem:/ {print $7}'; }
diskfree() { df -BG --output=avail /home | tail -1 | tr -dc 0-9; }
gate() { local n=0; until [ "$(qn)" -le "$1" ] && [ "$(avail)" -ge 9 ] && [ "$(diskfree)" -ge "${2:-20}" ]; do
    [ $((n % 10)) -eq 0 ] && log "gate wait: qemu=$(qn) avail=$(avail)G free=$(diskfree)G"; n=$((n + 1)); sleep 30; done; log "gate ok"; }
gap() { sleep 75; }
if [ ! -s "$ISO" ]; then
    [ -e "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r49" ] || sudo mv "$B/lfs13-snapshots/r4-iso-src-2026-11-09" "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r49"
    log "ISO build"; sudo nice -n 10 env TAG=r50 bash scripts/rebuild/iso/build-iso.sh > "$B/r50/build-r50.log" 2>&1 || { log "ISO build failed"; exit 1; }
    log "ISO built: $(du -h "$ISO" | cut -f1)"
fi
MD=$L/matrix; mkdir -p "$MD"
# the matrix rows type the password at the greeter: it must be the digits test password, not the generated one
[ -e "$B/test-secrets/r50.pw" ] || (umask 077; cp "$B/test-secrets/r21.pw" "$B/test-secrets/r50.pw")
gate 1 40; log "lane2"; DRIVERS_PAGE=1 ROUND=r50 bash scripts/rebuild/r20/r20-lanes.sh "$ISO" lane2 > "$L/lane2.log" 2>&1; gap
gate 1 25; log "matrix nvidia"; env MROUND=r50 bash scripts/rebuild/r21/matrix-r21.sh nvidia > "$MD/run-NVIDIA.out" 2>&1; gap
gate 1 25; log "matrix B2 (needs the BIOS install: lane1 first)"; DRIVERS_PAGE=1 ROUND=r50 bash scripts/rebuild/r20/r20-lanes.sh "$ISO" lane1 > "$L/lane1.log" 2>&1; gap
gate 1 25; env MROUND=r50 bash scripts/rebuild/r21/matrix-r21.sh diag B2 > "$MD/run-B2.out" 2>&1; gap
log "r50 done"
