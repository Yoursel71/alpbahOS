#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.67.1: Gzip-1.14.
set -euo pipefail

PKG=gzip-1.14.tar.xz
DIR=gzip-1.14
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.67.1 Installation of Gzip
./configure --prefix=/usr
make
make check > "$TESTS/gzip-check.log" 2>&1 || echo "NOTE gzip check exited $? (see $TESTS/gzip-check.log)"
tail -n 3 "$TESTS/gzip-check.log"
make install

cd /sources
rm -rf "$DIR"
echo "OK 65-gzip"
