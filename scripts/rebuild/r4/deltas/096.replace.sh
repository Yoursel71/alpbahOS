#!/bin/bash
# REBUILD-R4 096: libXfont2-2.0.9.tar.xz per the BLFS 13.1-systemd lib loop (079 is the group leader in the generator).
set -eo pipefail
export XORG_PREFIX=/usr
export XORG_CONFIG="--prefix=$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static"
export KF6_PREFIX=/usr
as_root() { "$@"; }; export -f as_root
mkdir -p /sources/blfs-build/xorg && cd /sources/blfs-build/xorg
TB=/sources/blfs-src/libXfont2-2.0.9.tar.xz; [ -f "$TB" ] || { echo "KAYNAK_YOK $TB"; exit 2; }
packagedir=libXfont2-2.0.9
rm -rf "$packagedir"; tar -xf "$TB" || { echo "BLOK-FAIL 1 tar"; exit 1; }
pushd "$packagedir" > /dev/null
docdir="--docdir=$XORG_PREFIX/share/doc/$packagedir"
./configure $XORG_CONFIG $docdir --disable-devel-docs
make
as_root make install
popd > /dev/null
rm -rf "$packagedir"
as_root /sbin/ldconfig
