#!/bin/sh
# alpbahOS BETA: runs in the INSTALLED system (Calamares shellprocess, chroot of the target), before grubcfg and
# bootloader. Builds a generic dracut initramfs for the installed kernel, so storage drivers that are modules
# (AHCI, NVMe, ...) load before the root file system is mounted. grub-mkconfig adds it to the menu.
# The systemd initrd is omitted (same as the live image): with it the initrd systemd had no default.target
# ("Failed to isolate default target", found 2026-11-08). The shell init mounts root=PARTUUID and switches root.
# The drop-in lists the storage drivers that must be in the initramfs; the checks fail the install if one is missing.
set -eu
KVER=$(ls /lib/modules | head -n 1)
[ -n "$KVER" ] || { echo "no kernel modules directory in the target"; exit 1; }
IMG="/boot/initramfs-$KVER.img"

# NOUVEAU-HANG-01: nouveau hangs on recent NVIDIA cards (RTX 5060 real PC); the installed system never loads it (the
# firmware framebuffer keeps the screen). The file is written before dracut so the initramfs carries it as well.
mkdir -p /etc/modprobe.d /etc/dracut.conf.d
printf '%s\n' '# alpbahOS: nouveau hangs on recent NVIDIA cards; remove this file to try it.' 'blacklist nouveau' 'options nouveau modeset=0' > /etc/modprobe.d/alpbahos-nouveau.conf
cat > /etc/dracut.conf.d/90-alpbahos-storage.conf << 'EOF'
# alpbahOS BETA: storage drivers in the installed initramfs (SATA, NVMe, virtio, SCSI).
add_drivers+=" ahci ata_piix nvme sd_mod sr_mod virtio_blk virtio_pci virtio_scsi "
EOF

# INSTALL-LUKS-01 (round 50): an encrypted install has /etc/crypttab (fstab module). The shell initramfs then needs dracut's crypt
# module and the dm_crypt driver (a no-hostonly image does not pick them by itself) and cryptsetup; the boot key file made
# by the luksbootkeyfile module is in the image through install_items of dracutlukscfg.
LUKS=0
if [ -s /etc/crypttab ] && grep -qv '^[[:space:]]*#' /etc/crypttab; then
    LUKS=1
    printf '%s\n' '# alpbahOS (INSTALL-LUKS-01): encrypted root' 'add_dracutmodules+=" crypt "' 'add_drivers+=" dm_crypt "' > /etc/dracut.conf.d/91-alpbahos-luks.conf
fi

DLOG=$(dracut --force --no-hostonly --kver "$KVER" \
    --omit "systemd systemd-initrd dracut-systemd systemd-journald systemd-sysusers systemd-tmpfiles systemd-hwdb systemd-networkd systemd-battery-check" \
    "$IMG" "$KVER" 2>&1) || { echo "$DLOG"; echo "dracut failed"; exit 1; }
echo "$DLOG"
# dracut exits 0 even when a module cannot be installed ("dracut[E]"). Round 6 (2026-11-09): a plain dracut -f in the
# chroot, without these options, printed systemd-initrd dependency errors and left an image that cannot boot.
if echo "$DLOG" | grep -q 'dracut[[]E[]]'; then echo "dracut reported module errors"; exit 1; fi
test -s "$IMG"

# Checks: each driver is either in the image (lsinitrd lists it) or built into the kernel (modules.builtin).
# sd_mod and virtio_blk are built-in in this kernel (found 2026-11-08: the check had failed the install on sd_mod).
LIST=$(lsinitrd "$IMG" 2>/dev/null)
BUILTIN=/lib/modules/$KVER/modules.builtin
for m in ahci nvme sd_mod virtio_blk; do
    # No "echo | grep -q": grep -q stops reading early and echo then prints "write error" (round 21 REC rows).
    case "$LIST" in *"/$m.ko"*) continue ;; esac
    grep -q "/$m\.ko" "$BUILTIN" || { echo "initramfs lacks module $m"; exit 1; }
done
if [ "$LUKS" = 1 ]; then
    case "$LIST" in *"/dm-crypt.ko"*|*"/dm_crypt.ko"*) ;; *) grep -q "/dm-crypt\.ko" "$BUILTIN" || { echo "initramfs lacks dm-crypt"; exit 1; } ;; esac
    case "$LIST" in *cryptsetup*) ;; *) echo "initramfs lacks cryptsetup"; exit 1 ;; esac
fi
# PLYMOUTH-01 (D160): the boot splash daemon and the alpbahOS theme are in the image (dracut module 45plymouth).
for f in usr/sbin/plymouthd usr/share/plymouth/themes/alpbahos/alpbahos.script usr/share/plymouth/themes/alpbahos/mark.png; do
    case "$LIST" in *" $f
"*|*" $f") ;; *) echo "initramfs lacks $f"; exit 1 ;; esac
done
exit 0
