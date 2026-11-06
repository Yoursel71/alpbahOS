#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, sections 8.10.1-8.10.2: Zstd-1.5.7 (64-bit, then 32-bit).
set -euo pipefail

PKG=zstd-1.5.7.tar.gz
DIR=zstd-1.5.7
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.10.1 Installation of Zstd
make prefix=/usr
make check > "$TESTS/zstd-check.log" 2>&1 || echo "NOTE zstd check exited $? (see $TESTS/zstd-check.log)"
tail -n 3 "$TESTS/zstd-check.log"
make prefix=/usr install
rm -v /usr/lib/libzstd.a

# 8.10.2 Installation of Zstd - 32-bit
make clean
CC="gcc -m32" make prefix=/usr
make prefix=/usr DESTDIR=$PWD/DESTDIR install
cp -Rv DESTDIR/usr/lib/* /usr/lib32/
sed -e "/^libdir/s/lib$/lib32/" -i /usr/lib32/pkgconfig/libzstd.pc
rm -rf DESTDIR

cd /sources
rm -rf "$DIR"
echo "OK 08-zstd"
