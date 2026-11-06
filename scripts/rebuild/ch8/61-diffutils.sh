#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.63.1: Diffutils-3.12.
set -euo pipefail

PKG=diffutils-3.12.tar.xz
DIR=diffutils-3.12
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.63.1 Installation of Diffutils
./configure --prefix=/usr
make
make check > "$TESTS/diffutils-check.log" 2>&1 || echo "NOTE diffutils check exited $? (see $TESTS/diffutils-check.log)"
tail -n 3 "$TESTS/diffutils-check.log"
make install

cd /sources
rm -rf "$DIR"
echo "OK 61-diffutils"
