#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.68.1: IPRoute2-7.1.0 (no test suite in the book).
set -euo pipefail

PKG=iproute2-7.1.0.tar.xz
DIR=iproute2-7.1.0

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.68.1 Installation of IPRoute2
sed -i /ARPD/d Makefile
rm -fv man/man8/arpd.8
make NETNS_RUN_DIR=/run/netns
make SBINDIR=/usr/sbin install
install -vDm644 COPYING README* -t /usr/share/doc/iproute2-7.1.0

cd /sources
rm -rf "$DIR"
echo "OK 66-iproute2"
