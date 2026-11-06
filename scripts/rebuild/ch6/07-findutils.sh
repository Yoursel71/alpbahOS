#!/bin/bash
# Multilib LFS 13.1, chapter 6, section 6.8: Findutils-4.11.0
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../config.sh"
lfs_guard

PKG=findutils-4.11.0.tar.xz
PKG_DIR=findutils-4.11.0

cd $LFS/sources
rm -rf $PKG_DIR
tar -xf $PKG
cd $PKG_DIR

# 6.8.1 Installation of Findutils
./configure --prefix=/usr                   \
            --localstatedir=/var/lib/locate \
            --host=$LFS_TGT                 \
            --build=$(build-aux/config.guess)

make

make DESTDIR=$LFS install

cd $LFS/sources && rm -rf $PKG_DIR
echo "OK 07-findutils"
