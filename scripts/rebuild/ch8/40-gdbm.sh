#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapters 8.42.1-8.42.2: GDBM-1.26 (64-bit, then 32-bit).
set -euo pipefail

PKG=gdbm-1.26.tar.gz
DIR=gdbm-1.26
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.42.1 Installation of GDBM
./configure --prefix=/usr \
            --disable-static \
            --enable-libgdbm-compat
make
make check > "$TESTS/gdbm-check.log" 2>&1 || echo "NOTE gdbm check exited $? (see $TESTS/gdbm-check.log)"
tail -n 3 "$TESTS/gdbm-check.log"
make install

# 8.42.2 Installation of GDBM - 32-bit
make distclean
CC="gcc -m32" CXX="g++ -m32" \
./configure --prefix=/usr \
            --libdir=/usr/lib32 \
            --host=i686-pc-linux-gnu \
            --disable-static \
            --enable-libgdbm-compat
make
make DESTDIR=$PWD/DESTDIR install
cp -Rv DESTDIR/usr/lib32/* /usr/lib32/
rm -rf DESTDIR

cd /sources
rm -rf "$DIR"
echo "OK 40-gdbm"
