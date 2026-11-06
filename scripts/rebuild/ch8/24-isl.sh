#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.26.1: ISL-0.28.
set -euo pipefail

PKG=isl-0.28.tar.xz
DIR=isl-0.28
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.26.1 Installation of ISL
./configure --prefix=/usr \
            --disable-static \
            --docdir=/usr/share/doc/isl-0.28
make
make check > "$TESTS/isl-check.log" 2>&1 || echo "NOTE isl check exited $? (see $TESTS/isl-check.log)"
tail -n 3 "$TESTS/isl-check.log"
make install
install -vd /usr/share/doc/isl-0.28
install -m644 doc/{CodingStyle,manual.pdf,SubmittingPatches,user.pod} \
    /usr/share/doc/isl-0.28
mkdir -pv /usr/share/gdb/auto-load/usr/lib
mv -v /usr/lib/libisl*gdb.py /usr/share/gdb/auto-load/usr/lib

cd /sources
rm -rf "$DIR"
echo "OK 24-isl"
