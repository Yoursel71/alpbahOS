#!/bin/bash
# CONTEXT: chroot
# dracut-ng 112: the initramfs generator the M11 work used (M09 build-parameter.txt records dracut-ng 112).
# Source: https://github.com/dracut-ng/dracut-ng/archive/refs/tags/112.tar.gz, staged in /sources by the
# host step (sha256 recorded in the phase docs; no upstream signature check).
set -euo pipefail

PKG=dracut-ng-112.tar.gz
DIR=dracut-112

command -v cpio >/dev/null 2>&1 || { echo "cpio is missing: run 03-cpio.sh first" >&2; exit 1; }

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

./configure --prefix=/usr \
            --sysconfdir=/etc \
            --disable-documentation
make
make install

cd /sources
rm -rf "$DIR"

test -x /usr/bin/dracut
/usr/bin/dracut --version | head -n 1
echo "OK 04-dracut"
