#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 7, section 7.11: mpdecimal-4.0.1 (chroot paths).
set -euo pipefail

PKG=mpdecimal-4.0.1.tar.gz
DIR=mpdecimal-4.0.1

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 7.11.1 Installation of mpdecimal
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/mpdecimal-4.0.1
make
make install

cd /sources
rm -rf "$DIR"
echo "OK 09-mpdecimal"
