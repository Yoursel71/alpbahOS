#!/bin/bash
# INSTALL-LUKS-01 (round 50): builds, WITHOUT the Calamares GUI, an image that has what the installer's encrypted install
# produces, to test the boot chain: GPT, ESP (vfat), root = LUKS1 + ext4 with /boot inside, the squashfs of the ISO unpacked,
# fstab/crypttab, /crypto_keyfile.bin added as a second key (luksbootkeyfile), /etc/dracut.conf.d/calamares-luks.conf
# (dracutlukscfg), /etc/default/grub with GRUB_ENABLE_CRYPTODISK=y and rd.luks.uuid/rd.luks.key (grubcfg), then the REAL
# repo scripts: target-initramfs.sh and grub-install/grub-mkconfig in a chroot. The test shell unit of the matrix is added.
# Not covered: the Calamares modules themselves (settings.conf order, module defaults): that needs the GUI install.
# Usage: luks-build.sh <iso> <out.raw>      Run as root. Passphrase: digits only (the harness types it): 123456
set -euo pipefail
ISO=${1:?iso}; OUT=${2:?out}
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
PASS=123456
[ ! -e "$OUT" ] || { echo "REFUSED: $OUT exists"; exit 2; }
MNT=/tmp/luks-build-mnt; ISOM=/tmp/luks-build-iso
mkdir -p "$MNT" "$ISOM"
LOOP=""
cleanup() { set +e
  for t in run/udev run sys proc dev boot/efi; do umount "$MNT/$t" 2>/dev/null; done
  umount "$MNT" 2>/dev/null; umount "$ISOM" 2>/dev/null
  [ -n "${MAP:-}" ] && cryptsetup close "$MAP" 2>/dev/null; [ -n "$LOOP" ] && losetup -d "$LOOP" 2>/dev/null
  rmdir "$MNT" "$ISOM" 2>/dev/null; }
trap cleanup EXIT
truncate -s 30G "$OUT"
sgdisk -o -n1:2048:+512M -t1:ef00 -n2:0:0 -t2:8300 "$OUT" > /dev/null
LOOP=$(losetup -fP --show "$OUT")
mkfs.vfat -F32 "${LOOP}p1" > /dev/null
printf '%s' "$PASS" | cryptsetup luksFormat --type luks1 -q "${LOOP}p2" -
LUUID=$(cryptsetup luksUUID "${LOOP}p2"); MAP=luks-$LUUID   # the name the installed system would use (grub-install probes it)
printf '%s' "$PASS" | cryptsetup open "${LOOP}p2" "$MAP" -
mkfs.ext4 -q -L alpbahos "/dev/mapper/$MAP"
mount "/dev/mapper/$MAP" "$MNT"; mkdir -p "$MNT/boot/efi"; mount "${LOOP}p1" "$MNT/boot/efi"
mount -o loop,ro "$ISO" "$ISOM"
echo "unsquashfs..."; unsquashfs -f -q -d "$MNT" "$ISOM/LiveOS/squashfs.img" > /dev/null
EUUID=$(blkid -o value -s UUID "${LOOP}p1")
# fstab module + crypttab
printf '# alpbahOS test\n/dev/mapper/%s / ext4 defaults 0 1\nUUID=%s /boot/efi vfat umask=0077 0 2\n' "$MAP" "$EUUID" > "$MNT/etc/fstab"
printf '%s UUID=%s /crypto_keyfile.bin luks\n' "$MAP" "$LUUID" > "$MNT/etc/crypttab"
# luksbootkeyfile: a key file as a second key
dd if=/dev/urandom of="$MNT/crypto_keyfile.bin" bs=512 count=8 status=none; chmod 000 "$MNT/crypto_keyfile.bin"
printf '%s' "$PASS" | cryptsetup luksAddKey "${LOOP}p2" "$MNT/crypto_keyfile.bin" -
# dracutlukscfg
mkdir -p "$MNT/etc/dracut.conf.d"; printf 'install_items+=" /etc/crypttab /crypto_keyfile.bin "\n' > "$MNT/etc/dracut.conf.d/calamares-luks.conf"
# grubcfg
cat > "$MNT/etc/default/grub" <<EOF
GRUB_DEFAULT='saved'
GRUB_DISABLE_LINUX_PARTUUID='false'
GRUB_DISABLE_LINUX_UUID='true'
GRUB_DISABLE_OS_PROBER='false'
GRUB_DISABLE_RECOVERY='true'
GRUB_DISABLE_SUBMENU='true'
GRUB_DISTRIBUTOR='alpbahOS'
GRUB_GFXMODE='1024x768,auto'
GRUB_TERMINAL_OUTPUT='gfxterm'
GRUB_TIMEOUT='3'
GRUB_ENABLE_CRYPTODISK=y
GRUB_CMDLINE_LINUX_DEFAULT='quiet splash'
GRUB_CMDLINE_LINUX='rd.luks.uuid=$LUUID rd.luks.key=/crypto_keyfile.bin'
EOF
# test shell unit (same as cmd_mkcopy)
install -m 755 "$WT/scripts/rebuild/r21/guest-agent-r21.sh" "$MNT/usr/local/sbin/r21m-agent"
install -m 755 "$WT/scripts/rebuild/r21/guest-as-user-r21.sh" "$MNT/usr/local/sbin/r21m-as-user"
install -m 644 "$WT/scripts/rebuild/r21/guest-agent-r21.service" "$MNT/etc/systemd/system/r21m-agent.service"
mkdir -p "$MNT/etc/systemd/system/graphical.target.wants"; ln -sf /etc/systemd/system/r21m-agent.service "$MNT/etc/systemd/system/graphical.target.wants/r21m-agent.service"
install -m 755 "$WT/scripts/rebuild/iso/live/target-initramfs.sh" "$MNT/tmp/target-initramfs.sh"
mount --bind /dev "$MNT/dev"; mount -t proc proc "$MNT/proc"; mount -t sysfs sys "$MNT/sys"; mount -t tmpfs tmpfs "$MNT/run"; mkdir -p "$MNT/run/lock" "$MNT/run/udev"; mount --bind /run/udev "$MNT/run/udev"   # grub-probe reads the dm uuid (CRYPT-) through udev
E_=/usr/bin/env\ -i; ENVV="PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C HOME=/root"
echo "== target-initramfs.sh"; chroot "$MNT" env $ENVV sh /tmp/target-initramfs.sh 2>&1 | tail -n 4
echo "== grub-install"; chroot "$MNT" env $ENVV grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable --no-nvram 2>&1 | tail -n 3
echo "== grub-mkconfig"; chroot "$MNT" env $ENVV grub-mkconfig -o /boot/grub/grub.cfg 2>&1 | tail -n 4
echo "linux lines: $(grep -c '^\s*linux' "$MNT/boot/grub/grub.cfg"); cryptodisk lines: $(grep -c cryptomount "$MNT/boot/grub/grub.cfg"); rd.luks in cfg: $(grep -c 'rd.luks.uuid' "$MNT/boot/grub/grub.cfg")"
echo "initramfs crypt: $(chroot "$MNT" env $ENVV lsinitrd /boot/initramfs-*.img 2>/dev/null | grep -cE 'cryptsetup|crypto_keyfile|dm-crypt')"
sync; echo "built $OUT (LUKS uuid $LUUID)"
