#!/bin/sh
# AlpbahOS BETA: runs in the INSTALLED system (Calamares shellprocess, chroot of the target), before grubcfg and
# bootloader. Builds a generic dracut initramfs for the installed kernel, so storage drivers that are modules
# (AHCI, NVMe, ...) load before the root file system is mounted. grub-mkconfig adds it to the menu.
# The systemd initrd is omitted (same as the live image): with it the initrd systemd had no default.target
# ("Failed to isolate default target", found 2026-11-08). The shell init mounts root=PARTUUID and switches root.
set -eu
KVER=$(ls /lib/modules | head -n 1)
[ -n "$KVER" ] || { echo "no kernel modules directory in the target"; exit 1; }
dracut --force --no-hostonly --kver "$KVER" \
    --omit "systemd systemd-initrd dracut-systemd systemd-journald systemd-sysusers systemd-tmpfiles systemd-hwdb systemd-networkd systemd-battery-check plymouth" \
    "/boot/initramfs-$KVER.img" "$KVER"
test -s "/boot/initramfs-$KVER.img"
exit 0
