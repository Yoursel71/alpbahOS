#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, sections 8.34.1-8.34.2: Ncurses-6.6 (wide-character, 64-bit, then 32-bit).
# The book's optional ABI 5 (narrow) libraries for binary-only applications are not built.
set -euo pipefail

PKG=ncurses-6.6.tar.gz
DIR=ncurses-6.6

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.34.1 Installation of Ncurses
./configure --prefix=/usr \
            --mandir=/usr/share/man \
            --with-shared \
            --without-debug \
            --without-normal \
            --with-cxx-shared \
            --enable-pc-files \
            --with-pkg-config-libdir=/usr/lib/pkgconfig
make

# Install into DESTDIR first so the running shell's libraries are not overwritten in place (book).
make DESTDIR=$PWD/dest install
sed -e 's/^#if.*XOPEN.*$/#if 1/' \
    -i dest/usr/include/curses.h
cp --remove-destination -av dest/* /

for lib in ncurses form panel menu ; do
    ln -sfv lib${lib}w.so /usr/lib/lib${lib}.so
    ln -sfv ${lib}w.pc /usr/lib/pkgconfig/${lib}.pc
done
ln -sfv libncursesw.so /usr/lib/libcurses.so
cp -v -R doc -T /usr/share/doc/ncurses-6.6

# 8.34.2 Building Ncurses - 32-bit
make distclean
CC="gcc -m32" CXX="g++ -m32" \
./configure --prefix=/usr \
            --host=i686-pc-linux-gnu \
            --libdir=/usr/lib32 \
            --mandir=/usr/share/man \
            --with-shared \
            --without-debug \
            --without-normal \
            --with-cxx-shared \
            --enable-pc-files \
            --with-pkg-config-libdir=/usr/lib32/pkgconfig
make
make DESTDIR=$PWD/DESTDIR install
mkdir -p DESTDIR/usr/lib32/pkgconfig
for lib in ncurses form panel menu ; do
    rm -vf DESTDIR/usr/lib32/lib${lib}.so
    echo "INPUT(-l${lib}w)" > DESTDIR/usr/lib32/lib${lib}.so
    ln -svf ${lib}w.pc DESTDIR/usr/lib32/pkgconfig/$lib.pc
done
rm -vf DESTDIR/usr/lib32/libcursesw.so
echo "INPUT(-lncursesw)" > DESTDIR/usr/lib32/libcursesw.so
ln -sfv libncurses.so DESTDIR/usr/lib32/libcurses.so
cp -Rv DESTDIR/usr/lib32/* /usr/lib32
rm -rf DESTDIR

cd /sources
rm -rf "$DIR"
echo "OK 32-ncurses"
