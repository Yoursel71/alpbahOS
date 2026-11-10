#!/bin/bash
# AlpbahOS 0.9 Beta live ISO (REBUILD-R4 ISO step, 2026-11-09). Usage: sudo build-iso.sh
#
# Input: r4-root (the finished R4 root, btrfs subvolume). Output: scratch-lfs-bench/images/alpbahos-beta-0.9-<DATE>.iso
# and its .sha256. Steps:
#   1. read-only snapshot of r4-root (lfs13-snapshots/r4-iso-src-<DATE>); writable copy iso-work/live-root.
#   2. live customization of the copy: user "live" (no password, sddm autologin into the Plasma Wayland session),
#      desktop launcher and polkit rule for the installer, Calamares 3.3.14 configuration and branding, sddm
#      autologin keys, empty fstab, empty machine-id, and a TEST-ONLY profile setting (LIBGL_ALWAYS_SOFTWARE=1).
#   3. initramfs with dracut (dmsquash-live) for the kernel in r4-root, built in the copy's chroot.
#   4. squashfs (zstd, 1 MiB blocks) of the copy, excluding build trees, caches and the ISO work directory.
#   5. ISO: GRUB BIOS El Torito (i386-pc-eltorito) and UEFI El Torito (efi.img with x86_64-efi), written by xorriso.
# Every ISO tool runs in a chroot of the copy, so it comes from r4-root (dracut, squashfs-tools, libisoburn,
# grub, dosfstools, rsync). Host tools are not used to build the image. The host is written only under
# scratch-lfs-bench/ (no real disks, no host /boot, no NVRAM, no /mnt/lfs).
set -euo pipefail
export LC_ALL=C

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
LIVE_SRC=$SELF_DIR/live
M11_MOD=$SELF_DIR/../../lfs-blfs/calamares/modules   # bootloader.conf and grubcfg.conf (reviewed in M11)
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
R4=$SB/r4-root
DATE=2026-11-09
KVER=7.1.8-alpbahos
LABEL=ALPBAHOS_BETA
SNAP_SRC=$SB/lfs13-snapshots/r4-iso-src-$DATE
WORK=$SB/iso-work
LIVE=$WORK/live-root
ISOTREE=$WORK/iso
OUT_DIR=$SB/images
# DEBUG=1: diagnostic build (installer log to the serial console, rd.debug, journal to console). Own file name.
DEBUG=${DEBUG:-0}
# TAG (test variants only): file name suffix, e.g. TAG=v1. EXTRA_OVERLAY (test variants only): a directory whose
# tree is copied over the live root before the squashfs (e.g. a sddm drop-in for an experiment).
TAG=${TAG:-}
if [ "$DEBUG" = 1 ]; then OUT=$OUT_DIR/alpbahos-beta-0.9-$DATE-debug${TAG:+-$TAG}.iso; else OUT=$OUT_DIR/alpbahos-beta-0.9-$DATE${TAG:+-$TAG}.iso; fi
LOGS=$SB/lfs13-logs/iso-beta-0.9/build
MIN_FREE_GIB=30

die() { echo "build-iso: $*" >&2; exit 1; }
log() { echo "[build-iso $(date +%T)] $*"; }

[ "$(id -u)" -eq 0 ] || die "run as root"
btrfs subvolume show "$R4" > /dev/null 2>&1 || die "$R4 is not a btrfs subvolume"
if findmnt -rn -o TARGET | grep -qE "^($R4|$WORK)(/|\$)"; then die "something is mounted under $R4 or $WORK"; fi
[ ! -e "$SNAP_SRC" ] || die "$SNAP_SRC exists (delete it first)"
[ ! -e "$LIVE" ] || die "$LIVE exists (delete it first)"
[ ! -e "$OUT" ] || die "$OUT exists"
for f in "$LIVE_SRC/calamares/settings.conf" "$M11_MOD/bootloader.conf" "$M11_MOD/grubcfg.conf"; do
    [ -f "$f" ] || die "missing input $f"
done
for t in dracut mksquashfs unsquashfs xorriso grub-mkimage mkfs.vfat rsync calamares pkexec sddm efibootmgr grub-install; do
    [ -x "$R4/usr/bin/$t" ] || [ -x "$R4/usr/sbin/$t" ] || die "r4-root has no $t"
