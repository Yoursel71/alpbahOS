#!/bin/bash
# REBUILD-R4 172: font-xfree86-type1-1.0.5.tar.xz per the BLFS 13.1-systemd font loop (164 is the group leader in the generator).
set -eo pipefail
export XORG_PREFIX=/usr
export XORG_CONFIG="--prefix=$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static"
export KF6_PREFIX=/usr
as_root() { "$@"; }; export -f as_root
mkdir -p /sources/blfs-build/xorg && cd /sources/blfs-build/xorg
TB=/sources/blfs-src/font-xfree86-type1-1.0.5.tar.xz; [ -f "$TB" ] || { echo "KAYNAK_YOK $TB"; exit 2; }
packagedir=font-xfree86-type1-1.0.5
rm -rf "$packagedir"; tar -xf "$TB" || { echo "BLOK-FAIL 1 tar"; exit 1; }
pushd "$packagedir" > /dev/null
./configure $XORG_CONFIG
make
as_root make install
popd > /dev/null
rm -rf "$packagedir"
as_root /sbin/ldconfig

# --- font group post step (book block 4): TrueType font links for Fontconfig, as root ---
install -v -d -m755 /usr/share/fonts &&
ln -svfn $XORG_PREFIX/share/fonts/X11/OTF /usr/share/fonts/X11-OTF &&
ln -svfn $XORG_PREFIX/share/fonts/X11/TTF /usr/share/fonts/X11-TTF
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 4 rc=$_rc"; exit 1; }
