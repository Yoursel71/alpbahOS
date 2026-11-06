#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, sections 8.11.1-8.11.2: File-5.48 (64-bit, then 32-bit).
set -euo pipefail

PKG=file-5.48.tar.gz
DIR=file-5.48
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.11.1 Installation of File
./configure --prefix=/usr
make
make check > "$TESTS/file-check.log" 2>&1 || echo "NOTE file check exited $? (see $TESTS/file-check.log)"
tail -n 3 "$TESTS/file-check.log"
make install

# 8.11.2 Installation of File - 32-bit
make distclean
CC="gcc -m32" ./configure \
    --prefix=/usr \
    --libdir=/usr/lib32 \
    --host=i686-pc-linux-gnu
make
make DESTDIR=$PWD/DESTDIR install
cp -Rv DESTDIR/usr/lib32/* /usr/lib32
rm -rf DESTDIR

cd /sources
rm -rf "$DIR"
echo "OK 09-file"
