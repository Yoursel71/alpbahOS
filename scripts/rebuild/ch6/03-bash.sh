#!/bin/bash
# Multilib LFS 13.1, chapter 6, section 6.4: Bash-5.3
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../config.sh"
lfs_guard

PKG=bash-5.3.tar.gz
PKG_DIR=bash-5.3

cd $LFS/sources
rm -rf $PKG_DIR
tar -xf $PKG
cd $PKG_DIR

# 6.4.1 Installation of Bash
./configure --prefix=/usr                      \
            --build=$(sh support/config.guess) \
            --host=$LFS_TGT                    \
            --without-bash-malloc              \
            --docdir=/usr/share/doc/bash-5.3

make

make DESTDIR=$LFS install

ln -sv bash $LFS/bin/sh

cd $LFS/sources && rm -rf $PKG_DIR
echo "OK 03-bash"
