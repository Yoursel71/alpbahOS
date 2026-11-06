#!/bin/bash
# Multilib LFS 13.1, chapter 6, section 6.5: Coreutils-9.11
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../config.sh"
lfs_guard

PKG=coreutils-9.11.tar.xz
PKG_DIR=coreutils-9.11

cd $LFS/sources
rm -rf $PKG_DIR
tar -xf $PKG
cd $PKG_DIR

# 6.5.1 Installation of Coreutils
./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --enable-install-program=hostname

make

make DESTDIR=$LFS install

mv -v $LFS/usr/bin/chroot              $LFS/usr/sbin
mkdir -pv $LFS/usr/share/man/man8
mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/'                    $LFS/usr/share/man/man8/chroot.8

cd $LFS/sources && rm -rf $PKG_DIR
echo "OK 04-coreutils"
