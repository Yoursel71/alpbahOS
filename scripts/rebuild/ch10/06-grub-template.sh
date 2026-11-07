#!/bin/bash
# CONTEXT: chroot
# REBUILD-R2 chapter 10: /boot/grub/grub.cfg as a TEMPLATE only (book grub.html shape).
# No grub-install is run in this phase: the disk image phase installs the BIOS and EFI loaders and
# fills in the placeholders (@ROOT_UUID@ and @GRUB_ROOT@).
set -euo pipefail

mkdir -pv /boot/grub
cat > /boot/grub/grub.cfg << "EOF"
# Begin /boot/grub/grub.cfg
# TEMPLATE (REBUILD-R2 chapter 10). Placeholders: @ROOT_UUID@, @GRUB_ROOT@. Not valid until the image phase fills them.

set default=0
set timeout=5

insmod part_gpt
insmod part_msdos
insmod ext2
insmod search_fs_uuid

search --no-floppy --fs-uuid --set=root @ROOT_UUID@

menuentry "alpbahOS, Linux 7.1.8-alpbahos" {
    linux /boot/vmlinuz-7.1.8-alpbahos root=UUID=@ROOT_UUID@ ro
    initrd /boot/initrd.img-7.1.8
}

# End /boot/grub/grub.cfg
EOF

grep -q '@ROOT_UUID@' /boot/grub/grub.cfg
echo "OK 06-grub-template"
