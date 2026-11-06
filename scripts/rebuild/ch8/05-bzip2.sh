#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, sections 8.7.1-8.7.2: Bzip2-1.0.8 (64-bit, then 32-bit).
set -euo pipefail

PKG=bzip2-1.0.8.tar.gz
DIR=bzip2-1.0.8

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.7.1 Installation of Bzip2
patch -Np1 -i ../bzip2-1.0.8-install_docs-1.patch
sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile

make -f Makefile-libbz2_so
make clean

make
make PREFIX=/usr install

cp -av libbz2.so.* /usr/lib
ln -sfv libbz2.so.1.0.8 /usr/lib/libbz2.so
ln -sfv libbz2.so.1.0.8 /usr/lib/libbz2.so.1

cp -v bzip2-shared /usr/bin/bzip2
for i in /usr/bin/{bzcat,bunzip2}; do
    ln -sfv bzip2 $i
done

rm -fv /usr/lib/libbz2.a

# 8.7.2 Installation of Bzip2 - 32-bit
make clean
make -f Makefile-libbz2_so clean
sed -e "s/^CC=.*/CC=gcc -m32/" -i Makefile{,-libbz2_so}
make -f Makefile-libbz2_so
install -Dm755 libbz2.so.1.0.8 /usr/lib32/libbz2.so.1.0.8
ln -svf libbz2.so.1.0.8 /usr/lib32/libbz2.so
ln -svf libbz2.so.1.0.8 /usr/lib32/libbz2.so.1
ln -svf libbz2.so.1.0.8 /usr/lib32/libbz2.so.1.0

cd /sources
rm -rf "$DIR"
echo "OK 05-bzip2"
