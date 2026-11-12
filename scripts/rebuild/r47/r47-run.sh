#!/bin/bash
# Round 47: nouveau-free live entries + installed blacklist (NOUVEAU-HANG-01); short matrix (lane2 L1+I2, APPS3, Welcome); writes the ISO to the user USB (approved) after sha check.
# gmmlib), iio-sensor-proxy, Turkish installer text (calamares-tr-r47), /etc/avahi/services check. Rows: lane2 (L1, I2)
# -> APPS3 (new files present) -> PRINT (now with systemsettings output and a coredump backtrace) -> lane1 (I1) ->
# Welcome -> B2. Runs as the build user (nohup); sudo for the ISO build.
set -u
B=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
L=$B/lfs13-logs/iso-beta-0.9/r47
ISO=$B/images/alpbahos-beta-0.9-2026-11-09-r47.iso
cd "$WT"
mkdir -p "$B/r47" "$L"
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
[ -e "$B/test-secrets/r47.pw" ] || (umask 077; cp "$B/test-secrets/r21.pw" "$B/test-secrets/r47.pw")
if [ ! -s "$ISO" ]; then
    sudo ls "$B/r4-root/tmp" > "$B/r47/r4-tmp-before.txt" 2>&1
    [ -e "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r46" ] \
        || sudo mv "$B/lfs13-snapshots/r4-iso-src-2026-11-09" "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r46"
    log "ISO build (nice 10)"
    sudo nice -n 10 env TAG=r47 bash scripts/rebuild/iso/build-iso.sh > "$B/r47/build-r47.log" 2>&1 || { log "ISO build failed"; exit 1; }
    log "ISO built: $(du -h "$ISO" | cut -f1)"
fi
MD=$L/matrix; mkdir -p "$MD"
gate 1 40; log "lane2 (L1 live UEFI, I2 UEFI install)"
DRIVERS_PAGE=1 ROUND=r47 bash scripts/rebuild/r20/r20-lanes.sh "$ISO" lane2 > "$L/lane2.log" 2>&1; gap
gate 1 25; log "matrix APPS3"; env MROUND=r47 bash scripts/rebuild/r21/matrix-r21.sh apps3 > "$MD/run-APPS3.out" 2>&1; gap
R25() { ROUND=r47 bash scripts/rebuild/r25/run-r25.sh "$ISO" "$@" >> "$B/r47/run-r47.out" 2>&1; }
gate 1; log "welcome"; R25 welcome; gap
# nouveau checks in the built ISO tree files
mkdir -p "$B/r47"; sudo bsdtar -xOf "$ISO" boot/grub/grub.cfg 2>/dev/null | grep -c 'modprobe.blacklist=nouveau' | sed 's/^/grub entries with nouveau blacklisted: /' | tee -a "$L/run.log"
# USB (user approved r47 -> USB 2026-11-12): only if /dev/sdc is still the removable 58.7G Cruzer Blade, not mounted
if [ "$(cat /sys/block/sdc/removable 2>/dev/null)" = 1 ] && lsblk -ndo MODEL /dev/sdc | grep -q Cruzer && ! lsblk -nro MOUNTPOINT /dev/sdc | grep -q .; then
    log "USB write"; (cd "$B/images" && sha256sum "$(basename "$ISO")" > "$(basename "$ISO").sha256")
    sudo dd if="$ISO" of=/dev/sdc bs=4M conv=fsync status=none && sync
    sudo cmp -n "$(stat -c %s "$ISO")" "$ISO" /dev/sdc && log "USB verified (cmp)" || log "USB verify FAILED"
else log "USB skipped: /dev/sdc is not the expected stick"; fi
log "r47 done"
