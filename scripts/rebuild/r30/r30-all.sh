#!/bin/bash
# Round 30: build ISO r30 from r4-root (all section D/E work, os-prober with the locale and directory fixes, zram stop
# fix, alsa-utils, pipe-free initramfs checks), then every row of run-r25.sh and the beta matrix (matrix-r21.sh with
# MROUND=r30). Runs as the build user; sudo for the ISO build and loop mounts. Logs: scratch-lfs-bench/r30/.
set -u
B=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
ISO=$B/images/alpbahos-beta-0.9-2026-11-09-r30.iso
L=$B/r30
M="env MROUND=r30 bash $WT/scripts/rebuild/r21/matrix-r21.sh"
cd "$WT"
[ -e "$B/test-secrets/r30.pw" ] || (umask 077; cp "$B/test-secrets/r21.pw" "$B/test-secrets/r30.pw")
if [ ! -e "$ISO" ]; then
    sudo mv "$B/lfs13-snapshots/r4-iso-src-2026-11-09" "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r29" 2>/dev/null || true
    sudo env TAG=r30 bash scripts/rebuild/iso/build-iso.sh > "$L/build-r30.log" 2>&1 || { echo "ISO build failed"; exit 1; }
fi
ROUND=r30 bash scripts/rebuild/r25/run-r25.sh "$ISO" installs grub splash live timing welcome ksplash dualboot > "$L/run-r30.out" 2>&1
mkdir -p "$B/lfs13-logs/iso-beta-0.9/r30/matrix"
MD=$B/lfs13-logs/iso-beta-0.9/r30/matrix
$M sha > "$MD/run-sha.out" 2>&1
for d in B2 B3 U2; do $M diag $d > "$MD/run-$d.out" 2>&1; done
$M live L2 uefi tcg 300 > "$MD/run-L2.out" 2>&1
$M live L3 bios kvm 130 > "$MD/run-L3.out" 2>&1
$M live L4 bios tcg 300 > "$MD/run-L4.out" 2>&1
$M s1 > "$MD/run-S1.out" 2>&1
$M r1 > "$MD/run-R1.out" 2>&1
$M fpgui > "$MD/run-FPGUI.out" 2>&1
$M recprep bios REC1 > "$MD/run-REC1-prep.out" 2>&1 && $M reclive bios REC1 /dev/vda1 > "$MD/run-REC1.out" 2>&1 && $M recboot bios REC1 > "$MD/run-REC1-boot.out" 2>&1
$M recprep uefi REC2 > "$MD/run-REC2-prep.out" 2>&1 && $M reclive uefi REC2 /dev/vda2 > "$MD/run-REC2.out" 2>&1 && $M recboot uefi REC2 > "$MD/run-REC2-boot.out" 2>&1
echo "r30-all done $(date +%T)"
