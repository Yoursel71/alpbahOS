#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.69.1: Kbd-2.10.0.
set -euo pipefail

PKG=kbd-2.10.0.tar.xz
DIR=kbd-2.10.0
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.69.1 Installation of Kbd
patch -Np1 -i ../kbd-2.10.0-backspace-1.patch
sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
./configure --prefix=/usr --disable-vlock
make
make check > "$TESTS/kbd-check.log" 2>&1 || echo "NOTE kbd check exited $? (see $TESTS/kbd-check.log)"
tail -n 3 "$TESTS/kbd-check.log"
make install
cp -R -v docs/doc -T /usr/share/doc/kbd-2.10.0

cd /sources
rm -rf "$DIR"
echo "OK 67-kbd"
