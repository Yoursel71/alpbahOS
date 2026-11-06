#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, sections 8.8.1-8.8.2: Xz-5.8.3 (64-bit, then 32-bit).
set -euo pipefail

PKG=xz-5.8.3.tar.xz
DIR=xz-5.8.3
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.8.1 Installation of Xz
./configure --prefix=/usr \
            --disable-static \
            --docdir=/usr/share/doc/xz-5.8.3
make
make check > "$TESTS/xz-check.log" 2>&1 || echo "NOTE xz check exited $? (see $TESTS/xz-check.log)"
tail -n 3 "$TESTS/xz-check.log"
make install

# 8.8.2 Installation of Xz - 32-bit
make distclean
CC="gcc -m32" ./configure \
    --host=i686-pc-linux-gnu \
    --prefix=/usr \
    --libdir=/usr/lib32 \
    --disable-static
make
make DESTDIR=$PWD/DESTDIR install
cp -Rv DESTDIR/usr/lib32/* /usr/lib32
rm -rf DESTDIR

cd /sources
rm -rf "$DIR"
echo "OK 06-xz"
