#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapters 8.41.1-8.41.2: Libtool-2.6.2 (64-bit, then 32-bit).
set -euo pipefail

PKG=libtool-2.6.2.tar.xz
DIR=libtool-2.6.2
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.41.1 Installation of Libtool
./configure --prefix=/usr
make
make check > "$TESTS/libtool-check.log" 2>&1 || echo "NOTE libtool check exited $? (see $TESTS/libtool-check.log)"
tail -n 3 "$TESTS/libtool-check.log"
make install
rm -fv /usr/lib/libltdl.a

# 8.41.2 Installation of Libtool - 32-bit
make distclean
CC="gcc -m32" ./configure \
    --host=i686-pc-linux-gnu \
    --prefix=/usr \
    --libdir=/usr/lib32
make
make DESTDIR=$PWD/DESTDIR install
cp -Rv DESTDIR/usr/lib32/* /usr/lib32
rm -rf DESTDIR

cd /sources
rm -rf "$DIR"
echo "OK 39-libtool"
