#!/bin/bash
# Multilib LFS 13.1, chapter 6, section 6.11: Gzip-1.14
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../config.sh"
lfs_guard

PKG=gzip-1.14.tar.xz
PKG_DIR=gzip-1.14

cd $LFS/sources
rm -rf $PKG_DIR
tar -xf $PKG
cd $PKG_DIR

# 6.11.1 Installation of Gzip
./configure --prefix=/usr --host=$LFS_TGT

make

make DESTDIR=$LFS install

cd $LFS/sources && rm -rf $PKG_DIR
echo "OK 10-gzip"
