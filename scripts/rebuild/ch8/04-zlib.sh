#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, sections 8.6.1-8.6.2: Zlib-1.3.2 (64-bit, then 32-bit).
set -euo pipefail

PKG=zlib-1.3.2.tar.gz
DIR=zlib-1.3.2
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.6.1 Installation of Zlib
./configure --prefix=/usr
make
make check > "$TESTS/zlib-check.log" 2>&1 || echo "NOTE zlib check exited $? (see $TESTS/zlib-check.log)"
tail -n 3 "$TESTS/zlib-check.log"
make install
rm -fv /usr/lib/libz.a

# 8.6.2 Installation of Zlib - 32-bit
make distclean
CFLAGS+=" -m32" CXXFLAGS+=" -m32" \
./configure --prefix=/usr --libdir=/usr/lib32
make
make DESTDIR=$PWD/DESTDIR install
cp -Rv DESTDIR/usr/lib32/* /usr/lib32
rm -rf DESTDIR

cd /sources
rm -rf "$DIR"
echo "OK 04-zlib"
