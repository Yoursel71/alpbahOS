#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.65.1: Groff-1.24.1.
# PAGE=A4 is the paper size used for this project (the book leaves <paper_size> to the builder).
set -euo pipefail

PKG=groff-1.24.1.tar.gz
DIR=groff-1.24.1
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.65.1 Installation of Groff
PAGE=A4 ./configure --prefix=/usr
make -j1
make check > "$TESTS/groff-check.log" 2>&1 || echo "NOTE groff check exited $? (see $TESTS/groff-check.log)"
tail -n 3 "$TESTS/groff-check.log"
make install

cd /sources
rm -rf "$DIR"
echo "OK 63-groff"
