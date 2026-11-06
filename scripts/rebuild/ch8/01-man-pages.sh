#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.3: Man-pages-6.18 (chroot paths).
set -euo pipefail

PKG=man-pages-6.18.tar.xz
DIR=man-pages-6.18

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.3.1 Installation of Man-pages
rm -v man3/crypt*
make -R GIT=false prefix=/usr install

cd /sources
rm -rf "$DIR"
echo "OK 01-man-pages"
