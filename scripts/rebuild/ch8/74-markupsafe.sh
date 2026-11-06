#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.76.1: MarkupSafe-3.0.3.
set -euo pipefail

PKG=markupsafe-3.0.3.tar.gz
DIR=markupsafe-3.0.3

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.76.1 Installation of MarkupSafe
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist MarkupSafe

cd /sources
rm -rf "$DIR"
echo "OK 74-markupsafe"
