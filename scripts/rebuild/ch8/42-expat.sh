#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapters 8.44.1-8.44.2: Expat-2.8.3 (64-bit, then 32-bit).
set -euo pipefail

PKG=expat-2.8.3.tar.xz
DIR=expat-2.8.3
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.44.1 Installation of Expat
./configure --prefix=/usr \
            --disable-static \
            --docdir=/usr/share/doc/expat-2.8.3
make
make check > "$TESTS/expat-check.log" 2>&1 || echo "NOTE expat check exited $? (see $TESTS/expat-check.log)"
tail -n 3 "$TESTS/expat-check.log"
make install
install -v -m644 doc/*.{html,css} /usr/share/doc/expat-2.8.3

# 8.44.2 Installation of Expat - 32-bit
sed -e "/^am__append_1/ s/doc//" -i Makefile
make clean
CC="gcc -m32" \
./configure --prefix=/usr \
            --libdir=/usr/lib32 \
            --host=i686-pc-linux-gnu \
            --disable-static
make
make DESTDIR=$PWD/DESTDIR install
cp -Rv DESTDIR/usr/lib32/* /usr/lib32
rm -rf DESTDIR

cd /sources
rm -rf "$DIR"
echo "OK 42-expat"
