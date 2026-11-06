#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.46.1: Less-704.
set -euo pipefail

PKG=less-704.tar.gz
DIR=less-704
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.46.1 Installation of Less
./configure --prefix=/usr --sysconfdir=/etc
make
make check > "$TESTS/less-check.log" 2>&1 || echo "NOTE less check exited $? (see $TESTS/less-check.log)"
tail -n 3 "$TESTS/less-check.log"
make install

cd /sources
rm -rf "$DIR"
echo "OK 44-less"
