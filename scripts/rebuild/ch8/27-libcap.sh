#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapters 8.29.1-8.29.2: Libcap-2.78 (64-bit, then 32-bit).
set -euo pipefail

PKG=libcap-2.78.tar.xz
DIR=libcap-2.78
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.29.1 Installation of Libcap
sed -i '/install -m.*STA/d' libcap/Makefile
make prefix=/usr lib=lib
make test > "$TESTS/libcap-test.log" 2>&1 || echo "NOTE libcap test exited $? (see $TESTS/libcap-test.log)"
tail -n 3 "$TESTS/libcap-test.log"
make prefix=/usr lib=lib install

# 8.29.2 Installation of Libcap - 32-bit
make distclean
make CC="gcc -m32 -march=i686" lib=lib32
make CC="gcc -m32 -march=i686" lib=lib32 prefix=$PWD/DESTDIR/usr install -C libcap
cp -Rv DESTDIR/usr/lib32/* /usr/lib32
sed -e "s|^libdir=.*|libdir=/usr/lib32|" -i /usr/lib32/pkgconfig/lib{cap,psx}.pc
chmod -v 755 /usr/lib32/libcap.so.2.78
rm -rf DESTDIR

cd /sources
rm -rf "$DIR"
echo "OK 27-libcap"
