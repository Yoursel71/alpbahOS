#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.56.1: Flit-Core-4.0.2 (pip wheel, no build isolation).
set -euo pipefail

PKG=flit_core-4.0.2.tar.gz
DIR=flit_core-4.0.2

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.56.1 Installation of Flit-Core
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist flit_core

cd /sources
rm -rf "$DIR"
echo "OK 54-flit-core"
