#!/bin/bash
# Multilib LFS 13.1, chapter 6, section 6.6: Diffutils-3.12
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../config.sh"
lfs_guard

PKG=diffutils-3.12.tar.xz
PKG_DIR=diffutils-3.12

cd $LFS/sources
rm -rf $PKG_DIR
tar -xf $PKG
cd $PKG_DIR

# 6.6.1 Installation of Diffutils
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            gl_cv_func_strcasecmp_works=yes \
            --build=$(./build-aux/config.guess)

make

make DESTDIR=$LFS install

cd $LFS/sources && rm -rf $PKG_DIR
echo "OK 05-diffutils"
