#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.66.1: GRUB-2.14 (BIOS, x86_64 EFI and i386 EFI builds).
# The book does not recommend the GRUB test suite in LFS (most tests need packages not in LFS): not run.
set -euo pipefail

PKG=grub-2.14.tar.xz
DIR=grub-2.14

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.66.1 Installation of GRUB
unset {C,CPP,CXX,LD}FLAGS
sed 's/--image-base/--nonexist-linker-option/' -i configure

./configure --prefix=/usr \
            --sysconfdir=/etc \
            --disable-efiemu \
            --disable-werror
make
make install
make clean

./configure --prefix=/usr \
            --sysconfdir=/etc \
            --target=x86_64 \
            --with-platform=efi \
            --disable-efiemu \
            --disable-werror
make
make install
make clean

./configure --prefix=/usr \
            --sysconfdir=/etc \
            --target=i386 \
            --with-platform=efi \
            --disable-efiemu \
            --disable-werror
make
make install

cd /sources
rm -rf "$DIR"
echo "OK 64-grub"
