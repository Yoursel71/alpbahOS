#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.59.1: Setuptools-84.0.0.
set -euo pipefail

PKG=setuptools-84.0.0.tar.gz
DIR=setuptools-84.0.0

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.59.1 Installation of Setuptools
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist setuptools

cd /sources
rm -rf "$DIR"
echo "OK 57-setuptools"
