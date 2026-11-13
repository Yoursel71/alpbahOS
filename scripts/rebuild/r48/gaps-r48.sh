#!/bin/bash
# Round 48 gap rows: the rows the host session's r48-run.sh / r48-full-run.sh do not cover on the r48 ISO:
# W4 (Welcome design 4, welcome4-r47.sh), boot timing (B1D/U1D with the boot hook), KSplash, B2 (4 GiB AHCI).
# Waits for "r48 full follow-up done", then one guest at a time. Runs under its own name r48g on symlinks to the
# r48 install images so the host session's evidence directory is not touched; W4 and timing boot those images
# directly, which is why this runs last. Evidence: scratch-lfs-bench/lfs13-logs/iso-beta-0.9/r48g/.
set -u
B=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
RD=r48g; L=$B/lfs13-logs/iso-beta-0.9/$RD; MD=$L/matrix
ISO=$B/images/alpbahos-beta-0.9-2026-11-09-r48.iso
F=$B/lfs13-logs/iso-beta-0.9/r48/run-full.log
cd "$WT"; mkdir -p "$MD"
log() { echo "[$(date +%T)] $*" | tee -a "$L/run.log"; }
qn() { pgrep -c qemu-system; }
avail() { free -g | awk '/^Mem:/ {print $7}'; }
gate() { local n=0
  until [ "$(qn)" -le 0 ] && [ "$(avail)" -ge 9 ]; do
    [ $((n % 10)) -eq 0 ] && log "gate wait: qemu=$(qn) avail=$(avail)G"; n=$((n + 1)); sleep 30
  done; log "gate ok: qemu=$(qn) avail=$(avail)G load=$(cut -d' ' -f1 /proc/loadavg)"; }
gap() { sleep 60; }
log "waiting for r48-full-run.sh"
until grep -q 'r48 full follow-up done' "$F" 2>/dev/null; do sleep 60; done
for fw in bios-msdos uefi-gpt; do
  [ -e "$B/images/inst-$fw-r48.raw" ] || { log "missing inst-$fw-r48.raw, stop"; exit 1; }
  ln -sfn "inst-$fw-r48.raw" "$B/images/inst-$fw-$RD.raw"
done
[ -e "$B/test-secrets/$RD.pw" ] || (umask 077; cp "$B/test-secrets/r21.pw" "$B/test-secrets/$RD.pw")
log "ISO $(basename "$ISO") sha256 $(cut -d' ' -f1 "$ISO.sha256"); worktree $(git rev-parse --short HEAD)"
R25() { ROUND=$RD bash scripts/rebuild/r25/run-r25.sh "$ISO" "$@" >> "$L/run-r25.out" 2>&1; }
gate; log "matrix B2"; env MROUND=$RD ISO_PATH="$ISO" bash scripts/rebuild/r21/matrix-r21.sh diag B2 > "$MD/run-B2.out" 2>&1; gap
gate; log "timing"; R25 timing; gap
gate; log "ksplash"; R25 ksplash; gap
gate; log "W4 (Welcome design 4)"; ROUND=$RD bash scripts/rebuild/r47/welcome4-r47.sh > "$L/run-w4.out" 2>&1
rm -f "$B/images/inst-bios-msdos-$RD.raw" "$B/images/inst-uefi-gpt-$RD.raw"
log "r48g done"
