#!/bin/bash
# Round 48: /etc/avahi/services fix baked into an ISO; short matrix rerun (lane2 L1+I2, APPS3, PRINT, Welcome, B2)
# to catch regressions since r47/47x. No new BLFS packages this round: a static check of r4-root found SOF
# firmware, IPU6 firmware+modules and Thunderbolt/USB4 kernel config already present (stale BACKLOG "missing"
# entries from the round-44 audit), so nothing to add there. Does not touch system-config-printer (needs a user
# decision, see handoff 044) or any real hardware/display step. Runs as the build user (nohup); sudo for the ISO
# build only.
set -u
B=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
L=$B/lfs13-logs/iso-beta-0.9/r48
ISO=$B/images/alpbahos-beta-0.9-2026-11-09-r48.iso
cd "$WT"
mkdir -p "$B/r48" "$L"
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
[ -e "$B/test-secrets/r48.pw" ] || (umask 077; cp "$B/test-secrets/r21.pw" "$B/test-secrets/r48.pw")
if [ ! -s "$ISO" ]; then
    sudo ls "$B/r4-root/tmp" > "$B/r48/r4-tmp-before.txt" 2>&1
    [ -e "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r47" ] \
        || sudo mv "$B/lfs13-snapshots/r4-iso-src-2026-11-09" "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r47"
    log "ISO build (nice 10)"
    sudo nice -n 10 env TAG=r48 bash scripts/rebuild/iso/build-iso.sh > "$B/r48/build-r48.log" 2>&1 || { log "ISO build failed"; exit 1; }
    log "ISO built: $(du -h "$ISO" | cut -f1)"
fi
MD=$L/matrix; mkdir -p "$MD"
gate 1 40; log "lane2 (L1 live UEFI, I2 UEFI install)"
DRIVERS_PAGE=1 ROUND=r48 bash scripts/rebuild/r20/r20-lanes.sh "$ISO" lane2 > "$L/lane2.log" 2>&1; gap
gate 1 25; log "matrix APPS3"; env MROUND=r48 bash scripts/rebuild/r21/matrix-r21.sh apps3 > "$MD/run-APPS3.out" 2>&1; gap
gate 1 25; log "matrix PRINT"; env MROUND=r48 bash scripts/rebuild/r21/matrix-r21.sh print > "$MD/run-PRINT.out" 2>&1; gap
R25() { ROUND=r48 bash scripts/rebuild/r25/run-r25.sh "$ISO" "$@" >> "$B/r48/run-r48.out" 2>&1; }
gate 1; log "welcome"; R25 welcome; gap
gate 1 25; log "B2"; R25 b2; gap
# sof/ipu6/thunderbolt confirmed already in r4-root (static check, see handoff 044); just record presence from the ISO tree
mkdir -p "$B/r48"
sudo bsdtar -xOf "$ISO" boot/grub/grub.cfg 2>/dev/null | grep -c 'modprobe.blacklist=nouveau' | sed 's/^/grub entries with nouveau blacklisted: /' | tee -a "$L/run.log"
log "avahi services dir check (needs a live boot, done inside lane2/matrix gsh calls if they probe it)"
log "r48 done"
