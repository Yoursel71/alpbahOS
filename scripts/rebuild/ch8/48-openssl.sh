#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapters 8.50.1-8.50.2: OpenSSL-4.0.1 (64-bit, then 32-bit).
# The book's test is allowed to fail for kernels without AES-CBC crypto (it can be ignored).
set -euo pipefail

PKG=openssl-4.0.1.tar.gz
DIR=openssl-4.0.1
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.50.1 Installation of OpenSSL
./config --prefix=/usr \
         --openssldir=/etc/ssl \
         --libdir=lib \
         shared \
         zlib-dynamic
make
make test > "$TESTS/openssl-test.log" 2>&1 || echo "NOTE openssl test exited $? (book: may be ignored; see $TESTS/openssl-test.log)"
tail -n 3 "$TESTS/openssl-test.log"
make INSTALL_LIBS= MANSUFFIX=ssl install
mv -v /usr/share/doc/openssl /usr/share/doc/openssl-4.0.1
cp -vfr doc/* /usr/share/doc/openssl-4.0.1

# 8.50.2 Installation of OpenSSL - 32-bit
make distclean
./config --prefix=/usr \
         --openssldir=/etc/ssl \
         --libdir=lib32 \
         shared \
         zlib-dynamic \
         no-docs \
         linux-x86
make
make DESTDIR=$PWD/DESTDIR install
cp -Rv DESTDIR/usr/lib32/* /usr/lib32
rm -rf DESTDIR

cd /sources
rm -rf "$DIR"
echo "OK 48-openssl"
