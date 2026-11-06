#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.19.1: DejaGNU-1.6.3.
set -euo pipefail

PKG=dejagnu-1.6.3.tar.gz
DIR=dejagnu-1.6.3
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.19.1 Installation of DejaGNU
mkdir -v build
cd build
../configure --prefix=/usr
makeinfo --html --no-split -o doc/dejagnu.html ../doc/dejagnu.texi
makeinfo --plaintext -o doc/dejagnu.txt ../doc/dejagnu.texi
make check > "$TESTS/dejagnu-check.log" 2>&1 || echo "NOTE dejagnu check exited $? (see $TESTS/dejagnu-check.log)"
tail -n 3 "$TESTS/dejagnu-check.log"
make install
install -v -dm755 /usr/share/doc/dejagnu-1.6.3
install -v -m644 doc/dejagnu.{html,txt} /usr/share/doc/dejagnu-1.6.3

cd /sources
rm -rf "$DIR"
echo "OK 17-dejagnu"
