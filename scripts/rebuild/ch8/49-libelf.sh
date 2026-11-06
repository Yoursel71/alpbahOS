#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapters 8.51.1-8.51.2: Libelf from Elfutils-0.195 (64-bit, then 32-bit).
set -euo pipefail

PKG=elfutils-0.195.tar.bz2
DIR=elfutils-0.195
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.51.1 Installation of Libelf
./configure --prefix=/usr \
            --disable-debuginfod \
            --enable-libdebuginfod=dummy
make -C lib
make -C libelf
make -k check > "$TESTS/elfutils-check.log" 2>&1 || echo "NOTE elfutils check exited $? (see $TESTS/elfutils-check.log)"
tail -n 3 "$TESTS/elfutils-check.log"
make -C libelf install
install -vm644 config/libelf.pc /usr/lib/pkgconfig
rm /usr/lib/libelf.a

# 8.51.2 Installation of Libelf - 32-bit
make distclean
# --disable-demangler: the 32-bit C++ demangler test fails to link because ld -m32 does not search
# /usr/lib32 for DT_NEEDED libraries (binutils --with-lib-path=/usr/lib; BACKLOG item). Only libelf is
# installed from this build, so the demangler is not part of the installed files.
CC="gcc -m32" CXX="g++ -m32" \
./configure --prefix=/usr \
            --libdir=/usr/lib32 \
            --host=i686-pc-linux-gnu \
            --disable-debuginfod \
            --enable-libdebuginfod=dummy \
            --disable-demangler
make -C lib
make -C libelf
make DESTDIR=$PWD/DESTDIR -C libelf install
install -vDm644 config/libelf.pc DESTDIR/usr/lib32/pkgconfig/libelf.pc
rm -vf DESTDIR/usr/lib32/libelf.a
cp -Rv DESTDIR/usr/lib32/* /usr/lib32
rm -rf DESTDIR

cd /sources
rm -rf "$DIR"
echo "OK 49-libelf"
