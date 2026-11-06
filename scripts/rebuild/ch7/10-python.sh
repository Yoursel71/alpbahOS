#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 7, section 7.12: Python-3.14.7 (chroot paths).
set -euo pipefail

PKG=Python-3.14.7.tar.xz
DIR=Python-3.14.7

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 7.12.1 Installation of Python
./configure --prefix=/usr       \
            --enable-shared     \
            --without-ensurepip \
            --without-static-libpython
make
make install

cd /sources
rm -rf "$DIR"
echo "OK 10-python"
