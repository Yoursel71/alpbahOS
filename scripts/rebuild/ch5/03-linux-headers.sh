#!/bin/bash
# Multilib LFS 13.1, Chapter 5.4 "Linux-7.1.8 API Headers"
# https://linuxfromscratch.org/mlfs/view/13.1/chapter05/linux-headers.html
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../config.sh"
lfs_guard

PKG=linux-7.1.8.tar.xz
DIR=linux-7.1.8

cd "$LFS/sources"
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

make mrproper

make headers
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include $LFS/usr

cd "$LFS/sources"
rm -rf "$DIR"

echo "OK 03-linux-headers"
