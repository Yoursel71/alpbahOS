#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.77.1: Jinja2-3.1.6.
set -euo pipefail

PKG=jinja2-3.1.6.tar.gz
DIR=jinja2-3.1.6

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.77.1 Installation of Jinja2
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist Jinja2

cd /sources
rm -rf "$DIR"
echo "OK 75-jinja2"
