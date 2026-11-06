#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 7, section 7.13: Texinfo-7.3 (chroot paths).
set -euo pipefail

PKG=texinfo-7.3.tar.xz
DIR=texinfo-7.3

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 7.13.1 Installation of Texinfo
./configure --prefix=/usr
make
make install

cd /sources
rm -rf "$DIR"
echo "OK 11-texinfo"
