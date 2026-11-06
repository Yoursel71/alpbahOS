#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.58.1: Wheel-0.48.0.
set -euo pipefail

PKG=wheel-0.48.0.tar.gz
DIR=wheel-0.48.0

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.58.1 Installation of Wheel
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist wheel

cd /sources
rm -rf "$DIR"
echo "OK 56-wheel"
