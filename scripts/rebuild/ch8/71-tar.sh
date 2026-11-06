#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.73.1: Tar-1.35.
set -euo pipefail

PKG=tar-1.35.tar.xz
DIR=tar-1.35
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.73.1 Installation of Tar
patch -Np1 -i ../tar-1.35-acl_fix-1.patch
FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr
make
make check > "$TESTS/tar-check.log" 2>&1 || echo "NOTE tar check exited $? (see $TESTS/tar-check.log)"
tail -n 3 "$TESTS/tar-check.log"
make install
make -C doc install-html docdir=/usr/share/doc/tar-1.35

cd /sources
rm -rf "$DIR"
echo "OK 71-tar"
