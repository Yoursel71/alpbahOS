#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.74.1: Texinfo-7.3.
set -euo pipefail

PKG=texinfo-7.3.tar.xz
DIR=texinfo-7.3
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.74.1 Installation of Texinfo
./configure --prefix=/usr
make
make check > "$TESTS/texinfo-check.log" 2>&1 || echo "NOTE texinfo check exited $? (see $TESTS/texinfo-check.log)"
tail -n 3 "$TESTS/texinfo-check.log"
make install
make TEXMF=/usr/share/texmf install-tex

pushd /usr/share/info
rm -v dir
for f in *
    do install-info $f dir 2>/dev/null
done
popd

cd /sources
rm -rf "$DIR"
echo "OK 72-texinfo"
