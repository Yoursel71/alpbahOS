#!/bin/bash
# REBUILD-R2 image phase: install the chapter 11 tree from /mnt/lfs13 onto a sparse raw disk image.
# Layout: GPT with a 1 MiB BIOS boot partition (ef02), a 512 MiB ESP (FAT32, ef00) and an ext4 root.
# Runs on the host as root, from the Fedora build host.
#
# Safety: the only block devices this script writes are /dev/loopN devices whose backing file is $IMG.
# Every destructive command is preceded by assert_loop. Nothing touches real disks, the host /boot,
# /etc, efibootmgr or NVRAM. grub-install runs inside a chroot of the image (the LFS grub, not the host's).
#
# Usage: sudo build-image.sh [IMG]     (refuses to overwrite an existing image)
set -euo pipefail

LFS=${R3_ROOT:-/mnt/lfs13}
IMG=${1:-/home/yrslf/alpbahOS/scratch-lfs-bench/images/alpbahos-r2-ch11-2026-11-07.raw}
IMG_SIZE=20G
MNT=/mnt/r2-image
ROOTMNT=$MNT/root
ESPMNT=$ROOTMNT/boot/efi
BUILD_USER=yrslf
KVER=7.1.8-alpbahos
LOOP=

die() { echo "build-image: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run as root"
[ -d "$LFS/usr" ] || die "$LFS is not a build root"
[ ! -e "$IMG" ] || die "$IMG exists; refusing to overwrite"

assert_loop() {
    [[ "$LOOP" =~ ^/dev/loop[0-9]+$ ]] || die "bad loop device '$LOOP'"
    [ "$(losetup -n -O BACK-FILE "$LOOP" 2>/dev/null)" = "$IMG" ] || die "$LOOP is not backed by $IMG"
}

cleanup() {
    set +e
    for m in "$ROOTMNT/dev" "$ROOTMNT/proc" "$ROOTMNT/sys"; do umount "$m" 2>/dev/null; done
    umount "$ESPMNT" 2>/dev/null
    umount "$ROOTMNT" 2>/dev/null
    if [ -n "$LOOP" ] && [[ "$LOOP" =~ ^/dev/loop[0-9]+$ ]] && [ "$(losetup -n -O BACK-FILE "$LOOP" 2>/dev/null)" = "$IMG" ]; then
        sync
        losetup -d "$LOOP"
    fi
}
trap cleanup EXIT

echo "== create sparse image $IMG ($IMG_SIZE)"
mkdir -p "$(dirname "$IMG")"
truncate -s "$IMG_SIZE" "$IMG"
chown "$BUILD_USER:$BUILD_USER" "$IMG"

LOOP=$(losetup --find --show --partscan "$IMG")
assert_loop
echo "loop: $LOOP"
losetup -l | grep -F "$IMG" || die "losetup does not list $IMG"

echo "== partition $LOOP"
assert_loop
sgdisk --zap-all "$LOOP" >/dev/null
assert_loop
sgdisk -n 1:2048:+1M -t 1:ef02 -c 1:biosboot \
       -n 2:0:+512M -t 2:ef00 -c 2:esp \
       -n 3:0:0 -t 3:8300 -c 3:alpbahos-root "$LOOP"
assert_loop
partprobe "$LOOP" 2>/dev/null || true
for i in $(seq 1 50); do
    [ -b "${LOOP}p3" ] && break
    sleep 0.2
done
for p in 1 2 3; do
    [ -b "${LOOP}p$p" ] || die "missing ${LOOP}p$p"
    [ "$(lsblk -no PKNAME "${LOOP}p$p")" = "$(basename "$LOOP")" ] || die "${LOOP}p$p is not a partition of $LOOP"
done
sgdisk -p "$LOOP"

echo "== mkfs"
assert_loop
mkfs.vfat -F 32 -n ALPESP "${LOOP}p2" >/dev/null
assert_loop
mkfs.ext4 -q -F -L alpbahos-root "${LOOP}p3"
ROOT_UUID=$(blkid -s UUID -o value "${LOOP}p3")
ESP_UUID=$(blkid -s UUID -o value "${LOOP}p2")
[ -n "$ROOT_UUID" ] && [ -n "$ESP_UUID" ] || die "no UUIDs"
echo "ROOT_UUID=$ROOT_UUID"
echo "ESP_UUID=$ESP_UUID"

echo "== mount and copy $LFS"
mkdir -p "$ROOTMNT"
assert_loop
mount "${LOOP}p3" "$ROOTMNT"
rsync -aHAXx --numeric-ids \
    --exclude=/sources --exclude=/tools \
    --exclude='/proc/*' --exclude='/sys/*' --exclude='/dev/*' --exclude='/run/*' \
    --exclude='/tmp/*' --exclude=/root/isa --exclude='/var/tmp/*' \
    "$LFS/" "$ROOTMNT/"
mkdir -p "$ROOTMNT/proc" "$ROOTMNT/sys" "$ROOTMNT/dev" "$ROOTMNT/run" "$ROOTMNT/tmp" "$ESPMNT"
chmod 1777 "$ROOTMNT/tmp"
mkdir -p "$ROOTMNT/var/log/journal"

echo "== fstab"
sed -i -e "s/@ROOT_UUID@/$ROOT_UUID/" -e "s/@ESP_UUID@/$ESP_UUID/" "$ROOTMNT/etc/fstab"
grep -q "UUID=$ROOT_UUID" "$ROOTMNT/etc/fstab"
grep -q "UUID=$ESP_UUID" "$ROOTMNT/etc/fstab"
! grep -q '@' "$ROOTMNT/etc/fstab" || die "placeholder left in fstab"

echo "== grub.cfg"
cat > "$ROOTMNT/boot/grub/grub.cfg" << EOF
# Begin /boot/grub/grub.cfg
# REBUILD-R2 image phase: filled from the chapter 10 template by build-image.sh.

set default=0
set timeout=5

insmod part_gpt
insmod part_msdos
insmod ext2
insmod search_fs_uuid

search --no-floppy --fs-uuid --set=root $ROOT_UUID

menuentry "alpbahOS, Linux $KVER" {
    linux /boot/vmlinuz-$KVER root=UUID=$ROOT_UUID ro console=ttyS0,115200 console=tty0
    initrd /boot/initrd.img-7.1.8
}

# End /boot/grub/grub.cfg
EOF
test -f "$ROOTMNT/boot/vmlinuz-$KVER"
test -f "$ROOTMNT/boot/initrd.img-7.1.8"

echo "== grub-install (inside image chroot)"
assert_loop
mount "${LOOP}p2" "$ESPMNT"
mount --bind /dev "$ROOTMNT/dev"
mount -t proc proc "$ROOTMNT/proc"
mount -t sysfs sys "$ROOTMNT/sys"
assert_loop
chroot "$ROOTMNT" /usr/sbin/grub-install --target=i386-pc --boot-directory=/boot "$LOOP"
assert_loop
chroot "$ROOTMNT" /usr/sbin/grub-install --target=x86_64-efi --removable --no-nvram \
    --efi-directory=/boot/efi --boot-directory=/boot
test -f "$ROOTMNT/boot/efi/EFI/BOOT/BOOTX64.EFI"

echo "== unmount"
umount "$ROOTMNT/sys" "$ROOTMNT/proc" "$ROOTMNT/dev"
umount "$ESPMNT"
sync
umount "$ROOTMNT"
trap - EXIT
assert_loop
losetup -d "$LOOP"
echo "OK image-build ROOT_UUID=$ROOT_UUID ESP_UUID=$ESP_UUID"
