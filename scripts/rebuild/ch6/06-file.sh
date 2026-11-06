#!/bin/bash
# Multilib LFS 13.1, chapter 6, section 6.7: File-5.48
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../config.sh"
lfs_guard

PKG=file-5.48.tar.gz
PKG_DIR=file-5.48

cd $LFS/sources
rm -rf $PKG_DIR
tar -xf $PKG
cd $PKG_DIR

# 6.7.1 Installation of File
# Temporary host-version file command (needed to create the signature file)
mkdir build
pushd build
  ../configure --disable-bzlib      \
               --disable-libseccomp \
               --disable-xzlib      \
               --disable-zlib
  make
popd

./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)

make FILE_COMPILE=$(pwd)/build/src/file

make DESTDIR=$LFS install

rm -v $LFS/usr/lib/libmagic.la

cd $LFS/sources && rm -rf $PKG_DIR
echo "OK 06-file"
