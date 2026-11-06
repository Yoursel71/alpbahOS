#!/bin/bash
# Multilib LFS 13.1, chapter 6, section 6.15: Tar-1.35
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../config.sh"
lfs_guard

PKG=tar-1.35.tar.xz
PKG_DIR=tar-1.35

cd $LFS/sources
rm -rf $PKG_DIR
tar -xf $PKG
cd $PKG_DIR

# 6.15.1 Installation of Tar
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)

make

make DESTDIR=$LFS install

cd $LFS/sources && rm -rf $PKG_DIR
echo "OK 14-tar"
