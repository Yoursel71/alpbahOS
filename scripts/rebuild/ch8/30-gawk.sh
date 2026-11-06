#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.32.1: Gawk-5.4.1.
set -euo pipefail

PKG=gawk-5.4.1.tar.xz
DIR=gawk-5.4.1
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.32.1 Installation of Gawk
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr
make
chown -R tester .
su tester -c "PATH=$PATH make check" > "$TESTS/gawk-check.log" 2>&1 || echo "NOTE gawk check exited $? (see $TESTS/gawk-check.log)"
tail -n 3 "$TESTS/gawk-check.log"
rm -f /usr/bin/gawk-5.4.1
make install
ln -sv gawk.1 /usr/share/man/man1/awk.1
install -vDm644 doc/{awkforai.txt,*.{eps,pdf,jpg}} -t /usr/share/doc/gawk-5.4.1

cd /sources
rm -rf "$DIR"
echo "OK 30-gawk"
