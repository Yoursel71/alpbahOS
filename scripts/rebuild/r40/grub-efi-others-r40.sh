#!/bin/bash
# Round 40 (GRUB-OTHERS-01, real-PC test 2026-11-11): the installed alpbahOS GRUB menu did not list the user's Fedora
# (on UEFI os-prober only detects Windows; Fedora's root is a btrfs subvolume). Record alpbahos-grub-efi-others-r40
# adds /etc/grub.d/35_alpbahos_efi_others (profiles/boot/grub.d/): chainload entries for the EFI boot loaders of other
# Linux systems on any EFI system partition. r40b: partition type probed with blkid -p (no udev in a chroot); r40c: a mounted ESP is read only where its st_dev is that partition. Run as root. Env TARGET_ROOT/LEDGER_DIR (apply-r7.sh) for another root.
set -euo pipefail
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
ST=$SB/r40/stage-grub-efi-others
rm -rf "$ST" && install -D -m 755 "$WT/profiles/boot/grub.d/35_alpbahos_efi_others" "$ST/etc/grub.d/35_alpbahos_efi_others"
cd "$WT"
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-grub-efi-others-r40c 0.9-r40c "$ST" \
    alpbahos-grub-efi-others-r40c 0.9-r40c
