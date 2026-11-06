#!/bin/bash
# Multilib LFS 13.1, chapter 6, section 6.13: Patch-2.8
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../config.sh"
lfs_guard

PKG=patch-2.8.tar.xz
PKG_DIR=patch-2.8

cd $LFS/sources
rm -rf $PKG_DIR
tar -xf $PKG
cd $PKG_DIR

# 6.13.1 Installation of Patch
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)

make

make DESTDIR=$LFS install

cd $LFS/sources && rm -rf $PKG_DIR
echo "OK 12-patch"
