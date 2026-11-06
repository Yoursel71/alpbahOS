#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 7, section 7.7: Gettext-1.0 (chroot paths).
set -euo pipefail

PKG=gettext-1.0.tar.xz
DIR=gettext-1.0

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 7.7.1 Installation of Gettext
./configure --disable-shared
make
cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin

cd /sources
rm -rf "$DIR"
echo "OK 05-gettext"
