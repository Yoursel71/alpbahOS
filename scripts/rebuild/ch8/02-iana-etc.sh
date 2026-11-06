#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.4: Iana-Etc-20260805 (chroot paths).
set -euo pipefail

PKG=iana-etc-20260805.tar.gz
DIR=iana-etc-20260805

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.4.1 Installation of Iana-Etc
cp -v services protocols /etc

cd /sources
rm -rf "$DIR"
echo "OK 02-iana-etc"
