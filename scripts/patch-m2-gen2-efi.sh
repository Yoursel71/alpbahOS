#!/usr/bin/env bash
set -Eeuo pipefail

# Replace only the test image's EFI application with a standalone GRUB image
# containing its menu configuration. The LFS rootfs is mounted read-only.
IMG=/tmp/alpbahOS-m2-ssh-gen2-test.vhdx
EXPECTED=0e147ad1ebd8ef740e84197cc1212a550e25f7ee33477136303ce11c777bfab7
NBD=/dev/nbd0
WORK=$(mktemp -d /tmp/alpbahos-gen2-efi.XXXXXX)
MOUNT=$WORK/root
ATTACHED=0
ROOT_MOUNTED=0
EFI_MOUNTED=0

cleanup() {
    local cleanup_ok=1
    trap - EXIT
    set +e
    if (( EFI_MOUNTED )); then umount "$MOUNT/boot/efi" || cleanup_ok=0; fi
    if (( ROOT_MOUNTED )); then umount "$MOUNT" || cleanup_ok=0; fi
    if (( ATTACHED && cleanup_ok )); then
        qemu-nbd --disconnect "$NBD" >/dev/null 2>&1 || cleanup_ok=0
    fi
    if (( ! cleanup_ok )); then
        # A failed umount leaves the guest filesystem visible under $WORK/root; never
        # detach the device or rm -rf through it. Keep everything for manual recovery.
        echo "CLEANUP FAILED: keeping $WORK; if $NBD is still attached, umount the image and run qemu-nbd --disconnect $NBD." >&2
        exit 1
    fi
    rmdir "$MOUNT" 2>/dev/null || true   # absent when the script died before mounting; must not trip the ERR trap
    rm -rf --one-file-system -- "$WORK"
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
mkdir -p "$MOUNT"
mount "${NBD}p2" "$MOUNT"
ROOT_MOUNTED=1
mount "${NBD}p1" "$MOUNT/boot/efi"
EFI_MOUNTED=1

cfg="$MOUNT/boot/grub/grub.cfg"
efi="$MOUNT/boot/efi/EFI/BOOT/BOOTX64.EFI"
test -f "$cfg"
test -f "$efi"
cp -a "$efi" /tmp/alpbahOS-m2-gen2-grub-efi-before-standalone.efi
grub-mkstandalone --format=x86_64-efi --output="$WORK/BOOTX64.EFI" \
    --install-modules='part_gpt fat ext2 normal linux search search_fs_uuid configfile' \
    --modules='part_gpt fat ext2 normal linux search search_fs_uuid configfile' \
    --locales='' --fonts='' --themes='' \
    "boot/grub/grub.cfg=$cfg"
grub-file --is-x86_64-efi "$WORK/BOOTX64.EFI"
install -m 0644 "$WORK/BOOTX64.EFI" "$efi"
sync
umount "$MOUNT/boot/efi"
EFI_MOUNTED=0
umount "$MOUNT"
ROOT_MOUNTED=0
qemu-nbd --disconnect "$NBD"
ATTACHED=0
qemu-img check "$IMG"
sha256sum "$IMG"
qemu-img info "$IMG"
