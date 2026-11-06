#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 7, section 7.8: Bison-3.8.2 (chroot paths).
set -euo pipefail

PKG=bison-3.8.2.tar.xz
DIR=bison-3.8.2

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 7.8.1 Installation of Bison
./configure --prefix=/usr \
            --docdir=/usr/share/doc/bison-3.8.2
make
make install

cd /sources
rm -rf "$DIR"
echo "OK 06-bison"
