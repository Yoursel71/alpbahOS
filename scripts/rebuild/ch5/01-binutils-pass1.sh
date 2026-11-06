#!/bin/bash
# Multilib LFS 13.1, Chapter 5.2 "Binutils-2.47 - Pass 1"
# https://linuxfromscratch.org/mlfs/view/13.1/chapter05/binutils-pass1.html
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../config.sh"
lfs_guard

PKG=binutils-2.47.tar.xz
DIR=binutils-2.47

cd "$LFS/sources"
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

mkdir -v build
cd       build

../configure --prefix=$LFS/tools \
             --with-sysroot=$LFS \
             --target=$LFS_TGT   \
             --disable-nls       \
             --enable-gprofng=no \
             --disable-werror    \
             --enable-new-dtags  \
             --enable-default-hash-style=gnu

make
make install

cd "$LFS/sources"
rm -rf "$DIR"

echo "OK 01-binutils-pass1"
