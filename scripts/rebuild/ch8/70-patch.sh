#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.72.1: Patch-2.8.
set -euo pipefail

PKG=patch-2.8.tar.xz
DIR=patch-2.8
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.72.1 Installation of Patch
./configure --prefix=/usr
make
make check > "$TESTS/patch-check.log" 2>&1 || echo "NOTE patch check exited $? (see $TESTS/patch-check.log)"
tail -n 3 "$TESTS/patch-check.log"
make install

cd /sources
rm -rf "$DIR"
echo "OK 70-patch"
