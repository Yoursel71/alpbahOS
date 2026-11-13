#!/bin/bash
# INSTALL-DUALBOOT-01 (round 50): a raw disk shaped like a Windows 11 UEFI install, for the dual-boot row (cmd_dualboot of matrix-r21.sh):
# GPT, 260 MiB ESP (vfat) with EFI/Microsoft/Boot/bootmgfw.efi and BCD, 16 MiB MSR, NTFS "Windows" partition with Windows/System32/config and
# about 3 GB of data. Nothing here touches a real disk (a sparse file and a loop device). Usage: make-fake-windows-disk.sh <out.raw> [size]
# Run as root.
set -euo pipefail
OUT=${1:?out.raw}; SIZE=${2:-20G}
[ ! -e "$OUT" ] || { echo "REFUSED: $OUT exists"; exit 2; }
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
ESP=$SB/r50/fw-esp; NT=$SB/r50/fw-ntfs; mkdir -p "$ESP" "$NT"
truncate -s "$SIZE" "$OUT"
sgdisk -o -n1:2048:+260M -t1:ef00 -n2:0:+16M -t2:0c01 -n3:0:0 -t3:0700 "$OUT" > /dev/null
LOOP=$(losetup -fP --show "$OUT")
cleanup() { set +e; umount "$ESP" "$NT" 2>/dev/null; losetup -d "$LOOP" 2>/dev/null; rmdir "$ESP" "$NT" 2>/dev/null; }
trap cleanup EXIT
mkfs.vfat -F32 -n SYSTEM "${LOOP}p1" > /dev/null
mkfs.ntfs -Q -L Windows "${LOOP}p3" > /dev/null
mount "${LOOP}p1" "$ESP"; mkdir -p "$ESP/EFI/Microsoft/Boot"
# os-prober (efi/20microsoft) wants BOTH bootmgfw.efi and a BCD file in EFI/Microsoft/Boot; a real Windows ESP has both
head -c 400000 /dev/urandom > "$ESP/EFI/Microsoft/Boot/bootmgfw.efi"; head -c 262144 /dev/urandom > "$ESP/EFI/Microsoft/Boot/BCD"; umount "$ESP"
mount -t ntfs3 "${LOOP}p3" "$NT" 2> /dev/null || ntfs-3g "${LOOP}p3" "$NT"
mkdir -p "$NT/Windows/System32/config" "$NT/Users/test" "$NT/Program Files"
head -c 3000000000 /dev/zero | tr '\0' 'x' > "$NT/Users/test/data.bin" 2> /dev/null || true
umount "$NT"
echo "disk: $(sgdisk -p "$OUT" | grep -E '^ +[0-9]' | tr -s ' ' | tr '\n' ';')"
echo "ntfsresize: $(ntfsresize --info -f "${LOOP}p3" 2>&1 | grep -E 'You might resize' | head -n 1)"
