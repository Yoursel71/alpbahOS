#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.18.1: Expect-5.45.4.
set -euo pipefail

PKG=expect5.45.4.tar.gz
DIR=expect5.45.4
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.18.1 Installation of Expect
# PTY check from the book (must print "ok").
python3 -c 'from pty import spawn; spawn(["echo", "ok"])'

patch -Np1 -i ../expect-5.45.4-gcc15-1.patch
./configure --prefix=/usr \
            --with-tcl=/usr/lib \
            --enable-shared \
            --disable-rpath \
            --mandir=/usr/share/man \
            --with-tclinclude=/usr/include
make
make test > "$TESTS/expect-test.log" 2>&1 || echo "NOTE expect test exited $? (see $TESTS/expect-test.log)"
tail -n 3 "$TESTS/expect-test.log"
make install
ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib

cd /sources
rm -rf "$DIR"
echo "OK 16-expect"
