#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.43.1: Gperf-3.3.
set -euo pipefail

PKG=gperf-3.3.tar.gz
DIR=gperf-3.3
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.43.1 Installation of Gperf
./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.3
make
make check > "$TESTS/gperf-check.log" 2>&1 || echo "NOTE gperf check exited $? (see $TESTS/gperf-check.log)"
tail -n 3 "$TESTS/gperf-check.log"
make install

cd /sources
rm -rf "$DIR"
echo "OK 41-gperf"
