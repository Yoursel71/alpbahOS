#!/bin/bash
# Multilib LFS 13.1, chapter 6, section 6.14: Sed-4.10
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../config.sh"
lfs_guard

PKG=sed-4.10.tar.xz
PKG_DIR=sed-4.10

cd $LFS/sources
rm -rf $PKG_DIR
tar -xf $PKG
cd $PKG_DIR

# 6.14.1 Installation of Sed
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(./build-aux/config.guess)

make

make DESTDIR=$LFS install

cd $LFS/sources && rm -rf $PKG_DIR
echo "OK 13-sed"
