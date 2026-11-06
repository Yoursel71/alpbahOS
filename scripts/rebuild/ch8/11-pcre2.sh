#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, sections 8.13.1-8.13.2: Pcre2-10.47 (64-bit, then 32-bit).
set -euo pipefail

PKG=pcre2-10.47.tar.bz2
DIR=pcre2-10.47
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.13.1 Installation of Pcre2
./configure --prefix=/usr \
            --docdir=/usr/share/doc/pcre2-10.47 \
            --enable-unicode \
            --enable-jit \
            --enable-pcre2-16 \
            --enable-pcre2-32 \
            --enable-pcre2grep-libz \
            --enable-pcre2grep-libbz2 \
            --enable-pcre2test-libreadline \
            --disable-static
make
make check > "$TESTS/pcre2-check.log" 2>&1 || echo "NOTE pcre2 check exited $? (see $TESTS/pcre2-check.log)"
tail -n 3 "$TESTS/pcre2-check.log"
make install

# 8.13.2 Installation of Pcre2 - 32-bit
make distclean
CC="gcc -m32" CXX="g++ -m32" \
./configure --prefix=/usr \
            --libdir=/usr/lib32 \
            --host=i686-pc-linux-gnu \
            --enable-unicode \
            --enable-jit \
            --enable-pcre2-16 \
            --enable-pcre2-32 \
            --enable-pcre2grep-libz \
            --enable-pcre2grep-libbz2 \
            --enable-pcre2test-libreadline \
            --disable-static
make
make DESTDIR=$PWD/DESTDIR install
cp -Rv DESTDIR/usr/lib32/* /usr/lib32
rm -rf DESTDIR

cd /sources
rm -rf "$DIR"
echo "OK 11-pcre2"
