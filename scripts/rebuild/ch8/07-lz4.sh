#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, sections 8.9.1-8.9.2: Lz4-1.10.0 (64-bit, then 32-bit).
set -euo pipefail

PKG=lz4-1.10.0.tar.gz
DIR=lz4-1.10.0
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.9.1 Installation of Lz4
make BUILD_STATIC=no PREFIX=/usr
make -j1 check > "$TESTS/lz4-check.log" 2>&1 || echo "NOTE lz4 check exited $? (see $TESTS/lz4-check.log)"
tail -n 3 "$TESTS/lz4-check.log"
make BUILD_STATIC=no PREFIX=/usr install

# 8.9.2 Installation of Lz4 - 32-bit
make clean
CC="gcc -m32" make BUILD_STATIC=no -C lib
make BUILD_STATIC=no \
     PREFIX=/usr \
     LIBDIR=/usr/lib32 \
     DESTDIR=$(pwd)/m32 \
     -C lib install
cp -vR m32/usr/lib32/* /usr/lib32/

cd /sources
rm -rf "$DIR"
echo "OK 07-lz4"
