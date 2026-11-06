#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.36.1: Psmisc-23.7.
set -euo pipefail

PKG=psmisc-23.7.tar.xz
DIR=psmisc-23.7
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.36.1 Installation of Psmisc
./configure --prefix=/usr
make
make check > "$TESTS/psmisc-check.log" 2>&1 || echo "NOTE psmisc check exited $? (see $TESTS/psmisc-check.log)"
tail -n 3 "$TESTS/psmisc-check.log"
make install

cd /sources
rm -rf "$DIR"
echo "OK 34-psmisc"
