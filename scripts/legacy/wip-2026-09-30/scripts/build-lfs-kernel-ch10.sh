#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly VERSION=6.16.1-alpbahOS
readonly HEADER_SOURCE="$LFS/sources/linux-6.16.1"
readonly ARCHIVE="$LFS/sources/linux-6.16.1.tar.xz"
readonly WORK_ROOT="$LFS/sources/linux-6.16.1-ch10-$STAMP"
readonly SOURCE="$WORK_ROOT/linux-6.16.1"
readonly TARGET_SOURCE="/sources/linux-6.16.1-ch10-$STAMP/linux-6.16.1"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="$LOG_DIR/kernel-ch10-$STAMP.log"
readonly TARGET_LOG="$TARGET_SOURCE/kernel-ch10-$STAMP.log"
readonly STATUS="$LOG_DIR/kernel-ch10-$STAMP.status"
readonly MODULES="$LFS/usr/lib/modules/$VERSION"
readonly IMAGE="$LFS/boot/vmlinuz-$VERSION"
readonly MAP="$LFS/boot/System.map-$VERSION"
readonly CONFIG="$LFS/boot/config-$VERSION"
readonly DOCS="$LFS/usr/share/doc/linux-6.16.1"
readonly USB_CONF="$LFS/etc/modprobe.d/usb.conf"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" ]] || fail 'The LFS target or HDD build directory is missing.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on ext4."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
[[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
[[ -f "$ARCHIVE" && -d "$HEADER_SOURCE" ]] || fail 'The official LFS Linux 6.16.1 source archive/tree is missing.'
[[ -f "$HEADER_SOURCE/Makefile" ]] || fail 'The existing Linux headers source tree is incomplete.'
[[ ! -e "$WORK_ROOT" ]] || fail "The isolated kernel source path already exists: $WORK_ROOT"
[[ ! -e "$IMAGE" && ! -e "$MAP" && ! -e "$CONFIG" ]] || fail 'A kernel boot file already exists; refusing to overwrite it.'
[[ ! -e "$MODULES" ]] || fail "Kernel modules already exist: $MODULES"
[[ ! -e "$DOCS" ]] || fail "Kernel documentation already exists: $DOCS"
[[ ! -e "$USB_CONF" && ! -L "$USB_CONF" ]] || fail "USB module-order config already exists: $USB_CONF"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'A make/ninja/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks"
exec 9>"$DATA/locks/lfs-build-writer.lock"
flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOG") 2>&1

record_result() {
    local result=$?
    if (( result == 0 )); then
        printf 'LFS_KERNEL_CH10_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else
        printf 'LFS_KERNEL_CH10_RESULT=FAIL exit=%s\nLOG=%s\n' "$result" "$LOG" > "$STATUS"
    fi
}
trap record_result EXIT

printf 'Building LFS Chapter 10 Linux 6.16.1 for alpbahOS.\n'
printf 'Target release: %s\nIsolated source tree: %s\nParallel jobs: 4\nStarted: %s\n\n' \
    "$VERSION" "$SOURCE" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Using the existing source archive without checksum work. No package test suite will be run. Previous kernel outputs are absent. The Chapter 5 headers source tree is preserved.\n'

sudo -n mkdir -p "$WORK_ROOT"
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -c 'tar -xJf /sources/linux-6.16.1.tar.xz -C "$1"' unpack-kernel \
    "/sources/linux-6.16.1-ch10-$STAMP"

readonly BUILD_UID="$(id -u)"
readonly BUILD_GID="$(id -g)"
sudo -n chown -R "$BUILD_UID:$BUILD_GID" "$SOURCE"

sudo -n chroot --userspec="$BUILD_UID:$BUILD_GID" "$LFS" /usr/bin/env -i \
    HOME=/tmp TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$TARGET_LOG" "$VERSION" "$TARGET_SOURCE" <<'BUILD'
set -Eeuo pipefail
build_log="$1"
version="$2"
kernel_tree="$3"
exec > >(tee "$build_log") 2>&1
cd "$kernel_tree"

printf 'LFS target compiler: '
gcc --version | sed -n '1p'
make mrproper
make defconfig

scripts/config --set-str LOCALVERSION "-alpbahOS"
scripts/config --disable LOCALVERSION_AUTO

# LFS 12.4-systemd kernel requirements.
scripts/config --disable WERROR
scripts/config --enable PSI --disable PSI_DEFAULT_DISABLED
scripts/config --disable IKHEADERS
scripts/config --enable CGROUPS --enable MEMCG --enable CGROUP_SCHED --disable RT_GROUP_SCHED
scripts/config --enable RELOCATABLE --enable RANDOMIZE_BASE
scripts/config --enable STACKPROTECTOR --enable STACKPROTECTOR_STRONG
scripts/config --enable NET --enable INET --enable IPV6
scripts/config --disable UEVENT_HELPER --enable DEVTMPFS --enable DEVTMPFS_MOUNT
scripts/config --enable FW_LOADER --disable FW_LOADER_USER_HELPER
scripts/config --enable DMIID --enable SYSFB_SIMPLEFB
scripts/config --enable DRM --enable DRM_PANIC --set-str DRM_PANIC_SCREEN kmsg
scripts/config --enable DRM_FBDEV_EMULATION --enable DRM_SIMPLEDRM --enable FRAMEBUFFER_CONSOLE
scripts/config --enable INOTIFY_USER --enable TMPFS --enable TMPFS_POSIX_ACL
scripts/config --enable PCI_MSI --enable IOMMU_SUPPORT --enable IRQ_REMAP --enable X86_X2APIC

# Bootable storage and networking in QEMU/KVM and on common x86-64 hardware.
scripts/config --enable EFI --enable EFI_STUB --enable EFI_PARTITION
scripts/config --enable EXT4_FS --enable BLK_DEV_NVME
scripts/config --enable ATA --enable SATA_AHCI --enable SCSI --enable BLK_DEV_SD
scripts/config --enable VIRTIO --enable VIRTIO_PCI --enable VIRTIO_BLK --enable SCSI_VIRTIO
scripts/config --enable VIRTIO_NET --enable VIRTIO_CONSOLE --module VIRTIO_INPUT
scripts/config --module DRM_VIRTIO_GPU

# Retain the already-tested Hyper-V display/input capabilities for legacy artifacts.
scripts/config --enable HYPERVISOR_GUEST --enable HYPERV
scripts/config --enable HYPERV_STORAGE --enable HYPERV_NET
scripts/config --module HYPERV_KEYBOARD --enable HID_HYPERV_MOUSE
scripts/config --enable DRM_HYPERV --enable DRM_VGEM

make olddefconfig
make -s syncconfig
release=$(make -s kernelrelease)
[[ "$release" == "$version" ]] || { printf 'Unexpected kernel release: %s\n' "$release" >&2; exit 1; }

require_y() {
    grep -Fxq "CONFIG_$1=y" .config || { printf 'Required kernel option is not built in: CONFIG_%s\n' "$1" >&2; exit 1; }
}
require_m() {
    grep -Fxq "CONFIG_$1=m" .config || { printf 'Required kernel module is missing: CONFIG_%s\n' "$1" >&2; exit 1; }
}
for option in PSI CGROUPS MEMCG RELOCATABLE RANDOMIZE_BASE STACKPROTECTOR_STRONG \
    NET INET IPV6 DEVTMPFS DEVTMPFS_MOUNT FW_LOADER DMIID SYSFB_SIMPLEFB DRM \
    DRM_PANIC DRM_SIMPLEDRM FRAMEBUFFER_CONSOLE INOTIFY_USER TMPFS TMPFS_POSIX_ACL \
    PCI_MSI IOMMU_SUPPORT IRQ_REMAP X86_X2APIC EFI EFI_STUB EFI_PARTITION \
    EXT4_FS BLK_DEV_NVME ATA SATA_AHCI SCSI BLK_DEV_SD VIRTIO VIRTIO_PCI VIRTIO_BLK \
    SCSI_VIRTIO VIRTIO_NET VIRTIO_CONSOLE HYPERVISOR_GUEST HYPERV HYPERV_STORAGE \
    HYPERV_NET HID_HYPERV_MOUSE DRM_HYPERV DRM_VGEM; do
    require_y "$option"
done
for option in VIRTIO_INPUT DRM_VIRTIO_GPU HYPERV_KEYBOARD; do require_m "$option"; done
grep -Fxq 'CONFIG_LOCALVERSION="-alpbahOS"' .config || {
    printf 'Kernel CONFIG_LOCALVERSION does not match the selected release.\n' >&2
    exit 1
}
grep -Fxq '# CONFIG_WERROR is not set' .config
grep -Fxq '# CONFIG_IKHEADERS is not set' .config
grep -Fxq '# CONFIG_RT_GROUP_SCHED is not set' .config
grep -Fxq 'CONFIG_DRM_PANIC_SCREEN="kmsg"' .config

printf 'KERNEL_CONFIG_RESULT=PASS\n'
printf 'Kernel configuration: release=%s, built-in root storage=ext4+virtio+NVMe+AHCI+Hyper-V\n' "$release"
make -j4
[[ -s arch/x86/boot/bzImage && -s System.map ]]
printf 'KERNEL_BUILD_RESULT=PASS\n'
BUILD

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$TARGET_LOG" "$TARGET_SOURCE" <<'INSTALL'
set -Eeuo pipefail
build_log="$1"
kernel_tree="$2"
exec > >(tee -a "$build_log") 2>&1
cd "$kernel_tree"
make modules_install
INSTALL

sudo -n install -D -o 0 -g 0 -m 0644 "$SOURCE/arch/x86/boot/bzImage" "$IMAGE"
sudo -n install -D -o 0 -g 0 -m 0644 "$SOURCE/System.map" "$MAP"
sudo -n install -D -o 0 -g 0 -m 0644 "$SOURCE/.config" "$CONFIG"
sudo -n mkdir -p "$(dirname "$DOCS")" "$DOCS" "$(dirname "$USB_CONF")"
sudo -n cp -r --no-preserve=ownership "$SOURCE/Documentation/." "$DOCS/"
sudo -n install -o 0 -g 0 -m 0644 -T /dev/stdin "$USB_CONF" <<'USB'
# Begin /etc/modprobe.d/usb.conf

install ohci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i ohci_hcd ; true
install uhci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i uhci_hcd ; true

# End /etc/modprobe.d/usb.conf
USB

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /sbin/depmod -a "$VERSION"
sudo -n chown -R 0:0 "$SOURCE"

[[ -s "$IMAGE" && -s "$MAP" && -s "$CONFIG" ]]
[[ -s "$MODULES/modules.dep" ]]
[[ -d "$DOCS" && -s "$USB_CONF" ]]
grep -Fxq 'CONFIG_LOCALVERSION="-alpbahOS"' "$CONFIG"
grep -Fxq 'CONFIG_DRM_VGEM=y' "$CONFIG"
grep -Fxq 'CONFIG_VIRTIO_BLK=y' "$CONFIG"
grep -Fxq 'CONFIG_EXT4_FS=y' "$CONFIG"
file "$IMAGE"
printf 'Installed modules: %s\n' "$(find "$MODULES" -type f -name '*.ko*' | wc -l)"
printf 'Kernel image size: %s bytes\n' "$(stat -c '%s' "$IMAGE")"
printf 'Kernel module tree size: %s\n' "$(du -sh "$MODULES" | cut -f1)"
printf 'No kernel test suite was run.\n'
printf '\nKernel source/log: %s\nBoot image: %s\nStatus: %s\nFinished: %s\n' \
    "$SOURCE" "$IMAGE" "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
