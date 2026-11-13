#!/bin/bash
# INSTALL-DUALBOOT-01 (round 50), host side, no QEMU: a loop disk shaped like a Windows 11 UEFI install (GPT, ESP with
# EFI/Microsoft/Boot/bootmgfw.efi, NTFS partition with Windows/System32) is probed by the os-prober of r4-root (the one that
# goes into the image, with the alpbahOS patches os-prober-dir-r30/locale-r29), then ntfsresize --info proves the NTFS
# partition can be shrunk (what Calamares "alongside" does through kpmcore). Nothing touches a real disk: only a loop device
# on a sparse file. Run as root. Output: lines "KEY: value".
set -euo pipefail
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
R=$SB/r50/probe-root   # a throwaway snapshot of r4-root: os-prober needs /var/lib/os-prober and /run/lock
IMG=$SB/r50/dualboot-probe.raw
mkdir -p "$SB/r50"; rm -f "$IMG"
[ ! -e "$R" ] || btrfs subvolume delete "$R" > /dev/null
btrfs subvolume snapshot "$SB/r4-root" "$R" > /dev/null
truncate -s 20G "$IMG"
sgdisk -o -n1:2048:+260M -t1:ef00 -n2:0:+16M -t2:0c01 -n3:0:0 -t3:0700 "$IMG" > /dev/null
LOOP=$(losetup -fP --show "$IMG")
cleanup() { umount "$R/run" "$R/sys" "$R/proc" "$R/dev" 2>/dev/null || true; btrfs subvolume delete "$R" > /dev/null 2>&1 || true; umount /tmp/dbp-esp /tmp/dbp-ntfs 2>/dev/null || true; losetup -d "$LOOP" 2>/dev/null || true; rmdir /tmp/dbp-esp /tmp/dbp-ntfs 2>/dev/null || true; }
trap cleanup EXIT
mkfs.vfat -F32 "${LOOP}p1" > /dev/null
mkfs.ntfs -Q -L Windows "${LOOP}p3" > /dev/null
mkdir -p /tmp/dbp-esp /tmp/dbp-ntfs
mount "${LOOP}p1" /tmp/dbp-esp
mkdir -p /tmp/dbp-esp/EFI/Microsoft/Boot
head -c 400000 /dev/urandom > /tmp/dbp-esp/EFI/Microsoft/Boot/bootmgfw.efi
umount /tmp/dbp-esp
mount -t ntfs3 "${LOOP}p3" /tmp/dbp-ntfs 2>/dev/null || ntfs-3g "${LOOP}p3" /tmp/dbp-ntfs
mkdir -p /tmp/dbp-ntfs/Windows/System32/config /tmp/dbp-ntfs/Users/test
head -c 3000000000 /dev/zero | tr '\0' 'x' > /tmp/dbp-ntfs/Users/test/data.bin 2>/dev/null || true
umount /tmp/dbp-ntfs
echo "disk: $(sgdisk -p "$IMG" | grep -E '^ +[0-9]' | tr -s ' ' | tr '\n' ';')"
echo "ntfsresize-info: $(ntfsresize --info -f "${LOOP}p3" 2>&1 | grep -E 'You might resize|Estimated|min size' | head -n 2 | tr '\n' ';')"
mount --bind /dev "$R/dev"; mount -t proc proc "$R/proc"; mount -t sysfs sys "$R/sys"; mount -t tmpfs tmpfs "$R/run"; mkdir -p "$R/run/lock" "$R/var/lib/os-prober"
OUT=$(chroot "$R" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin LC_ALL=C env OS_PROBER_NEWNS=1 sh -x /usr/bin/os-prober 2>&1 || true); echo "$OUT" > "$SB/r50/os-prober-trace.txt"; echo "os-prober: $(chroot "$R" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin LC_ALL=C os-prober 2>&1 | tr "\n" ";" | cut -c1-300)"
