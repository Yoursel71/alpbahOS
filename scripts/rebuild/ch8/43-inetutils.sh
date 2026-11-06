#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.45.1: Inetutils-2.8.
set -euo pipefail

PKG=inetutils-2.8.tar.gz
DIR=inetutils-2.8
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.45.1 Installation of Inetutils
sed -i 's/def HAVE_TERMCAP_TGETENT/ 1/' telnet/telnet.c
./configure --prefix=/usr \
            --bindir=/usr/bin \
            --localstatedir=/var \
            --disable-logger \
            --disable-whois \
            --disable-rcp \
            --disable-rexec \
            --disable-rlogin \
            --disable-rsh \
            --disable-servers
make
make check > "$TESTS/inetutils-check.log" 2>&1 || echo "NOTE inetutils check exited $? (see $TESTS/inetutils-check.log)"
tail -n 3 "$TESTS/inetutils-check.log"
make install
mv -v /usr/{,s}bin/ifconfig

cd /sources
rm -rf "$DIR"
echo "OK 43-inetutils"
