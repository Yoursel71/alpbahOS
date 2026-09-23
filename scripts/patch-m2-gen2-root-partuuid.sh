#!/usr/bin/env bash
set -Eeuo pipefail

# Fix the Gen2 test image's kernel root argument. Without an initramfs the
# kernel cannot resolve root=UUID= (a filesystem UUID); it only understands
# root=PARTUUID= (the GPT partition GUID). rootwait covers late storvsc probing.
# Only the test image is written; /mnt/lfs is never mounted or touched.
IMG=/tmp/alpbahOS-m2-ssh-gen2-test.vhdx
EXPECTED=f606aedf3e54e5235b11f87bf87ae328c94deb3b5d3a85fa3d55f197e292705f
NBD=/dev/nbd0
BACKUP=/tmp/alpbahOS-m2-gen2-before-partuuid
WORK=$(mktemp -d /tmp/alpbahos-gen2-partuuid.XXXXXX)
MOUNT=$WORK/root
ATTACHED=0
ROOT_MOUNTED=0
EFI_MOUNTED=0

cleanup() {
    set +e
    if (( EFI_MOUNTED )); then umount "$MOUNT/boot/efi"; fi
    if (( ROOT_MOUNTED )); then umount "$MOUNT"; fi
    if (( ATTACHED )); then qemu-nbd --disconnect "$NBD" >/dev/null 2>&1; fi
    rm -rf -- "$WORK"
}
trap cleanup EXIT

[[ $EUID -eq 0 ]] || { echo 'Run as root.' >&2; exit 1; }
[[ -f $IMG ]] || { echo "Missing test image: $IMG" >&2; exit 1; }
ACTUAL=$(sha256sum "$IMG" | cut -d' ' -f1)
[[ $ACTUAL == "$EXPECTED" ]] || { echo "Unexpected source image hash: $ACTUAL" >&2; exit 1; }
command -v grub-mkstandalone >/dev/null
modprobe nbd max_part=8
[[ ! -s /sys/block/nbd0/pid ]] || { echo "$NBD is already in use." >&2; exit 1; }

qemu-nbd --connect="$NBD" --format=vhdx "$IMG"
ATTACHED=1
partprobe "$NBD"
udevadm settle
[[ $(blkid -s LABEL -o value "${NBD}p2") == ALP_ROOT ]] || { echo 'Partition 2 is not ALP_ROOT.' >&2; exit 1; }
ROOT_UUID=$(blkid -s UUID -o value "${NBD}p2")
ROOT_PARTUUID=$(blkid -s PARTUUID -o value "${NBD}p2")
[[ $ROOT_PARTUUID =~ ^[0-9a-f-]{36}$ ]] || { echo "Bad PARTUUID: $ROOT_PARTUUID" >&2; exit 1; }
sgdisk -i 2 "$NBD" | grep -qi "unique GUID: $ROOT_PARTUUID" || { echo 'sgdisk disagrees with blkid.' >&2; exit 1; }

mkdir -p "$MOUNT"
mount "${NBD}p2" "$MOUNT"
ROOT_MOUNTED=1
mount "${NBD}p1" "$MOUNT/boot/efi"
EFI_MOUNTED=1

cfg="$MOUNT/boot/grub/grub.cfg"
efi="$MOUNT/boot/efi/EFI/BOOT/BOOTX64.EFI"
test -f "$cfg"
test -f "$efi"
mkdir -p "$BACKUP"
cp -a "$cfg" "$BACKUP/grub.cfg"
cp -a "$efi" "$BACKUP/BOOTX64.EFI"

grep -q "root=UUID=$ROOT_UUID " "$cfg" || { echo 'grub.cfg has no expected root=UUID= argument.' >&2; exit 1; }
sed -i "s|root=UUID=$ROOT_UUID rw|root=PARTUUID=$ROOT_PARTUUID rootwait rw|" "$cfg"
grep -q "root=PARTUUID=$ROOT_PARTUUID rootwait rw" "$cfg"

grub-mkstandalone --format=x86_64-efi --output="$WORK/BOOTX64.EFI" \
    --install-modules='part_gpt fat ext2 normal linux search search_fs_uuid configfile' \
    --modules='part_gpt fat ext2 normal linux search search_fs_uuid configfile' \
    --locales='' --fonts='' --themes='' \
    "boot/grub/grub.cfg=$cfg"
grub-file --is-x86_64-efi "$WORK/BOOTX64.EFI"
install -m 0644 "$WORK/BOOTX64.EFI" "$efi"
cat "$cfg"
sync
umount "$MOUNT/boot/efi"
EFI_MOUNTED=0
umount "$MOUNT"
ROOT_MOUNTED=0
qemu-nbd --disconnect "$NBD"
ATTACHED=0
qemu-img check "$IMG"
sha256sum "$IMG"
