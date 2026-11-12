#!/bin/bash
# Round 44: PRINT-01 step 2 (Avahi, nss-mdns, CUPS with DNS-SD, cups-browsed, mDNS firewall rule D176), the Zsh fix
# (Calamares user.shell), INSTALLER-02 (new installer look; the lanes' clicks and find-button-y.py checked on the
# preview), the cleanup of target-grub-gfxmode.sh, and the Welcome design if the user picked one (WELCOME-02).
# Rows: lane2 (L1, I2) -> APPS2 (apps, 7z, zsh: the login shell must now be /bin/zsh) -> PRINT (DNS-SD printer in
# the guest: ippeveprinter found by avahi-browse/ippfind, .local name through nss-mdns, a PDF printed to it through the
# IPP Everywhere queue, KDE printer page screenshot) -> lane1 (I1; DRIVERS_CHOICE=nvidia: the NVIDIA row is picked on
# the drivers page and the disk check must find the marker; its first boot then runs the driver service, which finds
# no NVIDIA GPU) -> Welcome, timing, KSplash -> B2. Same host sharing and disk gate as r43-run.sh.
# Runs as the build user (nohup); sudo for the ISO build.
set -u
B=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
L=$B/lfs13-logs/iso-beta-0.9/r44
ISO=$B/images/alpbahos-beta-0.9-2026-11-09-r44.iso
cd "$WT"
mkdir -p "$B/r44" "$L"
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
[ -e "$B/test-secrets/r44.pw" ] || (umask 077; cp "$B/test-secrets/r21.pw" "$B/test-secrets/r44.pw")
if [ ! -s "$ISO" ]; then
    sudo ls "$B/r4-root/tmp" > "$B/r44/r4-tmp-before.txt" 2>&1
    [ -e "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r43" ] \
        || sudo mv "$B/lfs13-snapshots/r4-iso-src-2026-11-09" "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r43"
    log "ISO build (nice 10)"
    sudo nice -n 10 env TAG=r44 bash scripts/rebuild/iso/build-iso.sh > "$B/r44/build-r44.log" 2>&1 || { log "ISO build failed"; exit 1; }
    log "ISO built: $(du -h "$ISO" | cut -f1)"
fi
MD=$L/matrix; mkdir -p "$MD"
gate 1 40; log "lane2 (L1 live UEFI, I2 UEFI install)"
DRIVERS_PAGE=1 ROUND=r44 bash scripts/rebuild/r20/r20-lanes.sh "$ISO" lane2 > "$L/lane2.log" 2>&1; gap
gate 1 25; log "matrix APPS2"; env MROUND=r44 bash scripts/rebuild/r21/matrix-r21.sh apps2 > "$MD/run-APPS2.out" 2>&1; gap
gate 1 25; log "matrix PRINT"; env MROUND=r44 bash scripts/rebuild/r21/matrix-r21.sh print > "$MD/run-PRINT.out" 2>&1; gap
gate 1 40; log "lane1 (I1 BIOS install)"
DRIVERS_PAGE=1 DRIVERS_CHOICE=nvidia ROUND=r44 bash scripts/rebuild/r20/r20-lanes.sh "$ISO" lane1 > "$L/lane1.log" 2>&1; gap
R25() { ROUND=r44 bash scripts/rebuild/r25/run-r25.sh "$ISO" "$@" >> "$B/r44/run-r44.out" 2>&1; }
gate 1; log "welcome"; R25 welcome; gap
w=0; while [ "$(qn)" -gt 0 ] && [ $w -lt 90 ]; do sleep 30; w=$((w + 1)); done
gate 1; log "timing (other QEMU at start: $(qn))"; R25 timing; gap
gate 1; log "ksplash"; R25 ksplash; gap
gate 1 25; log "matrix B2"; env MROUND=r44 bash scripts/rebuild/r21/matrix-r21.sh diag B2 > "$MD/run-B2.out" 2>&1
log "r44 done"
