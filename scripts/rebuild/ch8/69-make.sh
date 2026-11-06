#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.71.1: Make-4.4.1.
set -euo pipefail

PKG=make-4.4.1.tar.gz
DIR=make-4.4.1
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.71.1 Installation of Make
./configure --prefix=/usr
make
chown -R tester .
su tester -c "PATH=$PATH make check" > "$TESTS/make-check.log" 2>&1 || echo "NOTE make check exited $? (see $TESTS/make-check.log)"
tail -n 3 "$TESTS/make-check.log"
make install

cd /sources
rm -rf "$DIR"
echo "OK 69-make"
