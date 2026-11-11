#!/bin/bash
# Round 35: one ISO with everything up to the round 35 records (greeter/PAM/colours r33, layout r34, Calamares legend
# r34, wallpaper r35), every row of run-r25.sh and the matrix rows that log in at the greeter (B2, S1, R1, FP-GUI)
# plus REC2 (installer path untouched otherwise). Runs as the build user (nohup). Logs: scratch-lfs-bench/r35/.
set -u
B=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
ISO=$B/images/alpbahos-beta-0.9-2026-11-09-r35.iso
M="env MROUND=r35 bash $WT/scripts/rebuild/r21/matrix-r21.sh"
cd "$WT"
sudo mv "$B/lfs13-snapshots/r4-iso-src-2026-11-09" "$B/lfs13-snapshots/r4-iso-src-2026-11-09-prev-r34" 2>/dev/null || true
sudo env TAG=r35 bash scripts/rebuild/iso/build-iso.sh > "$B/r35/build-r35.log" 2>&1 || { echo "ISO build failed"; exit 1; }
ROUND=r35 bash scripts/rebuild/r25/run-r25.sh "$ISO" > "$B/r35/run-r35.out" 2>&1
MD=$B/lfs13-logs/iso-beta-0.9/r35/matrix; mkdir -p "$MD"
$M sha > "$MD/run-sha.out" 2>&1
$M diag B2 > "$MD/run-B2.out" 2>&1
$M s1 > "$MD/run-S1.out" 2>&1
$M r1 > "$MD/run-R1.out" 2>&1
$M fpgui > "$MD/run-FPGUI.out" 2>&1
$M recprep uefi REC2 > "$MD/run-REC2-prep.out" 2>&1 && $M reclive uefi REC2 /dev/vda2 > "$MD/run-REC2.out" 2>&1 && $M recboot uefi REC2 > "$MD/run-REC2-boot.out" 2>&1
echo "r35-all done $(date +%T)"
