#!/bin/bash
# CONTEXT: chroot
# REBUILD-R2 chapter 10: kernel 7.1.8 configuration (book kernel.html, systemd variant), scripted
# instead of make menuconfig.
#
# Method: start from the Fedora 44 kernel config of the build host (7.2.7-200.fc44, the host's
# /boot/config-$(uname -r)), staged by the host step as /sources/config-fedora-7.2.7-200.fc44.
# Then: make olddefconfig for 7.1.8, forced options (below), systemd kernel options (systemd 261.2
# README, section "Kernel"), and the book's notes on PCI_MSI, IRQ_REMAP, X86_X2APIC and DRM.
# Output: /sources/kernel-7.1.8.config (copied into scripts/rebuild/ch10/ by the host step).
set -euo pipefail

FEDORA_CFG=/sources/config-fedora-7.2.7-200.fc44
FEDORA_SHA256=4c8b7e6d12f317c48701c8424dd2c1c0855ff85b1872840fe7bec7a90926adbc
KVER=7.1.8
SRC=/sources/linux-$KVER

test -f "$FEDORA_CFG"
echo "$FEDORA_SHA256  $FEDORA_CFG" | sha256sum -c -

cd /sources
rm -rf "linux-$KVER"
tar -xf "linux-$KVER.tar.xz"
cd "$SRC"
cp "$FEDORA_CFG" .config

# Forced options.
#  - LOCALVERSION: release becomes 7.1.8-alpbahos (vmlinuz-7.1.8-alpbahos).
#  - RUST: the Fedora config enables it; this tree is built with gcc only, no rustc in the chroot.
#  - Module signing: no signing key. MODULE_SIG_KEY, SYSTEM_TRUSTED_KEYS and the revocation list are empty
#    or off, and MODULE_SIG_ALL is off so modules_install does not sign. MODULE_SIG itself stays on: the
#    Fedora config enables SECURITY_LOCKDOWN_LSM, which selects MODULE_SIG (security/lockdown/Kconfig:4).
#    MODULE_SIG_FORCE stays off, so unsigned modules load.
#    (7.1.8 has no SYSTEM_REVOCATION_KEYS symbol; its name is SYSTEM_REVOCATION_LIST.)
#  - BTF: off, pahole is not in the chroot.
#  - Generic x86-64 only (D140/D146): X86_NATIVE_CPU off. This tree has no processor-family choice for
#    x86-64 (arch/x86/Kconfig.cpu: the choice is under X86_32), so the build uses the generic flags in
#    arch/x86/Makefile (-march=x86-64 -mtune=generic); checked below.
scripts/config \
    --set-str LOCALVERSION "-alpbahos" \
    --disable RUST \
    --set-str MODULE_SIG_KEY "" \
    --disable MODULE_SIG_ALL \
    --set-str SYSTEM_TRUSTED_KEYS "" \
    --disable SYSTEM_REVOCATION_LIST \
    --disable DEBUG_INFO_BTF \
    --disable DEBUG_INFO_BTF_MODULES \
    --disable X86_NATIVE_CPU

# systemd kernel options (systemd 261.2 README, "Kernel" section, required and listed items).
scripts/config \
    --enable DEVTMPFS --enable DEVTMPFS_MOUNT \
    --enable CGROUPS --enable INOTIFY_USER --enable SIGNALFD --enable TIMERFD --enable EPOLL \
    --enable UNIX --enable SYSFS --enable PROC_FS --enable FHANDLE \
    --disable SYSFS_DEPRECATED --set-str UEVENT_HELPER_PATH "" --disable FW_LOADER_USER_HELPER \
    --enable DMIID --enable DMI --enable DMI_SYSFS \
    --enable BLK_DEV_BSG --enable NET_NS --enable USER_NS --enable IPV6 --enable AUTOFS_FS \
    --enable TMPFS_XATTR --enable TMPFS_POSIX_ACL --enable EXT4_FS_POSIX_ACL --enable BTRFS_FS_POSIX_ACL \
    --enable SECCOMP --enable SECCOMP_FILTER --enable KCMP \
    --enable EFI_PARTITION

# Found in the chapter 11 boot test (2026-11-07): proc-sys-fs-binfmt_misc.mount failed with
# "unknown filesystem type 'binfmt_misc'" while CONFIG_BINFMT_MISC was a module that was not loaded.
# Built in, so the systemd binfmt automount works without a module load.
scripts/config --enable BINFMT_MISC

# Book notes on the kernel page: PCI_MSI, IRQ_REMAP and X86_X2APIC are needed for systemd features;
# DRM is listed too.
scripts/config --enable PCI_MSI --enable IRQ_REMAP --enable X86_X2APIC --enable DRM

# Root file systems and block drivers for the target. ext4 and btrfs are built in; NVMe, AHCI,
# virtio-scsi and dm-crypt are modules, covered by the initramfs (--no-hostonly, see 05-initramfs.sh).
scripts/config \
    --enable EXT4_FS --enable BTRFS_FS \
    --enable VIRTIO_BLK \
    --module NVME_CORE --module BLK_DEV_NVME \
    --module SATA_AHCI --module SCSI_VIRTIO \
    --module DM_CRYPT \
    --enable VFAT_FS

