#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.15.1: Bc-7.0.3.
set -euo pipefail

PKG=bc-7.0.3.tar.xz
DIR=bc-7.0.3
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.15.1 Installation of Bc
CC='gcc -std=c99' ./configure --prefix=/usr -G -O3 -r
make
make test > "$TESTS/bc-test.log" 2>&1 || echo "NOTE bc test exited $? (see $TESTS/bc-test.log)"
tail -n 3 "$TESTS/bc-test.log"
make install

cd /sources
rm -rf "$DIR"
echo "OK 13-bc"
