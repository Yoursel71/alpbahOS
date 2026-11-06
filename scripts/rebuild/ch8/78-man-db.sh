#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.80.1: Man-DB-2.13.1.
set -euo pipefail

PKG=man-db-2.13.1.tar.xz
DIR=man-db-2.13.1
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.80.1 Installation of Man-DB
./configure --prefix=/usr \
            --docdir=/usr/share/doc/man-db-2.13.1 \
            --sysconfdir=/etc \
            --disable-setuid \
            --enable-cache-owner=bin \
            --with-browser=/usr/bin/lynx \
            --with-vgrind=/usr/bin/vgrind \
            --with-grap=/usr/bin/grap
make
make check > "$TESTS/man-db-check.log" 2>&1 || echo "NOTE man-db check exited $? (see $TESTS/man-db-check.log)"
tail -n 3 "$TESTS/man-db-check.log"
make install

cd /sources
rm -rf "$DIR"
echo "OK 78-man-db"
