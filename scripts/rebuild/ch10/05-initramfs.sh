#!/bin/bash
# CONTEXT: chroot
# REBUILD-R2 chapter 10: initramfs for 7.1.8-alpbahos -> /boot/initrd.img-7.1.8.
# Needed because the kernel is modular: the root file system, its driver and dm-crypt are modules.
# Options follow the M11 work (M09 build-parameter.txt: --no-hostonly --add ... --omit ...), with two
# changes, both for an installed system instead of the live ISO:
#   - no --no-kernel: M11 used it for the live kernel, but this kernel is modular, so the kernel modules must go
#     into the initramfs;
#   - no alplive module (the live-only pivot); the omit list keeps the systemd-specific initrd pieces out,
#     but keeps systemd-udevd and the udev rules, which create /dev/disk/by-uuid for root=UUID=.
set -euo pipefail

KVER=7.1.8-alpbahos
test -d "/lib/modules/$KVER"

# dm_crypt is added as a driver only (the module, for a later LUKS root); dracut's crypt module is not
# used, so no cryptsetup binary goes in.
dracut --force --no-hostonly --kver "$KVER" \
    --add-drivers 'dm_crypt' \
    --omit 'dracut-systemd systemd-initrd systemd-journald systemd-sysusers systemd-tmpfiles systemd-hwdb systemd-networkd systemd-battery-check' \
    "/boot/initrd.img-7.1.8"

test -s /boot/initrd.img-7.1.8

# Short content listing (the full list is in this log).
lsinitrd /boot/initrd.img-7.1.8 > /tmp/initrd-list.txt 2>&1
echo "initrd entries: $(wc -l < /tmp/initrd-list.txt)"
grep -E 'usr/bin/(udevadm|cpio)|systemd-udevd|rootfs-block|kernel/fs/ext4/ext4\.ko|dm-crypt\.ko|nvme\.ko|ahci\.ko|virtio_blk\.ko' /tmp/initrd-list.txt | head -20
rm -f /tmp/initrd-list.txt
echo "OK 05-initramfs"
