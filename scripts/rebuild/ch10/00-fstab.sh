#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1-systemd, chapter 10, "Creating the /etc/fstab File" (book page fstab.html).
# TEMPLATE ONLY: the UUID placeholders (@ROOT_UUID@, @ESP_UUID@) are filled in by the later image phase,
# when the disk image exists. /boot is not a separate partition in this layout: kernel and initramfs
# live in the root file system's /boot directory, and the ESP is mounted at /boot/efi (as in M11).
set -euo pipefail

cat > /etc/fstab << "EOF"
# Begin /etc/fstab

# file system        mount-point  type   options    dump  fsck
#                                                          order
UUID=@ROOT_UUID@     /            ext4   defaults   1     1
UUID=@ESP_UUID@      /boot/efi    vfat   umask=0077 0     2

# End /etc/fstab
EOF

grep -q '@ROOT_UUID@' /etc/fstab
echo "OK 00-fstab"
