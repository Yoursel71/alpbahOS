#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapters 8.28.1-8.28.2: Acl-2.4.0 (64-bit, then 32-bit).
set -euo pipefail

PKG=acl-2.4.0.tar.xz
DIR=acl-2.4.0
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.28.1 Installation of Acl
./configure --prefix=/usr \
            --disable-static \
            --docdir=/usr/share/doc/acl-2.4.0
make
# Book: test/cp.run is expected to fail until Coreutils is built with ACL support.
make check > "$TESTS/acl-check.log" 2>&1 || echo "NOTE acl check exited $? (see $TESTS/acl-check.log)"
tail -n 3 "$TESTS/acl-check.log"
make install

# 8.28.2 Installation of Acl - 32-bit
make distclean
CC="gcc -m32" ./configure \
    --prefix=/usr \
    --disable-static \
    --libdir=/usr/lib32 \
    --libexecdir=/usr/lib32 \
    --host=i686-pc-linux-gnu
make
make DESTDIR=$PWD/DESTDIR install
cp -Rv DESTDIR/usr/lib32/* /usr/lib32
rm -rf DESTDIR

cd /sources
rm -rf "$DIR"
echo "OK 26-acl"
