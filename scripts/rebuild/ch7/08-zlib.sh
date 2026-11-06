#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 7, section 7.10: Zlib-1.3.2 (chroot paths).
set -euo pipefail

PKG=zlib-1.3.2.tar.gz
DIR=zlib-1.3.2

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 7.10.1 Installation of Zlib
./configure --prefix=/usr
make
make install

# The static library is not needed in the final system.
rm -fv /usr/lib/libz.a

cd /sources
rm -rf "$DIR"
echo "OK 08-zlib"
