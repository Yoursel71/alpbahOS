#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.24.1: MPFR-4.2.2.
# Critical test suite (book): all 198 tests must pass.
# REBUILD-R3: derived from ch8/22-mpfr.sh by deleting its test gate (lines 25-38). The gate runs as ch08-31b, after GCC.
set -euo pipefail

PKG=mpfr-4.2.2.tar.xz
DIR=mpfr-4.2.2
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.24.1 Installation of MPFR
./configure --prefix=/usr \
            --disable-static \
            --enable-thread-safe \
            --docdir=/usr/share/doc/mpfr-4.2.2
make
make html

make install
make install-html

cd /sources
rm -rf "$DIR"
echo "OK 22-mpfr"
