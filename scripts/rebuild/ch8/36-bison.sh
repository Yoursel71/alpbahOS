#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.38.1: Bison-3.8.2.
set -euo pipefail

PKG=bison-3.8.2.tar.xz
DIR=bison-3.8.2
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.38.1 Installation of Bison
./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2
make
make check > "$TESTS/bison-check.log" 2>&1 || echo "NOTE bison check exited $? (see $TESTS/bison-check.log)"
tail -n 3 "$TESTS/bison-check.log"
make install

cd /sources
rm -rf "$DIR"
echo "OK 36-bison"
