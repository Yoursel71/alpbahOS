#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.49.1: Automake-1.18.1.
set -euo pipefail

PKG=automake-1.18.1.tar.xz
DIR=automake-1.18.1
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.49.1 Installation of Automake
./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.18.1
make
make -j$(($(nproc)>4?$(nproc):4)) check > "$TESTS/automake-check.log" 2>&1 || echo "NOTE automake check exited $? (see $TESTS/automake-check.log)"
tail -n 3 "$TESTS/automake-check.log"
make install

cd /sources
rm -rf "$DIR"
echo "OK 47-automake"