make olddefconfig

fail=0
need() {   # need "<regex>" "<label>": the regex must match a line of .config
    if ! grep -qE "$1" .config; then
        echo "CHECK FAILED: $2 (no line matching $1)"
        fail=1
    fi
}
off() {    # off "<symbol>" "<label>": the symbol is not y or m (unset lines and absent symbols both pass)
    if grep -qE "^CONFIG_$1=[ym]$" .config; then
        echo "CHECK FAILED: $2 (CONFIG_$1 is on)"
        fail=1
    fi
}
need '^CONFIG_LOCALVERSION="-alpbahos"$' 'LOCALVERSION'
off RUST 'RUST off'
need '^CONFIG_MODULE_SIG=y$' 'MODULE_SIG on (selected by SECURITY_LOCKDOWN_LSM)'
need '^# CONFIG_MODULE_SIG_ALL is not set$' 'MODULE_SIG_ALL off'
need '^# CONFIG_MODULE_SIG_FORCE is not set$' 'MODULE_SIG_FORCE off'
need '^CONFIG_MODULE_SIG_KEY=""$' 'MODULE_SIG_KEY empty'
need '^CONFIG_SYSTEM_TRUSTED_KEYS=""$' 'SYSTEM_TRUSTED_KEYS empty'
need '^# CONFIG_SYSTEM_REVOCATION_LIST is not set$' 'SYSTEM_REVOCATION_LIST off'
off DEBUG_INFO_BTF 'BTF off'
need '^# CONFIG_X86_NATIVE_CPU is not set$' 'X86_NATIVE_CPU off'
need '^CONFIG_X86_64=y$' 'X86_64 target'
# The generic tuning flags for x86-64 come from arch/x86/Makefile; a native build would change them.
grep -q -- '-march=x86-64 -mtune=generic' arch/x86/Makefile || { echo "CHECK FAILED: generic flags not found in arch/x86/Makefile"; fail=1; }
need '^CONFIG_DEVTMPFS=y$' 'systemd DEVTMPFS'
need '^CONFIG_CGROUPS=y$' 'systemd CGROUPS'
need '^CONFIG_INOTIFY_USER=y$' 'systemd INOTIFY_USER'
need '^CONFIG_SIGNALFD=y$' 'systemd SIGNALFD'
need '^CONFIG_TIMERFD=y$' 'systemd TIMERFD'
need '^CONFIG_EPOLL=y$' 'systemd EPOLL'
need '^CONFIG_UNIX=y$' 'systemd UNIX'
need '^CONFIG_FHANDLE=y$' 'systemd FHANDLE'
need '^CONFIG_TMPFS_POSIX_ACL=y$' 'systemd TMPFS_POSIX_ACL'
need '^CONFIG_SECCOMP_FILTER=y$' 'systemd SECCOMP_FILTER'
need '^CONFIG_PCI_MSI=y$' 'PCI_MSI'
need '^CONFIG_IRQ_REMAP=y$' 'IRQ_REMAP'
need '^CONFIG_X86_X2APIC=y$' 'X86_X2APIC'
need '^CONFIG_EFI_PARTITION=y$' 'EFI_PARTITION'
need '^CONFIG_BINFMT_MISC=y$' 'BINFMT_MISC'
need '^CONFIG_EXT4_FS=y$' 'EXT4_FS (built in)'
need '^CONFIG_BTRFS_FS=y$' 'BTRFS_FS (built in)'
need '^CONFIG_DM_CRYPT=m$' 'DM_CRYPT (module)'
need '^CONFIG_NVME_CORE=m$' 'NVME_CORE (module)'
need '^CONFIG_SATA_AHCI=m$' 'SATA_AHCI (module)'
need '^CONFIG_SCSI_VIRTIO=m$' 'SCSI_VIRTIO (module)'
need '^CONFIG_VIRTIO_BLK=[ym]$' 'VIRTIO_BLK'

# No CPU-specific choice from arch/x86/Kconfig.cpu may be on (names read from this tree).
cpu_on=0
for opt in $(grep -oE '^config M[A-Z0-9_]+' arch/x86/Kconfig.cpu | cut -d' ' -f2); do
    if grep -qx "CONFIG_${opt}=y" .config; then
        echo "CHECK FAILED: CPU-specific option on: CONFIG_${opt}=y"
        cpu_on=1
    fi
done
[ "$cpu_on" -eq 0 ] || fail=1

[ "$fail" -eq 0 ] || { echo "kernel config checks failed"; exit 1; }

cp .config /sources/kernel-$KVER.config
echo "kernel config: $(grep -cE '^CONFIG_[A-Z0-9_]+=[ym]' .config) options set to y or m"
echo "kernel config sha256: $(sha256sum /sources/kernel-$KVER.config | cut -c1-64)"
echo "OK 01-kernel-config"
