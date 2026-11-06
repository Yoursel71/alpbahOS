#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 7, sections 7.14.1-7.14.2: Util-linux-2.42.2 (64-bit, then 32-bit).
set -euo pipefail

PKG=util-linux-2.42.2.tar.xz
DIR=util-linux-2.42.2

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 7.14.1 Installation of Util-linux
mkdir -pv /var/lib/hwclock
./configure --libdir=/usr/lib     \
            --runstatedir=/run    \
            --disable-chfn-chsh   \
            --disable-login       \
            --disable-nologin     \
            --disable-su          \
            --disable-setpriv     \
            --disable-runuser     \
            --disable-pylibmount  \
            --disable-static      \
            --disable-liblastlog2 \
            --without-python      \
            ADJTIME_PATH=/var/lib/hwclock/adjtime \
            --docdir=/usr/share/doc/util-linux-2.42.2
make
make install

# 7.14.2 Installation of Util-linux - 32-bit
make distclean
CC="gcc -m32"                        \
./configure --host=i686-pc-linux-gnu \
            --libdir=/usr/lib32      \
            --runstatedir=/run       \
            --disable-chfn-chsh      \
            --disable-login          \
            --disable-nologin        \
            --disable-su             \
            --disable-setpriv        \
            --disable-runuser        \
            --disable-pylibmount     \
            --disable-static         \
            --disable-liblastlog2    \
            --without-python         \
            ADJTIME_PATH=/var/lib/hwclock/adjtime
make
make DESTDIR=$PWD/DESTDIR install
cp -Rv DESTDIR/usr/lib32/* /usr/lib32

cd /sources
rm -rf "$DIR"
echo "OK 12-util-linux"
