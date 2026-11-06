#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.70.1: Libpipeline-1.5.8.
# The book's tests need the Check library, which is not in LFS: not run.
set -euo pipefail

PKG=libpipeline-1.5.8.tar.gz
DIR=libpipeline-1.5.8

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.70.1 Installation of Libpipeline
./configure --prefix=/usr
make
make install

cd /sources
rm -rf "$DIR"
echo "OK 68-libpipeline"
