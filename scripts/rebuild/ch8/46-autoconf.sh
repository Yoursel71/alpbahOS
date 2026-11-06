#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.48.1: Autoconf-2.73.
set -euo pipefail

PKG=autoconf-2.73.tar.xz
DIR=autoconf-2.73
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.48.1 Installation of Autoconf
./configure --prefix=/usr
make
make check > "$TESTS/autoconf-check.log" 2>&1 || echo "NOTE autoconf check exited $? (see $TESTS/autoconf-check.log)"
tail -n 3 "$TESTS/autoconf-check.log"
make install

cd /sources
rm -rf "$DIR"
echo "OK 46-autoconf"
