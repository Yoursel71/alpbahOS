#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.57.1: Packaging-26.3.
set -euo pipefail

PKG=packaging-26.3.tar.gz
DIR=packaging-26.3

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.57.1 Installation of Packaging
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist packaging

cd /sources
rm -rf "$DIR"
echo "OK 55-packaging"
