#!/bin/bash
# Round 40: fixes from the first real-PC test (BETA-01): PIXBUF-01 (gdk-pixbuf loaders), GRUB-OTHERS-01, INSTALLER-UI-01
# (calamares-r40, branding logo), PORTAL-01 (GStreamer, gst-plugins-base, xdg-desktop-portal), ALP-FLATHUB-01 and
# DISTROBOX-01 (D163); installs, Welcome rows, timing, KSplash (run-r25.sh), the matrix APPS row (with the round 40
# checks) and B2. Runs as the build user (nohup); sudo for the ISO build.
# Shares the host with another session's matrix queue (r39x, at most 2 QEMU, >= 9 GiB available): the ISO build runs at
# nice 10, every VM step waits for its own gate (at most one other QEMU, >= 9 GiB available) and leaves a 75 s gap
# afterwards so the other queue's 60 s poll gets a turn. Install lanes run one after the other (one 6 GiB VM each)
# instead of in parallel. The timing step waits up to 45 min for a host without other VMs; the log says if it had one.
set -u
B=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
L=$B/lfs13-logs/iso-beta-0.9/r40
ISO=$B/images/alpbahos-beta-0.9-2026-11-09-r40.iso
cd "$WT"
mkdir -p "$B/r40" "$L"
log() { echo "[$(date +%T)] $*" | tee -a "$L/run.log"; }
qn() { pgrep -c qemu-system; }
avail() { free -g | awk '/^Mem:/ {print $7}'; }
gate() {  # gate MAXQEMU: wait (no time limit) until at most MAXQEMU QEMU run and >= 9 GiB are available
  local n=0
  until [ "$(qn)" -le "$1" ] && [ "$(avail)" -ge 9 ]; do
    [ $((n % 10)) -eq 0 ] && log "gate wait: qemu=$(qn) avail=$(avail)G"; n=$((n + 1)); sleep 30
  done
  log "gate ok: qemu=$(qn) avail=$(avail)G"
}
gap() { sleep 75; }
[ -e "$B/test-secrets/r40.pw" ] || (umask 077; cp "$B/test-secrets/r21.pw" "$B/test-secrets/r40.pw")
if [ ! -s "$ISO" ]; then
    sudo ls "$B/r4-root/tmp" > "$B/r40/r4-tmp-before.txt" 2>&1
    [ -e "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r39" ] \
        || sudo mv "$B/lfs13-snapshots/r4-iso-src-2026-11-09" "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r39"
    log "ISO build (nice 10)"
    sudo nice -n 10 env TAG=r40 bash scripts/rebuild/iso/build-iso.sh > "$B/r40/build-r40.log" 2>&1 || { log "ISO build failed"; exit 1; }
    log "ISO built: $(du -h "$ISO" | cut -f1)"
fi
R25() { ROUND=r40 bash scripts/rebuild/r25/run-r25.sh "$ISO" "$@" >> "$B/r40/run-r40.out" 2>&1; }
gate 1; log "lane1 (I1 BIOS install)"
ROUND=r40 bash scripts/rebuild/r20/r20-lanes.sh "$ISO" lane1 > "$L/lane1.log" 2>&1; gap
gate 1; log "lane2 (L1 live UEFI, I2 UEFI install)"
ROUND=r40 bash scripts/rebuild/r20/r20-lanes.sh "$ISO" lane2 > "$L/lane2.log" 2>&1; gap
gate 1; log "welcome"; R25 welcome; gap
w=0; while [ "$(qn)" -gt 0 ] && [ $w -lt 90 ]; do sleep 30; w=$((w + 1)); done
gate 1; log "timing (other QEMU at start: $(qn))"; R25 timing; gap
gate 1; log "ksplash"; R25 ksplash; gap
MD=$L/matrix; mkdir -p "$MD"
gate 1; log "matrix APPS"; env MROUND=r40 bash scripts/rebuild/r21/matrix-r21.sh apps > "$MD/run-APPS.out" 2>&1; gap
gate 1; log "matrix B2"; env MROUND=r40 bash scripts/rebuild/r21/matrix-r21.sh diag B2 > "$MD/run-B2.out" 2>&1
log "r40 done"
