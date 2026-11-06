#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.14.1: M4-1.4.21.
set -euo pipefail

PKG=m4-1.4.21.tar.xz
DIR=m4-1.4.21
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.14.1 Installation of M4
./configure --prefix=/usr
make
make check > "$TESTS/m4-check.log" 2>&1 || echo "NOTE m4 check exited $? (see $TESTS/m4-check.log)"
tail -n 3 "$TESTS/m4-check.log"
make install

cd /sources
rm -rf "$DIR"
echo "OK 12-m4"
