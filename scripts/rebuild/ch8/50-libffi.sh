#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapters 8.52.1-8.52.2: Libffi-3.8.0 (64-bit, then 32-bit).
# D146: the book's --with-gcc-arch=native is replaced by the generic x86-64 baseline.
set -euo pipefail

PKG=libffi-3.8.0.tar.gz
DIR=libffi-3.8.0
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.52.1 Installation of Libffi
./configure --prefix=/usr \
            --disable-static \
            --with-gcc-arch=x86-64
make
make check > "$TESTS/libffi-check.log" 2>&1 || echo "NOTE libffi check exited $? (see $TESTS/libffi-check.log)"
tail -n 3 "$TESTS/libffi-check.log"
make install

# 8.52.2 Installation of Libffi - 32-bit
make distclean
CC="gcc -m32" CXX="g++ -m32" \
./configure --prefix=/usr \
            --libdir=/usr/lib32 \
            --host=i686-pc-linux-gnu \
            --disable-static \
            --with-gcc-arch=i686
make
make check > "$TESTS/libffi32-check.log" 2>&1 || echo "NOTE libffi 32-bit check exited $? (see $TESTS/libffi32-check.log)"
tail -n 3 "$TESTS/libffi32-check.log"
make DESTDIR=$PWD/DESTDIR install
cp -Rv DESTDIR/usr/lib32/* /usr/lib32
rm -rf DESTDIR

cd /sources
rm -rf "$DIR"
echo "OK 50-libffi"
