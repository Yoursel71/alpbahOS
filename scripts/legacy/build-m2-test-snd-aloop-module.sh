#!/usr/bin/env bash
set -Eeuo pipefail
trap 'printf "FAILED line %s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR

# Build and install the Linux 6.16.1 ALSA loopback module into the authoritative
# Builder rootfs. Compilation runs as LFS (UID 1001) inside /mnt/lfs chroot;
# installation and depmod run as root inside that same chroot.

ROOTFS=/mnt/lfs
KERNEL_SRC=$ROOTFS/sources/linux-6.16.1
KERNEL_RELEASE=6.16.1-alpbahOS
MODULE_REL=kernel/sound/drivers/snd-aloop.ko
LOG_DIR=$ROOTFS/tmp/alp-logs
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
BUILD_LOG=$LOG_DIR/kernel-snd-aloop-$STAMP.log
CONFIG_BACKUP=$LOG_DIR/linux-6.16.1.config.before-snd-aloop-$STAMP
MOUNTED=()

cleanup() {
    local i
    set +e
    for ((i=${#MOUNTED[@]}-1; i>=0; i--)); do
        umount -R -- "${MOUNTED[$i]}"
    done
}
trap cleanup EXIT

[[ $EUID -eq 0 ]] || { echo 'Run as root on Builder.' >&2; exit 1; }
[[ $(hostname) == yrsk ]] || { echo 'Refusing to build outside Builder yrsk.' >&2; exit 1; }
[[ -d $ROOTFS/etc && -f $KERNEL_SRC/.config && -x $ROOTFS/bin/bash ]]
[[ -x $ROOTFS/usr/bin/make && -x $ROOTFS/usr/bin/kmod ]]
[[ $(id -u lfs) == 1001 && $(id -g lfs) == 1001 ]]
grep -qx 'CONFIG_MODULES=y' "$KERNEL_SRC/.config"
grep -qx 'CONFIG_SND_SEQUENCER=y' "$KERNEL_SRC/.config"
[[ $(cat "$KERNEL_SRC/include/config/kernel.release") == "$KERNEL_RELEASE" ]]

if ps -eo comm= | grep -Eq '^(make|ninja|cmake|chroot)$'; then
    echo 'Another build/chroot process is active; refusing to proceed.' >&2
    exit 1
fi
if [[ -s /sys/block/nbd0/pid ]]; then
    echo '/dev/nbd0 is in use; refusing to proceed.' >&2
    exit 1
fi
if findmnt -rn -o TARGET | grep -q '^/mnt/lfs/'; then
    echo 'An existing mount is present below /mnt/lfs; refusing to alter it.' >&2
    exit 1
fi

mkdir -p "$LOG_DIR"
cp -a "$KERNEL_SRC/.config" "$CONFIG_BACKUP"
chown -R lfs:lfs "$KERNEL_SRC"

mount_chroot_tree() {
    local source=$1 target=$ROOTFS$1
    mkdir -p "$target"
    if mountpoint -q "$target"; then
        echo "Unexpected pre-existing mount: $target" >&2
        exit 1
    fi
    mount --rbind "$source" "$target"
    mount --make-rslave "$target"
    MOUNTED+=("$target")
}

mount_chroot_tree /dev
mount_chroot_tree /proc
mount_chroot_tree /sys
mount_chroot_tree /run

run_lfs() {
    chroot --userspec=1001:1001 "$ROOTFS" /usr/bin/env -i \
        HOME=/home/lfs TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
        /bin/bash --login -c "$1"
}

if ! run_lfs 'cd /sources/linux-6.16.1 && scripts/config --module SND_ALOOP && make olddefconfig && grep -qx "CONFIG_SND_ALOOP=m" .config && make -j4 modules' >"$BUILD_LOG" 2>&1; then
    tail -n 80 "$BUILD_LOG" >&2
    exit 1
fi

module=$KERNEL_SRC/sound/drivers/snd-aloop.ko
[[ -s $module ]]
install -D -o 0 -g 0 -m 0644 "$module" "$ROOTFS/usr/lib/modules/$KERNEL_RELEASE/$MODULE_REL"
install -o 0 -g 0 -m 0644 "$KERNEL_SRC/.config" "$ROOTFS/boot/config-$KERNEL_RELEASE"
chroot "$ROOTFS" /sbin/depmod -a "$KERNEL_RELEASE"

grep -qx 'CONFIG_SND_ALOOP=m' "$KERNEL_SRC/.config"
grep -qx 'CONFIG_SND_ALOOP=m' "$ROOTFS/boot/config-$KERNEL_RELEASE"
chroot "$ROOTFS" /sbin/modinfo "/lib/modules/$KERNEL_RELEASE/$MODULE_REL" \
    | grep -q "^vermagic:.*$KERNEL_RELEASE"

printf 'CONFIG_BACKUP=%s\nBUILD_LOG=%s\n' "$CONFIG_BACKUP" "$BUILD_LOG"
sha256sum "$ROOTFS/sources/linux-6.16.1.tar.xz" "$KERNEL_SRC/.config" \
    "$ROOTFS/boot/config-$KERNEL_RELEASE" \
    "$ROOTFS/usr/lib/modules/$KERNEL_RELEASE/$MODULE_REL"
tail -n 20 "$BUILD_LOG"
