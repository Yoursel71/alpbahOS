#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.39.1: Grep-3.12.
set -euo pipefail

PKG=grep-3.12.tar.xz
DIR=grep-3.12
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.39.1 Installation of Grep
sed -i "s/echo/#echo/" src/egrep.sh
./configure --prefix=/usr
make
make check > "$TESTS/grep-check.log" 2>&1 || echo "NOTE grep check exited $? (see $TESTS/grep-check.log)"
tail -n 3 "$TESTS/grep-check.log"
make install

cd /sources
rm -rf "$DIR"
echo "OK 37-grep"
