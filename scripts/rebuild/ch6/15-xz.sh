#!/bin/bash
# Multilib LFS 13.1, chapter 6, section 6.16: Xz-5.8.3
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../config.sh"
lfs_guard

PKG=xz-5.8.3.tar.xz
PKG_DIR=xz-5.8.3

cd $LFS/sources
rm -rf $PKG_DIR
tar -xf $PKG
cd $PKG_DIR

# 6.16.1 Installation of Xz
./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --disable-static                  \
            --docdir=/usr/share/doc/xz-5.8.3

make

make DESTDIR=$LFS install

# Remove the libtool archive file because it is harmful for cross compilation
rm -v $LFS/usr/lib/liblzma.la

cd $LFS/sources && rm -rf $PKG_DIR
echo "OK 15-xz"
