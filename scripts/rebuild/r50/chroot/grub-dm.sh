#!/bin/bash
# GRUB-DM-01 (round 50): GRUB 2.14 rebuilt with libdevmapper. The LFS chapter 8 build (ch8/64-grub.sh) ran before LVM2, so
# grub-probe/grub-install had no device-mapper support and treated /dev/mapper/luks-<uuid> as an LVM volume
# ("disk `lvm/luks-...' not found"): an encrypted install could not get its bootloader. Same three configures as the book
# (BIOS, x86_64 EFI, i386 EFI) plus --enable-device-mapper, DESTDIR stage; run in the chroot of r4-root.
set -e
unset CFLAGS CPPFLAGS CXXFLAGS LDFLAGS
sed 's/--image-base/--nonexist-linker-option/' -i configure
OPTS="--prefix=/usr --sysconfdir=/etc --disable-efiemu --disable-werror --enable-device-mapper"
./configure $OPTS
make
make DESTDIR="$STAGE" install
make clean
./configure $OPTS --target=x86_64 --with-platform=efi
make
make DESTDIR="$STAGE" install
make clean
./configure $OPTS --target=i386 --with-platform=efi
make
make DESTDIR="$STAGE" install