done
[ -f "$R4/boot/vmlinuz-$KVER" ] && [ -d "$R4/lib/modules/$KVER" ] || die "kernel $KVER missing in r4-root"
FREE=$(df -BG --output=avail "$SB" | tail -1 | tr -dc '0-9')
[ "$FREE" -ge "$MIN_FREE_GIB" ] || die "only ${FREE} GiB free under $SB (need $MIN_FREE_GIB)"
mkdir -p "$WORK" "$ISOTREE" "$OUT_DIR" "$LOGS"

cleanup() {
    set +e
    for m in "$LIVE/iso/efimnt" "$LIVE/iso" "$LIVE/run" "$LIVE/dev/pts" "$LIVE/dev" "$LIVE/proc" "$LIVE/sys"; do
        mountpoint -q "$m" && umount "$m"
    done
}
trap cleanup EXIT

# ------------------------------------------------------------------ 1. snapshots
log "snapshot r4-root (read-only) -> $SNAP_SRC"
btrfs subvolume snapshot -r "$R4" "$SNAP_SRC" > /dev/null
log "writable copy -> $LIVE"
btrfs subvolume snapshot "$SNAP_SRC" "$LIVE" > /dev/null

L() { chroot "$LIVE" "$@"; }

# Kernel file systems for the chroot (dracut, mksquashfs, xorriso, loop mounts for efi.img).
mkdir -p "$LIVE/dev" "$LIVE/proc" "$LIVE/sys" "$LIVE/run" "$LIVE/iso"
mount --bind /dev "$LIVE/dev"
mount -t proc proc "$LIVE/proc"
mount -t sysfs sys "$LIVE/sys"
mount -t tmpfs tmpfs "$LIVE/run"
mount --bind "$ISOTREE" "$LIVE/iso"

# ------------------------------------------------------------------ 2. live customization
log "live user, autologin, installer launcher"
if ! L /usr/bin/id live > /dev/null 2>&1; then
    L /usr/sbin/useradd -m -u 1000 -G wheel,audio,video,input -s /bin/bash live
fi
# Live user: NO password (passwd -d). Login is by sddm autologin only; /etc/pam.d/sddm-autologin allows that
# stack for the live user on the live medium (rd.live.image on the kernel line, session-r5fix record). pam_unix
# refuses empty passwords (no nullok), so the greeter cannot log the live user in. Removed from the installed
# system with the user (target-cleanup.sh).
if [ "$DEBUG" = 1 ]; then
    # DEBUG build only (test image, named -debug): the live user gets the password live, so the serial console
    # login of the session test works. The release build has no password.
    printf "live:live
" | L /usr/sbin/chpasswd
else
    L /usr/bin/passwd -d live > /dev/null
fi
# Root: locked (no login by password in the live or the installed system unless the installer sets one).
L /usr/sbin/usermod -L root
install -d -m 755 "$LIVE/home/live/Desktop"
install -m 755 "$LIVE_SRC/alpbahos-install.desktop" "$LIVE/home/live/Desktop/alpbahos-install.desktop"
install -m 755 "$LIVE_SRC/alpbahos-keyboard.desktop" "$LIVE/home/live/Desktop/alpbahos-keyboard.desktop"
install -m 755 "$LIVE_SRC/alpbahos-keyboard-check.desktop" "$LIVE/home/live/Desktop/alpbahos-keyboard-check.desktop"
L /usr/bin/chown -R live:live /home/live
install -m 755 "$LIVE_SRC/alpbahos-install" "$LIVE/usr/bin/alpbahos-install"
install -d -m 755 "$LIVE/etc/polkit-1/rules.d"
install -m 644 "$LIVE_SRC/polkit-49-alpbahos-live.rules" "$LIVE/etc/polkit-1/rules.d/49-alpbahos-live.rules"
# LIBGL_ALWAYS_SOFTWARE=1 only with LIBGL=1 (test setting for QEMU without virgl; the default build has none).
if [ "${LIBGL:-0}" = 1 ]; then
    install -m 644 "$LIVE_SRC/99-alpbahos-live.sh" "$LIVE/etc/profile.d/99-alpbahos-live.sh"
    echo "LIBGL build: LIBGL_ALWAYS_SOFTWARE=1 in the live image" >&2
