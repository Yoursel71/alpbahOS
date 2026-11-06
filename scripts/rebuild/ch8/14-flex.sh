#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.16.1: Flex-2.6.4.
set -euo pipefail

PKG=flex-2.6.4.tar.gz
DIR=flex-2.6.4
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.16.1 Installation of Flex
./configure --prefix=/usr \
            --disable-static \
            --docdir=/usr/share/doc/flex-2.6.4
make
make check > "$TESTS/flex-check.log" 2>&1 || echo "NOTE flex check exited $? (see $TESTS/flex-check.log)"
tail -n 3 "$TESTS/flex-check.log"
make install
ln -sv flex /usr/bin/lex
ln -sv flex.1 /usr/share/man/man1/lex.1

cd /sources
rm -rf "$DIR"
echo "OK 14-flex"
