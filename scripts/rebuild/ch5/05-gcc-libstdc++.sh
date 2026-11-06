#!/bin/bash
# Multilib LFS 13.1, Chapter 5.6 "Libstdc++ from GCC-16.2.0"
# https://linuxfromscratch.org/mlfs/view/13.1/chapter05/gcc-libstdc++.html
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../config.sh"
lfs_guard

PKG=gcc-16.2.0.tar.xz
DIR=gcc-16.2.0

cd "$LFS/sources"
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

mkdir -v build
cd       build

../libstdc++-v3/configure           \
    --host=$LFS_TGT                 \
    --build=$(../config.guess)      \
    CXX=$LFS_TGT-gcc           \
    --prefix=/usr                   \
    --enable-multilib               \
    --disable-nls                   \
    --disable-libstdcxx-pch         \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/16.2.0

make

make DESTDIR=$LFS install

rm -v $LFS/usr/lib/lib{stdc++{,exp,fs},supc++}.la

cd "$LFS/sources"
rm -rf "$DIR"

echo "OK 05-gcc-libstdc++"
