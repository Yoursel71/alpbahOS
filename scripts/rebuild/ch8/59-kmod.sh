#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapters 8.61.1-8.61.2: Kmod-34.2 (64-bit, then 32-bit).
# The 32-bit cross file is passed by absolute path (the book's bare name only works from its directory).
set -euo pipefail

PKG=kmod-34.2.tar.xz
DIR=kmod-34.2

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.61.1 Installation of Kmod
mkdir -p build
cd build
meson setup --prefix=/usr \
            --buildtype=release \
            -D manpages=false \
            ..
ninja
ninja install

# 8.61.2 Installation of Kmod - 32-bit
rm -rf ./*
meson setup --prefix=/usr \
            --buildtype=release \
            --cross-file=/usr/share/meson/cross/lib32 \
            -D manpages=false \
            ..
ninja
DESTDIR=$PWD/DESTDIR ninja install
cp -Rv DESTDIR/usr/lib32/* /usr/lib32
rm -rf DESTDIR

cd /sources
rm -rf "$DIR"
echo "OK 59-kmod"
