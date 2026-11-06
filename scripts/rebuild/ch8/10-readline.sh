#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, sections 8.12.1-8.12.2: Readline-8.3 (64-bit, then 32-bit).
# The book has no test suite for Readline.
set -euo pipefail

PKG=readline-8.3.tar.gz
DIR=readline-8.3

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.12.1 Installation of Readline
sed -i '/MV.*old/d' Makefile.in
sed -i '/{OLDSUFF}/c:' support/shlib-install
sed -i 's/-Wl,-rpath,[^ ]*//' support/shobj-conf
sed -e '270a\
   else\
     chars_avail = 1;' \
    -e '288i\   result = -1;' \
    -i.orig input.c

./configure --prefix=/usr \
            --disable-static \
            --with-curses \
            --docdir=/usr/share/doc/readline-8.3
make SHLIB_LIBS="-lncursesw"
make install
install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-8.3

# 8.12.2 Installation of Readline - 32-bit
make distclean
CC="gcc -m32" ./configure \
    --host=i686-pc-linux-gnu \
    --prefix=/usr \
    --libdir=/usr/lib32 \
    --disable-static \
    --with-curses
make SHLIB_LIBS="-lncursesw"
make DESTDIR=$PWD/DESTDIR install
cp -Rv DESTDIR/usr/lib32/* /usr/lib32
rm -rf DESTDIR

cd /sources
rm -rf "$DIR"
echo "OK 10-readline"
