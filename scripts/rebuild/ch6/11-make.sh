#!/bin/bash
# Multilib LFS 13.1, chapter 6, section 6.12: Make-4.4.1
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../config.sh"
lfs_guard

PKG=make-4.4.1.tar.gz
PKG_DIR=make-4.4.1

cd $LFS/sources
rm -rf $PKG_DIR
tar -xf $PKG
cd $PKG_DIR

# 6.12.1 Installation of Make
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)

make

make DESTDIR=$LFS install

cd $LFS/sources && rm -rf $PKG_DIR
echo "OK 11-make"
