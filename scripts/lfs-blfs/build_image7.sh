#!/bin/bash
# LFS disk imajı v4: BIOS (i386-pc) + UEFI (x86_64-efi, removable). Root sda2 (eski yollar aynı), ESP sda3.
set -eo pipefail
IMG=/home/yrslf/alpbahOS/scratch-lfs-bench/disk-blfs3.img
LFS=/mnt/lfs; MNT=/mnt/lfsimg
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
[ -e "$IMG" ] && { echo "IMAJ VAR (reddedildi)"; exit 1; }
truncate -s 22G "$IMG"
sgdisk -Z "$IMG" >/dev/null
sgdisk -n1:2048:+1M -t1:ef02 -c1:biosgrub "$IMG"
sgdisk -n2:0:+18G -t2:8300 -c2:lfsroot "$IMG"
sgdisk -n3:0:0 -t3:ef00 -c3:esp "$IMG"
LOOP=$(losetup -fP --show "$IMG"); echo "loop=$LOOP"
cleanup(){ umount -R "$MNT" 2>/dev/null || true; losetup -d "$LOOP" 2>/dev/null || true; }
trap cleanup EXIT
mkfs.ext4 -q -O ^orphan_file,^metadata_csum_seed -L lfsroot "${LOOP}p2"
mkfs.vfat -F32 -n LFSESP "${LOOP}p3" >/dev/null
mkdir -p "$MNT"; mount "${LOOP}p2" "$MNT"
for e in $(ls -A "$LFS"); do case "$e" in sources|tools|lost+found|dev|proc|sys|run) continue;; esac; cp -a "$LFS/$e" "$MNT/"; done
mkdir -p "$MNT"/{dev,proc,sys,run,sources,tools,boot/efi}
cat > "$MNT/etc/fstab" << 'FSTAB'
# file system  mount-point  type     options             dump  fsck
#                                                              order
/dev/sda2      /            ext4     defaults            1     1
/dev/sda3      /boot/efi    vfat     umask=0077          0     2
proc           /proc        proc     nosuid,noexec,nodev 0     0
sysfs          /sys         sysfs    nosuid,noexec,nodev 0     0
devpts         /dev/pts     devpts   gid=5,mode=620      0     0
tmpfs          /run         tmpfs    defaults            0     0
devtmpfs       /dev         devtmpfs mode=0755,nosuid    0     0
tmpfs          /dev/shm     tmpfs    nosuid,nodev        0     0
FSTAB
# root parolası boş (kullanıcı isteği)
sed -i 's/^root:[^:]*:/root::/' "$MNT/etc/shadow"
mkdir -p "$MNT/boot/grub"
cat > "$MNT/boot/grub/grub.cfg" << 'GRUBCFG'
set default=0
set timeout=5

insmod part_gpt
insmod ext2
set root=(hd0,gpt2)
set gfxpayload=1024x768x32

menuentry "GNU/Linux, Linux 6.16.1-lfs-12.4-systemd" {
        linux   /boot/vmlinuz-6.16.1-lfs-12.4-systemd root=/dev/sda2 rw console=tty1 console=ttyS0
}

menuentry "GNU/Linux, Linux 7.2.7 (Fedora kerneli, yedek)" {
        linux   /boot/vmlinuz-7.2.7-fedora-host root=/dev/sda2 rw init=/usr/lib/systemd/systemd console=tty1 console=ttyS0
}
GRUBCFG
cp /home/yrslf/alpbahOS/scratch-lfs-bench/fedora-kernel-copy-placeholder 2>/dev/null || true
cp /boot/vmlinuz-7.2.7-200.fc44.x86_64 "$MNT/boot/vmlinuz-7.2.7-fedora-host"
mount --bind /dev "$MNT/dev"; mount -t proc proc "$MNT/proc"; mount -t sysfs sysfs "$MNT/sys"
mount "${LOOP}p3" "$MNT/boot/efi"
chroot "$MNT" /usr/bin/env -i HOME=/root TERM=xterm PATH=/usr/bin:/usr/sbin /bin/bash --login +h -c "grub-install --target=i386-pc $LOOP"
chroot "$MNT" /usr/bin/env -i HOME=/root TERM=xterm PATH=/usr/bin:/usr/sbin /bin/bash --login +h -c "grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable --no-nvram"
# ESP'den tam yapılandırmaya düş (root = sda2)
mkdir -p "$MNT/boot/efi/EFI/BOOT"
cat > "$MNT/boot/efi/EFI/BOOT/grub.cfg" << 'STUB'
set root=(hd0,gpt2)
configfile /boot/grub/grub.cfg
STUB
sync
echo IMAGE_OK
