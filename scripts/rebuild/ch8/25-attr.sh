#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapters 8.27.1-8.27.2: Attr-2.6.0 (64-bit, then 32-bit).
set -euo pipefail

PKG=attr-2.6.0.tar.gz
DIR=attr-2.6.0
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.27.1 Installation of Attr
./configure --prefix=/usr \
            --disable-static \
            --sysconfdir=/etc \
            --docdir=/usr/share/doc/attr-2.6.0
make
make check > "$TESTS/attr-check.log" 2>&1 || echo "NOTE attr check exited $? (see $TESTS/attr-check.log)"
tail -n 3 "$TESTS/attr-check.log"
make install

# 8.27.2 Installation of Attr - 32-bit
make distclean
CC="gcc -m32" ./configure \
    --prefix=/usr \
    --disable-static \
    --sysconfdir=/etc \
    --libdir=/usr/lib32 \
    --host=i686-pc-linux-gnu
make
make DESTDIR=$PWD/DESTDIR install
cp -Rv DESTDIR/usr/lib32/* /usr/lib32
rm -rf DESTDIR

cd /sources
rm -rf "$DIR"
echo "OK 25-attr"
