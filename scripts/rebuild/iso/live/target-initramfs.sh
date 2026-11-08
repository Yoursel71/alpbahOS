#!/bin/sh
# AlpbahOS BETA: runs in the INSTALLED system (Calamares shellprocess, chroot of the target), before grubcfg and
# bootloader. Builds a generic dracut initramfs for the installed kernel, so storage drivers that are modules
# (AHCI, NVMe, ...) load before the root file system is mounted. grub-mkconfig adds it to the menu.
# The systemd initrd is omitted (same as the live image): with it the initrd systemd had no default.target
# ("Failed to isolate default target", found 2026-11-08). The shell init mounts root=PARTUUID and switches root.
# The drop-in lists the storage drivers that must be in the initramfs; the checks fail the install if one is missing.
set -eu
KVER=$(ls /lib/modules | head -n 1)
[ -n "$KVER" ] || { echo "no kernel modules directory in the target"; exit 1; }
IMG="/boot/initramfs-$KVER.img"

mkdir -p /etc/dracut.conf.d
cat > /etc/dracut.conf.d/90-alpbahos-storage.conf << 'EOF'
# AlpbahOS BETA: storage drivers in the installed initramfs (SATA, NVMe, virtio, SCSI).
add_drivers+=" ahci ata_piix nvme sd_mod sr_mod virtio_blk virtio_pci virtio_scsi "
EOF

dracut --force --no-hostonly --kver "$KVER" \
    --omit "systemd systemd-initrd dracut-systemd systemd-journald systemd-sysusers systemd-tmpfiles systemd-hwdb systemd-networkd systemd-battery-check plymouth" \
    "$IMG" "$KVER"
test -s "$IMG"

# Checks: each driver is either in the image (lsinitrd lists it) or built into the kernel (modules.builtin).
# sd_mod and virtio_blk are built-in in this kernel (found 2026-11-08: the check had failed the install on sd_mod).
LIST=$(lsinitrd "$IMG" 2>/dev/null)
BUILTIN=/lib/modules/$KVER/modules.builtin
for m in ahci nvme sd_mod virtio_blk; do
    echo "$LIST" | grep -q "/$m\.ko" || grep -q "/$m\.ko" "$BUILTIN" || { echo "initramfs lacks module $m"; exit 1; }
done
exit 0
