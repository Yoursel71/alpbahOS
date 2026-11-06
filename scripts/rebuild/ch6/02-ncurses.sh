#!/bin/bash
# Multilib LFS 13.1, chapter 6, section 6.3: Ncurses-6.6
# Builds the 64-bit library (6.3.1) and then the 32-bit library (6.3.2).
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../config.sh"
lfs_guard

PKG=ncurses-6.6.tar.gz
PKG_DIR=ncurses-6.6

cd $LFS/sources
rm -rf $PKG_DIR
tar -xf $PKG
cd $PKG_DIR

# 6.3.1 Installation of Ncurses
mkdir build
pushd build
  ../configure --prefix=$LFS/tools AWK=gawk
  make -C include
  make -C progs tic
  install progs/tic $LFS/tools/bin
popd

./configure --prefix=/usr                \
            --host=$LFS_TGT              \
            --build=$(./config.guess)    \
            --mandir=/usr/share/man      \
            --with-manpage-format=normal \
            --with-shared                \
            --without-normal             \
            --with-cxx-shared            \
            --without-debug              \
            --without-ada                \
            --disable-stripping          \
            AWK=gawk

make

make DESTDIR=$LFS install
ln -sv libncursesw.so $LFS/usr/lib/libncurses.so
sed -e 's/^#if.*XOPEN.*$/#if 1/' \
    -i $LFS/usr/include/curses.h

# 6.3.2 Building Ncurses - 32-bit
make distclean

CC="$LFS_TGT-gcc -m32"                \
CXX="$LFS_TGT-g++ -m32"               \
./configure --prefix=/usr             \
            --host=$LFS_TGT32         \
            --build=$(./config.guess) \
            --libdir=/usr/lib32       \
            --mandir=/usr/share/man   \
            --with-shared             \
            --without-normal          \
            --with-cxx-shared         \
            --without-debug           \
            --without-ada             \
            --disable-stripping

make

make DESTDIR=$PWD/DESTDIR TIC_PATH=$(pwd)/build/progs/tic install
ln -sv libncursesw.so DESTDIR/usr/lib32/libncurses.so
cp -Rv DESTDIR/usr/lib32/* $LFS/usr/lib32
rm -rf DESTDIR

cd $LFS/sources && rm -rf $PKG_DIR
echo "OK 02-ncurses"
