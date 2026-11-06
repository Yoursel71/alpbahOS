#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.64.1: Findutils-4.11.0.
set -euo pipefail

PKG=findutils-4.11.0.tar.xz
DIR=findutils-4.11.0
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.64.1 Installation of Findutils
./configure --prefix=/usr --localstatedir=/var/lib/locate
make
chown -R tester .
su tester -c "PATH=$PATH make check -k" > "$TESTS/findutils-check.log" 2>&1 || echo "NOTE findutils check exited $? (see $TESTS/findutils-check.log)"
tail -n 3 "$TESTS/findutils-check.log"
make install

cd /sources
rm -rf "$DIR"
echo "OK 62-findutils"
