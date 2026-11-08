#!/bin/bash
# REBUILD-R4 077 xcb-util-wm-0.4.2: 13.1 xcb-utilities page (x/xcb-utilities.html): ./configure $XORG_CONFIG, make, make install per package, in md5 list order.
export LANG=C LC_ALL=C
set -eo pipefail
export XORG_PREFIX=/usr
export XORG_CONFIG="--prefix=$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static"
export KF6_PREFIX=/usr
as_root() { "$@"; }; export -f as_root
mkdir -p /sources/blfs-build/xorg && cd /sources/blfs-build/xorg
TB="/sources/blfs-src/xcb-util-wm-0.4.2.tar.xz"; [ -f "$TB" ] || { echo "KAYNAK_YOK $TB"; exit 2; }
packagedir=xcb-util-wm-0.4.2
rm -rf "$packagedir"; tar -xf "$TB" || { echo "BLOK-FAIL 1 tar"; exit 1; }
pushd "$packagedir" > /dev/null
./configure $XORG_CONFIG
make
as_root make install
popd > /dev/null
rm -rf "$packagedir"
as_root /sbin/ldconfig
