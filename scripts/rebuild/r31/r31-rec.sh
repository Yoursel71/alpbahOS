#!/bin/bash
# Round 31 (RECOVER-UX-01): ISO r31 differs from r30 only in alpbahos-recover (finds the ESP itself). The installed
# images are reflink copies of the r30 installs (same product; the recovery tool runs from the live ISO). Rows: REC1
# (BIOS, root only: no ESP on the disk -> BIOS) and REC2 (UEFI, root only: the ESP is found -> UEFI), each broken,
# repaired from the live ISO and booted alone. Runs as the build user; sudo for the ISO build and loop mounts.
set -u
B=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
M="env MROUND=r31 bash $WT/scripts/rebuild/r21/matrix-r21.sh"
cd "$WT"
sudo mv "$B/lfs13-snapshots/r4-iso-src-2026-11-09" "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r30" 2>/dev/null || true
sudo env TAG=r31 bash scripts/rebuild/iso/build-iso.sh > "$B/r31/build-r31.log" 2>&1 || { echo "ISO build failed"; exit 1; }
MD=$B/lfs13-logs/iso-beta-0.9/r31/matrix; mkdir -p "$MD"
$M sha > "$MD/run-sha.out" 2>&1
$M recprep bios REC1 > "$MD/run-REC1-prep.out" 2>&1 && $M reclive bios REC1 /dev/vda1 > "$MD/run-REC1.out" 2>&1 && $M recboot bios REC1 > "$MD/run-REC1-boot.out" 2>&1
$M recprep uefi REC2 > "$MD/run-REC2-prep.out" 2>&1 && $M reclive uefi REC2 /dev/vda2 > "$MD/run-REC2.out" 2>&1 && $M recboot uefi REC2 > "$MD/run-REC2-boot.out" 2>&1
echo "r31-rec done $(date +%T)"
