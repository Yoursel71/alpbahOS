#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapters 8.30.1-8.30.2: Libxcrypt-4.5.2 (64-bit, then 32-bit).
# The book's upgrade-only Note (libcrypt.so.1 for an older glibc) is not needed on a fresh build.
set -euo pipefail

PKG=libxcrypt-4.5.2.tar.xz
DIR=libxcrypt-4.5.2
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.30.1 Installation of Libxcrypt
sed -i '/strchr/s/const//' lib/crypt-{sm3,gost}-yescrypt.c
./configure --prefix=/usr \
            --enable-hashes=strong,glibc \
            --enable-obsolete-api=no \
            --disable-static \
            --disable-failure-tokens
make
make check > "$TESTS/libxcrypt-check.log" 2>&1 || echo "NOTE libxcrypt check exited $? (see $TESTS/libxcrypt-check.log)"
tail -n 3 "$TESTS/libxcrypt-check.log"
make install

# 8.30.2 Installation of Libxcrypt - 32-bit
make distclean
CC="gcc -m32" \
./configure --prefix=/usr \
            --host=i686-pc-linux-gnu \
            --libdir=/usr/lib32 \
            --enable-hashes=strong,glibc \
            --enable-obsolete-api=glibc \
            --disable-static \
            --disable-failure-tokens
make
cp -av .libs/libcrypt.so* /usr/lib32/
make install-pkgconfigDATA
ln -svf libxcrypt.pc /usr/lib32/pkgconfig/libcrypt.pc

cd /sources
rm -rf "$DIR"
echo "OK 28-libxcrypt"
