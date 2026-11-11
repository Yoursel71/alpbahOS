#!/bin/bash
# Round 40: GRUB-OTHERS-01 on the user's real alpbahOS install (user's choice 2026-11-11: update the installed system;
# the GRUB menu should list both systems). Adds the record alpbahos-grub-efi-others-r40 to that root, then runs the
# root's own grub-mkconfig in a chroot (old grub.cfg kept as grub.cfg.before-r40) and lists the menu entries.
# Usage: update-grub-install-r40.sh <root partition> <its EFI system partition>   e.g. /dev/sda2 /dev/sda3
# Refuses anything that is not an alpbahOS root. Writes only /etc/grub.d/35_alpbahos_efi_others, the alp database and
# /boot/grub/grub.cfg of that root. Run as root on the host.
set -euo pipefail
export LC_ALL=C
DEV=$1; ESP=$2
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
M=/mnt/alpbahos-install-r40
for d in "$DEV" "$ESP"; do
    [ -b "$d" ] || { echo "not a block device: $d"; exit 2; }
    findmnt -rn -S "$d" > /dev/null && { echo "$d is mounted already"; exit 2; }
done
[ "$(lsblk -no PARTTYPE "$ESP")" = c12a7328-f81f-11d2-ba4b-00a0c93ec93b ] || { echo "$ESP is not an ESP"; exit 2; }
mkdir -p "$M"
cleanup() {
    for p in sys proc dev/pts dev boot/efi; do umount "$M/$p" 2> /dev/null || true; done
    umount "$M" 2> /dev/null || true
    rmdir "$M" 2> /dev/null || true
}
trap cleanup EXIT
mount "$DEV" "$M"
grep -qx 'ID=alpbahos' "$M/etc/os-release" || { echo "not an alpbahOS root"; exit 2; }
mount "$ESP" "$M/boot/efi"
cd "$WT"
TARGET_ROOT=$M LEDGER_DIR=$SB/r40/install-ledger-$(basename "$DEV") bash scripts/rebuild/r40/grub-efi-others-r40.sh
mount --bind /dev "$M/dev"; mount --bind /dev/pts "$M/dev/pts"; mount -t proc proc "$M/proc"; mount -t sysfs sys "$M/sys"
[ -e "$M/boot/grub/grub.cfg.before-r40" ] || cp -a "$M/boot/grub/grub.cfg" "$M/boot/grub/grub.cfg.before-r40"
chroot "$M" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LANG=C grub-mkconfig -o /boot/grub/grub.cfg
echo "== menu entries now:"
grep -E "^menuentry|^submenu" "$M/boot/grub/grub.cfg" | cut -c1-100
sync
echo "update-grub-install-r40 done $(date +%T)"
