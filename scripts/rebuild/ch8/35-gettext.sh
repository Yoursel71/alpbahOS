#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.37.1: Gettext-1.0 (full build).
set -euo pipefail

PKG=gettext-1.0.tar.xz
DIR=gettext-1.0
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.37.1 Installation of Gettext
./configure --prefix=/usr \
            --disable-static \
            --docdir=/usr/share/doc/gettext-1.0
make
make check > "$TESTS/gettext-check.log" 2>&1 || echo "NOTE gettext check exited $? (see $TESTS/gettext-check.log)"
tail -n 3 "$TESTS/gettext-check.log"
make install
chmod -v 0755 /usr/lib/preloadable_libintl.so

cd /sources
rm -rf "$DIR"
echo "OK 35-gettext"
