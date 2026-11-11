#!/bin/sh
# alpbahOS BETA: recovery of an INSTALLED system from the live ISO (round 7, stage 1).
# Repairs only the boot path: the initramfs is rebuilt by the installer's own script (target-initramfs.sh, run in
# the target chroot, so the same dracut options and storage drivers as the install), GRUB is reinstalled and
# grub.cfg is regenerated. Nothing else in the installed system is changed.
#
# Usage:  sudo alpbahos-recover ROOT_PART [ESP_PART]
#   ROOT_PART  the root partition of the installed system, e.g. /dev/sda1 (ext4, holds /boot)
#   ESP_PART   the EFI system partition (vfat, /boot/efi). Omitted: the one EFI System partition on the same disk
#              is used (UEFI install), none found means BIOS; "none" forces BIOS
# With no argument the candidate partitions are listed and nothing is changed.
#
# UEFI: GRUB is written to the ESP as the removable fallback (EFI/BOOT/BOOTX64.EFI) and the NVRAM boot entry is NOT
# touched (--no-nvram, same as the image build): the firmware boots the fallback path; the NVRAM stays as it is.
#
# Steps (each prints "== step"; the first failure stops the run; everything is unmounted on exit):
#   1 mount root (and ESP)   2 bind /dev /proc /sys /run (and efivars for UEFI)
#   3 initramfs via target-initramfs.sh   4 grub-install   5 grub-mkconfig   6 checks, unmount
# Idempotent: running it again repeats the same steps with the same result.
# Mount point: /mnt/alpbahos-recover. Never /mnt/lfs.
#
# TI_SCRIPT overrides the path of target-initramfs.sh (used for tests from a checkout).

set -eu

TI_SCRIPT=${TI_SCRIPT:-/usr/lib/alpbahos/target-initramfs.sh}
M=/mnt/alpbahos-recover
ROOT=${1:-}
ESP=${2:-}

say() { echo "== $*"; }
die() { echo "alpbahos-recover: $*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || die "run as root (sudo alpbahos-recover ROOT_PART [ESP_PART])"

if [ -z "$ROOT" ]; then
    echo "usage: sudo alpbahos-recover ROOT_PART [ESP_PART]"
    echo "candidate partitions (ext4 root candidates, vfat ESP candidates):"
    lsblk -o NAME,SIZE,FSTYPE,PARTLABEL,MOUNTPOINTS
    exit 2
fi
[ -b "$ROOT" ] || die "$ROOT is not a block device"
[ -z "$ESP" ] || [ "$ESP" = none ] || [ -b "$ESP" ] || die "$ESP is not a block device"
[ -r "$TI_SCRIPT" ] || die "$TI_SCRIPT not found"

DISK=/dev/$(lsblk -no PKNAME "$ROOT" | head -n 1)
[ "$DISK" != /dev/ ] || die "cannot find the parent disk of $ROOT"

# Round 31 (RECOVER-UX-01): with no ESP argument the ESP is looked up on the same disk (partition type EFI System,
# as the installer makes it for UEFI installs only). One found: UEFI install. None: BIOS install. "none" forces BIOS.
# Round 30 showed the old behaviour (no ESP argument = BIOS) failing on a UEFI disk: grub-install i386-pc on GPT.
if [ -z "$ESP" ]; then
    ESPS=$(lsblk -nrpo NAME,PARTTYPE "$DISK" | awk 'tolower($2) == "c12a7328-f81f-11d2-ba4b-00a0c93ec93b" {print $1}')
    case $(printf '%s\n' "$ESPS" | grep -c .) in
        0) ;;
        1) ESP=$ESPS; say "EFI system partition found on $DISK: $ESP (UEFI install)" ;;
        *) die "more than one EFI system partition on $DISK ($(echo $ESPS)): give the one to use as the second argument" ;;
    esac
fi
[ "$ESP" = none ] && ESP=""

# The install type: an ESP (given or found) means a UEFI install (GRUB x86_64-efi), none means BIOS.
EFI=0
[ -n "$ESP" ] && EFI=1
say "root=$ROOT esp=${ESP:-none} disk=$DISK efi=$EFI"

MOUNTED=""
cleanup() {
    for p in $MOUNTED; do
        umount "$p" 2>/dev/null || umount -l "$p" 2>/dev/null || true
    done
    sync
}
trap cleanup EXIT INT TERM

domount() { # domount TYPE SRC DEST [OPTS]
    mkdir -p "$3"
    if [ -n "${4:-}" ]; then mount "$4" "$2" "$3"; else mount -t "$1" "$2" "$3"; fi
    MOUNTED="$3 $MOUNTED"
}

say "1 mount root and ESP"
mkdir -p "$M"
domount auto "$ROOT" "$M"
[ -d "$M/boot" ] || die "$ROOT has no /boot: not an installed alpbahOS root"
ls "$M"/boot/vmlinuz-* >/dev/null 2>&1 || die "no kernel in $ROOT:/boot"
if [ -n "$ESP" ]; then
    domount auto "$ESP" "$M/boot/efi"
fi
say "root has: $(ls "$M"/boot | tr '\n' ' ')"

say "2 bind the kernel file systems"
domount auto /dev "$M/dev" --bind
domount proc proc "$M/proc"
domount sysfs sys "$M/sys"
domount tmpfs tmpfs "$M/run"

say "3 initramfs (installer script, same dracut options)"
install -m 755 "$TI_SCRIPT" "$M/tmp/alpbahos-target-initramfs.sh"
chroot "$M" /usr/bin/env PATH=/usr/sbin:/usr/bin:/sbin:/bin /bin/sh /tmp/alpbahos-target-initramfs.sh
rm -f "$M/tmp/alpbahos-target-initramfs.sh"

say "4 grub-install"
if [ "$EFI" = 1 ]; then
    chroot "$M" /usr/bin/env PATH=/usr/sbin:/usr/bin:/sbin:/bin \
        grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=alpbahOS --removable --no-nvram
else
    chroot "$M" /usr/bin/env PATH=/usr/sbin:/usr/bin:/sbin:/bin \
        grub-install --target=i386-pc --boot-directory=/boot "$DISK"
fi

say "5 grub-mkconfig"
chroot "$M" /usr/bin/env PATH=/usr/sbin:/usr/bin:/sbin:/bin grub-mkconfig -o /boot/grub/grub.cfg
[ "$(grep -c '^menuentry' "$M/boot/grub/grub.cfg")" -ge 1 ] || die "grub.cfg has no menu entry"

say "6 checks"
KVER=$(ls "$M/lib/modules" | head -n 1)
[ -s "$M/boot/initramfs-$KVER.img" ] || die "initramfs-$KVER.img missing"
grep -q "initramfs-$KVER.img" "$M/boot/grub/grub.cfg" || die "grub.cfg does not reference initramfs-$KVER.img"
say "kernel $KVER, initramfs $(stat -c %s "$M/boot/initramfs-$KVER.img") bytes, grub entries $(grep -c '^menuentry' "$M/boot/grub/grub.cfg")"
say "recovery done; unmounting; reboot the installed disk"
