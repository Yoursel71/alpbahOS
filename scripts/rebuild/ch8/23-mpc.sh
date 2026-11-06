#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.25.1: MPC-1.4.1.
set -euo pipefail

PKG=mpc-1.4.1.tar.gz
DIR=mpc-1.4.1
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.25.1 Installation of MPC
./configure --prefix=/usr \
            --disable-static \
            --docdir=/usr/share/doc/mpc-1.4.1
make
make html
make check > "$TESTS/mpc-check.log" 2>&1 || echo "NOTE mpc check exited $? (see $TESTS/mpc-check.log)"
tail -n 3 "$TESTS/mpc-check.log"
make install
make install-html

cd /sources
rm -rf "$DIR"
echo "OK 23-mpc"