fi
install -d -m 755 "$LIVE/usr/lib/alpbahos"
install -m 755 "$LIVE_SRC/target-cleanup.sh" "$LIVE/usr/lib/alpbahos/target-cleanup.sh"
install -m 755 "$LIVE_SRC/target-initramfs.sh" "$LIVE/usr/lib/alpbahos/target-initramfs.sh"
install -m 755 "$LIVE_SRC/live-layout-copy.sh" "$LIVE/usr/lib/alpbahos/live-layout-copy.sh"
# Recovery of an installed system (round 7): alpbahos-recover runs target-initramfs.sh and grub-install from the live
# image; see docs/verification/iso-beta-0.9-2026-11-09.md section 11.
install -d -m 755 "$LIVE/usr/local/sbin"
install -m 755 "$LIVE_SRC/alpbahos-recover.sh" "$LIVE/usr/local/sbin/alpbahos-recover"
if [ "$DEBUG" = 1 ]; then
    : > "$LIVE/etc/alpbahos-live-debug"
    echo "DEBUG build: installer log to serial, rd.debug" >&2
fi

log "Calamares configuration and branding"
install -d -m 755 "$LIVE/etc/calamares/modules" "$LIVE/usr/share/calamares/branding/alpbahos"
install -m 644 "$LIVE_SRC/calamares/settings.conf" "$LIVE/etc/calamares/settings.conf"
for f in "$LIVE_SRC"/calamares/modules/*.conf; do install -m 644 "$f" "$LIVE/etc/calamares/modules/"; done
install -m 644 "$M11_MOD/bootloader.conf" "$M11_MOD/grubcfg.conf" "$LIVE/etc/calamares/modules/"
install -m 644 "$LIVE_SRC/calamares/branding/branding.desc" "$LIVE/usr/share/calamares/branding/alpbahos/"
install -m 644 "$LIVE_SRC/calamares/branding/show.qml" "$LIVE/usr/share/calamares/branding/alpbahos/"
# The Calamares logo is the real brand logo (round 9): a transparent PNG made from docs/assets/alpbahOS-logo.png by
# scripts/rebuild/r9/brand-logo-r9.py (same keying as the brand wallpaper). The placeholder generator is gone.
install -m 644 "$LIVE_SRC/calamares/branding/logo.png" "$LIVE/usr/share/calamares/branding/alpbahos/logo.png"
[ -s "$LIVE/usr/share/calamares/branding/alpbahos/logo.png" ] || die "logo not written"
if [ "$DEBUG" != 1 ]; then grep -q '^live::' "$LIVE/etc/shadow" || die "live user has a password (expected empty)"; fi
grep -q '^root:[!*]' "$LIVE/etc/shadow" || die "root is not locked"
grep -qx 'PRETTY_NAME="AlpbahOS 0.9 Beta"' "$LIVE/etc/os-release" || die "os-release is not AlpbahOS 0.9 Beta"

log "sddm autologin (live only), empty fstab and machine-id"
sed -i '/^\[Autologin\]/,/^\[/{s/^User=.*/User=live/;s/^Session=.*/Session=plasma.desktop/;s/^Relogin=.*/Relogin=false/}' "$LIVE/etc/sddm.conf"
sed -n '/^\[Autologin\]/,/^\[/p' "$LIVE/etc/sddm.conf" | grep -qx 'User=live' || die "autologin User not set"
sed -n '/^\[Autologin\]/,/^\[/p' "$LIVE/etc/sddm.conf" | grep -qx 'Session=plasma.desktop' || die "autologin Session not set"
printf '# AlpbahOS BETA live image: the installer writes /etc/fstab of the installed system.\n' > "$LIVE/etc/fstab"
: > "$LIVE/etc/machine-id"

# ------------------------------------------------------------------ 3. initramfs (dracut, dmsquash-live)
log "dracut initramfs (dmsquash-live) for $KVER"
L /usr/bin/dracut --force --no-hostonly --kver "$KVER" \
    --add dmsquash-live \
    --omit "systemd systemd-initrd dracut-systemd systemd-journald systemd-sysusers systemd-tmpfiles systemd-hwdb systemd-networkd systemd-battery-check plymouth" \
    --add-drivers "squashfs overlay loop iso9660 sr_mod sd_mod ahci ata_piix virtio_blk virtio_pci virtio_scsi nvme" \
    /boot/initramfs-live.img "$KVER" > "$LOGS/10-dracut.log" 2>&1 || die "dracut failed (log $LOGS/10-dracut.log)"
[ -s "$LIVE/boot/initramfs-live.img" ] || die "no initramfs"

if [ -n "${EXTRA_OVERLAY:-}" ]; then
    [ -d "$EXTRA_OVERLAY" ] || die "EXTRA_OVERLAY is not a directory: $EXTRA_OVERLAY"
    cp -a "$EXTRA_OVERLAY"/. "$LIVE"/
    echo "EXTRA_OVERLAY applied (test variant): $EXTRA_OVERLAY" >&2
