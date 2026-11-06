#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.35.1: Sed-4.10.
set -euo pipefail

PKG=sed-4.10.tar.xz
DIR=sed-4.10
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.35.1 Installation of Sed
./configure --prefix=/usr
make
make html
chown -R tester .
su tester -c "PATH=$PATH make check" > "$TESTS/sed-check.log" 2>&1 || echo "NOTE sed check exited $? (see $TESTS/sed-check.log)"
tail -n 3 "$TESTS/sed-check.log"
make install
install -vDm644 doc/sed.html -t /usr/share/doc/sed-4.10

cd /sources
rm -rf "$DIR"
echo "OK 33-sed"
