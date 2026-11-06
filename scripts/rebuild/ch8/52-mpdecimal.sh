#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.54.1: mpdecimal-4.0.1.
set -euo pipefail

PKG=mpdecimal-4.0.1.tar.gz
DIR=mpdecimal-4.0.1
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.54.1 Installation of mpdecimal
./configure --prefix=/usr \
            --disable-static \
            --docdir=/usr/share/doc/mpdecimal-4.0.1
make
make check_local > "$TESTS/mpdecimal-check.log" 2>&1 || echo "NOTE mpdecimal check exited $? (see $TESTS/mpdecimal-check.log)"
tail -n 3 "$TESTS/mpdecimal-check.log"
make install

cd /sources
rm -rf "$DIR"
echo "OK 52-mpdecimal"
