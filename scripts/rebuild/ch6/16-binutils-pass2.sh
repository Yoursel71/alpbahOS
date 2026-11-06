#!/bin/bash
# Multilib LFS 13.1, chapter 6, section 6.17: Binutils-2.47 - Pass 2
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../config.sh"
lfs_guard

PKG=binutils-2.47.tar.xz
PKG_DIR=binutils-2.47

cd $LFS/sources
rm -rf $PKG_DIR
tar -xf $PKG
cd $PKG_DIR

# 6.17.1 Installation of Binutils
sed '6031s/$add_dir//' -i ltmain.sh

# Create a separate build directory again
mkdir -v build
cd       build

../configure                   \
    --prefix=/usr              \
    --build=$(../config.guess) \
    --host=$LFS_TGT            \
    --disable-nls              \
    --enable-shared            \
    --enable-gprofng=no        \
    --disable-werror           \
    --enable-64-bit-bfd        \
    --enable-new-dtags         \
    --enable-default-hash-style=gnu

make

make DESTDIR=$LFS install

# Remove the libtool archive files because they are harmful for cross compilation,
# and remove unnecessary static libraries
rm -v $LFS/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}

cd $LFS/sources && rm -rf $PKG_DIR
echo "OK 16-binutils-pass2"
