#!/usr/bin/env bash
set -Eeuo pipefail
trap 'printf "FAILED line %s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR

# Enable the virtual GEM render-node driver in the authoritative LFS kernel,
# build inside the /mnt/lfs chroot, and install only after a successful build.
ROOTFS=/mnt/lfs
KERNEL_SRC=$ROOTFS/sources/linux-6.16.1
KERNEL_RELEASE=6.16.1-alpbahOS
LOG_DIR=$ROOTFS/tmp/alp-logs
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
BUILD_LOG=$LOG_DIR/kernel-6.16.1-drm-vgem-$STAMP.log
CONFIG_BACKUP=$LOG_DIR/linux-6.16.1.config.before-drm-vgem-$STAMP
BOOT_BACKUP=$LOG_DIR/linux-6.16.1-boot.before-drm-vgem-$STAMP
MOUNTED=()

cleanup() {
    local status=$? i
    trap - EXIT
    set +e
    for ((i=${#MOUNTED[@]}-1; i>=0; i--)); do
        if ! umount -R -- "${MOUNTED[$i]}"; then
            printf 'CLEANUP_FAILED unmount %s\n' "${MOUNTED[$i]}" >&2
            status=1
        fi
    done
    exit "$status"
}
trap cleanup EXIT

[[ $EUID -eq 0 ]] || { echo 'Run as root on Builder.' >&2; exit 1; }
[[ $(hostname) == yrsk ]] || { echo 'Refusing to build outside Builder yrsk.' >&2; exit 1; }
[[ -d $ROOTFS/etc && -f $KERNEL_SRC/.config && -x $ROOTFS/bin/bash ]]
[[ -x $ROOTFS/usr/bin/make && -x $ROOTFS/usr/bin/kmod ]]
[[ $(id -u lfs) == 1001 && $(id -g lfs) == 1001 ]]
[[ $(cat "$KERNEL_SRC/include/config/kernel.release") == "$KERNEL_RELEASE" ]]
[[ $(md5sum "$ROOTFS/sources/linux-6.16.1.tar.xz" | cut -d' ' -f1) == 32d45755e4b39d06e9be58f6817445ee ]]
cmp -s "$ROOTFS/boot/config-$KERNEL_RELEASE" "$KERNEL_SRC/.config"
grep -qx 'CONFIG_DRM=y' "$KERNEL_SRC/.config"
grep -qx 'CONFIG_DRM_HYPERV=y' "$KERNEL_SRC/.config"
grep -qx '# CONFIG_DRM_VGEM is not set' "$KERNEL_SRC/.config"

if pgrep -x make >/dev/null || pgrep -x ninja >/dev/null || pgrep -x chroot >/dev/null; then
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

mkdir -p "$LOG_DIR" "$BOOT_BACKUP"
cp -a "$KERNEL_SRC/.config" "$CONFIG_BACKUP"
for file in config-"$KERNEL_RELEASE" vmlinuz-"$KERNEL_RELEASE" System.map-"$KERNEL_RELEASE"; do
    cp -a "$ROOTFS/boot/$file" "$BOOT_BACKUP/$file"
done
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

if ! run_lfs 'cd /sources/linux-6.16.1 && scripts/config --enable DRM_VGEM && make olddefconfig && grep -qx "CONFIG_DRM_VGEM=y" .config && make -j2 bzImage modules' >"$BUILD_LOG" 2>&1; then
    tail -n 100 "$BUILD_LOG" >&2
    exit 1
fi

[[ -s $KERNEL_SRC/arch/x86/boot/bzImage && -s $KERNEL_SRC/System.map ]]
grep -qx 'CONFIG_DRM_VGEM=y' "$KERNEL_SRC/.config"
chroot "$ROOTFS" /usr/bin/make -C /sources/linux-6.16.1 modules_install >>"$BUILD_LOG" 2>&1
install -o 0 -g 0 -m 0644 "$KERNEL_SRC/arch/x86/boot/bzImage" "$ROOTFS/boot/vmlinuz-$KERNEL_RELEASE"
install -o 0 -g 0 -m 0644 "$KERNEL_SRC/System.map" "$ROOTFS/boot/System.map-$KERNEL_RELEASE"
install -o 0 -g 0 -m 0644 "$KERNEL_SRC/.config" "$ROOTFS/boot/config-$KERNEL_RELEASE"
chroot "$ROOTFS" /sbin/depmod -a "$KERNEL_RELEASE"

grep -qx 'CONFIG_DRM_VGEM=y' "$ROOTFS/boot/config-$KERNEL_RELEASE"
[[ $(cat "$KERNEL_SRC/include/config/kernel.release") == "$KERNEL_RELEASE" ]]
file "$ROOTFS/boot/vmlinuz-$KERNEL_RELEASE"
sha256sum "$ROOTFS/boot/vmlinuz-$KERNEL_RELEASE" \
    "$ROOTFS/boot/System.map-$KERNEL_RELEASE" \
    "$ROOTFS/boot/config-$KERNEL_RELEASE" "$BUILD_LOG"
printf 'CONFIG_BACKUP=%s\nBOOT_BACKUP=%s\nBUILD_LOG=%s\n' \
    "$CONFIG_BACKUP" "$BOOT_BACKUP" "$BUILD_LOG"
