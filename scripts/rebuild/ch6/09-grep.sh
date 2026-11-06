#!/bin/bash
# Multilib LFS 13.1, chapter 6, section 6.10: Grep-3.12
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../config.sh"
lfs_guard

PKG=grep-3.12.tar.xz
PKG_DIR=grep-3.12

cd $LFS/sources
rm -rf $PKG_DIR
tar -xf $PKG
cd $PKG_DIR

# 6.10.1 Installation of Grep
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(./build-aux/config.guess)

make

make DESTDIR=$LFS install

cd $LFS/sources && rm -rf $PKG_DIR
echo "OK 09-grep"
