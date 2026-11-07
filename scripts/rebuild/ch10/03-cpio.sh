#!/bin/bash
# CONTEXT: chroot
# cpio 2.15 for dracut. cpio is a BLFS package, not in the MLFS 13.1 book, and the chroot has no cpio.
# Source: https://ftp.gnu.org/gnu/cpio/cpio-2.15.tar.bz2, staged in /sources by the host step
# (sha256 is recorded in the phase docs; the GNU signature was not checked).
set -euo pipefail

PKG=cpio-2.15.tar.bz2
DIR=cpio-2.15

if command -v cpio >/dev/null 2>&1; then
    echo "cpio already present: $(cpio --version | head -n 1)"
    echo "OK 03-cpio"
    exit 0
fi

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# GCC 15 defaults to C23, where an empty () declaration means (void); cpio 2.15 (gnulib) then fails
# with "too many arguments to function xstat". -std=gnu17 restores the old declarations. No CPU flags.
CFLAGS="-O2 -std=gnu17" ./configure --prefix=/usr \
            --bindir=/usr/bin \
            --enable-mt \
            --with-rmt=/usr/libexec/rmt
make
make install

cd /sources
rm -rf "$DIR"

cpio --version | head -n 1
echo "OK 03-cpio"