fi

# ------------------------------------------------------------------ 4. ISO tree and squashfs
log "ISO tree and squashfs"
install -d -m 755 "$ISOTREE/tree/boot/grub/i386-pc" "$ISOTREE/tree/boot/grub/x86_64-efi" "$ISOTREE/tree/LiveOS"
mv "$LIVE/boot/initramfs-live.img" "$ISOTREE/tree/boot/initramfs-live.img"
cp "$LIVE/boot/vmlinuz-$KVER" "$ISOTREE/tree/boot/vmlinuz"
rm -rf "$LIVE/var/cache/"* "$LIVE/var/tmp/"* "$LIVE/tmp/"* 2>/dev/null || true
find "$LIVE/root" "$LIVE/home" -name .bash_history -delete 2>/dev/null || true

cat > "$ISOTREE/excludes.txt" << 'EOF'
dev
proc
sys
run
tmp
mnt
media
iso
sources
tools
blfs-work
root/m11-runner
usr/lib/live
var/cache/*
var/tmp/*
lost+found
test-secrets
*/test-secrets
*/*/test-secrets
home/*/.bash_history
root/.bash_history
EOF
cat > "$ISOTREE/pseudo.txt" << 'EOF'
tmp d 1777 0 0
root d 0750 0 0
dev d 0755 0 0
proc d 0755 0 0
sys d 0755 0 0
run d 0755 0 0
mnt d 0755 0 0
media d 0755 0 0
EOF
L /usr/bin/mksquashfs / /iso/tree/LiveOS/squashfs.img -comp zstd -Xcompression-level 15 -b 1M -noappend \
    -no-progress -wildcards -ef /iso/excludes.txt -pf /iso/pseudo.txt \
    -xattrs-exclude '^security\.selinux$' > "$LOGS/20-mksquashfs.log" 2>&1 || die "mksquashfs failed (log $LOGS/20-mksquashfs.log)"
L /usr/bin/unsquashfs -ll /iso/tree/LiveOS/squashfs.img > "$ISOTREE/squashfs-ll.txt" 2>/dev/null || die "unsquashfs -ll failed"
LL=$ISOTREE/squashfs-ll.txt
check_path() { awk -v p="squashfs-root/$1" '$NF == p {f=1} END {exit !f}' "$LL" || die "squashfs lacks /$1"; }
check_absent() { if awk -v p="squashfs-root/$1" '$NF == p || index($NF, p "/") == 1 {f=1} END {exit !f}' "$LL"; then die "squashfs still has /$1"; fi; }
for p in usr/bin/calamares usr/bin/alpbahos-install usr/local/sbin/alpbahos-recover usr/lib/alpbahos/target-initramfs.sh etc/calamares/settings.conf etc/polkit-1/rules.d/49-alpbahos-live.rules \
         home/live/Desktop/alpbahos-install.desktop usr/share/calamares/branding/alpbahos/branding.desc boot/vmlinuz-$KVER; do
    check_path "$p"
done
for p in sources tools iso blfs-work; do check_absent "$p"; done
awk '$NF=="squashfs-root/tmp" {print $1}' "$LL" | grep -qx 'drwxrwxrwt' || die "squashfs /tmp mode"
awk '$NF=="squashfs-root/root" {print $1}' "$LL" | grep -qx 'drwxr-x---' || die "squashfs /root mode"
log "squashfs OK ($(wc -l < "$LL") entries)"

# ------------------------------------------------------------------ 5. GRUB images (BIOS and UEFI)
log "GRUB modules and images"
if [ "$DEBUG" = 1 ]; then
    sed 's/ console=tty0 / rd.debug systemd.journald.forward_to_console=1 console=tty0 /' "$LIVE_SRC/grub-iso.cfg" > "$ISOTREE/tree/boot/grub/grub.cfg"
    grep -q 'rd.debug' "$ISOTREE/tree/boot/grub/grub.cfg" || die "debug arguments not added to grub.cfg"
else
    install -m 644 "$LIVE_SRC/grub-iso.cfg" "$ISOTREE/tree/boot/grub/grub.cfg"
fi
# EXTRA_KARGS (test variants only): extra kernel arguments on the live kernel line.
if [ -n "${EXTRA_KARGS:-}" ]; then
    sed -i "s|^\(    linux /boot/vmlinuz .*\)$|\1 ${EXTRA_KARGS}|" "$ISOTREE/tree/boot/grub/grub.cfg"
    grep -q "${EXTRA_KARGS}" "$ISOTREE/tree/boot/grub/grub.cfg" || die "EXTRA_KARGS not applied"
    echo "EXTRA_KARGS applied (test variant): ${EXTRA_KARGS}" >&2
fi
install -m 644 "$LIVE_SRC/grub-embed.cfg" "$ISOTREE/grub-embed.cfg"
find "$R4/usr/lib/grub/i386-pc" -maxdepth 1 \( -name '*.mod' -o -name '*.lst' \) -exec cp {} "$ISOTREE/tree/boot/grub/i386-pc/" \;
find "$R4/usr/lib/grub/x86_64-efi" -maxdepth 1 \( -name '*.mod' -o -name '*.lst' \) -exec cp {} "$ISOTREE/tree/boot/grub/x86_64-efi/" \;
L grub-mkimage -O i386-pc-eltorito -o /iso/tree/boot/grub/i386-pc/eltorito.img -p /boot/grub -c /iso/grub-embed.cfg \
    biosdisk iso9660 part_msdos part_gpt search search_label search_fs_uuid normal configfile linux echo test ls cat \
    > "$LOGS/30-grub-bios.log" 2>&1 || die "grub-mkimage i386-pc-eltorito failed"
L grub-mkimage -O x86_64-efi -o /iso/bootx64.efi -p /boot/grub -c /iso/grub-embed.cfg \
    part_gpt part_msdos iso9660 fat ext2 search search_label search_fs_uuid normal configfile linux echo test ls cat \
    > "$LOGS/31-grub-efi.log" 2>&1 || die "grub-mkimage x86_64-efi failed"
L mkfs.vfat -n ALPBAHEFI -C /iso/tree/boot/efi.img 16384 > "$LOGS/32-mkfs-efi.log" 2>&1 || die "mkfs.vfat failed"
install -d -m 755 "$LIVE/iso/efimnt"
L mount -o loop /iso/tree/boot/efi.img /iso/efimnt
L /bin/sh -c 'mkdir -p /iso/efimnt/EFI/BOOT && cp /iso/bootx64.efi /iso/efimnt/EFI/BOOT/BOOTX64.EFI'
L umount /iso/efimnt
rm -f "$ISOTREE/bootx64.efi"

# ------------------------------------------------------------------ 6. ISO (xorriso from libisoburn)
log "xorriso"
L xorriso -as mkisofs -iso-level 3 -full-iso9660-filenames -joliet -joliet-long -rational-rock \
    -volid "$LABEL" -appid AlpbahOS -publisher AlpbahOS \
    -eltorito-boot boot/grub/i386-pc/eltorito.img -no-emul-boot -boot-load-size 4 -boot-info-table \
    --grub2-boot-info --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
    -eltorito-alt-boot -e boot/efi.img -no-emul-boot -isohybrid-gpt-basdat \
    -append_partition 2 0xef /iso/tree/boot/efi.img \
    -o /iso/alpbahos-beta.iso /iso/tree > "$LOGS/40-xorriso.log" 2>&1 || die "xorriso failed (log $LOGS/40-xorriso.log)"
L xorriso -indev /iso/alpbahos-beta.iso -report_el_torito plain > "$LOGS/50-el-torito.log" 2>&1 || die "xorriso report failed"
grep -q "Volume id.*'$LABEL'" "$LOGS/50-el-torito.log" || die "volume id is not $LABEL"
grep -q "BIOS" "$LOGS/50-el-torito.log" || die "no BIOS El Torito entry"
grep -q "UEFI" "$LOGS/50-el-torito.log" || die "no UEFI El Torito entry"

mv "$ISOTREE/alpbahos-beta.iso" "$OUT"
( cd "$OUT_DIR" && sha256sum "$(basename "$OUT")" > "$(basename "$OUT").sha256" )

# ------------------------------------------------------------------ 7. cleanup of the work copy
cleanup
btrfs subvolume delete "$LIVE" > /dev/null
rm -rf "$ISOTREE"
trap - EXIT

echo
echo "==== build-iso summary ===="
echo "ISO:    $OUT ($(du -h "$OUT" | awk '{print $1}'), $(stat -c%s "$OUT") bytes)"
echo "sha256: $(cut -d' ' -f1 "$OUT.sha256")"
echo "source: $SNAP_SRC (read-only)"
echo "logs:   $LOGS"
