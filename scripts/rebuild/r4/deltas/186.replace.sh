#!/bin/bash
# REBUILD-R4 186 gdk-pixbuf-2.44.7: meson options of the BLFS 13.1-systemd page (x/gdk-pixbuf.html); glycin disabled when not installed, as the page says.
# man=false: docutils (the page recommends docutils-0.23 for man pages) is not in the R4 list; the man option is turned off.
export LANG=C LC_ALL=C
set -eo pipefail
export XORG_PREFIX=/usr
export XORG_CONFIG="--prefix=$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static"
export KF6_PREFIX=/usr
as_root() { "$@"; }; export -f as_root
cd /sources/blfs-build 2>/dev/null || { mkdir -p /sources/blfs-build && cd /sources/blfs-build; }
TB="/sources/blfs-src/gdk-pixbuf-2.44.7.tar.xz"; [ -f "$TB" ] || { echo "KAYNAK_YOK $TB"; exit 2; }
PKG=$(tar -tf "$TB" | sed -n 1p | cut -d/ -f1); rm -rf "$PKG"; tar -xf "$TB"; cd "$PKG"

# --- blok 1 ---
# Install Gdk Pixbuf by running the following commands:
mkdir build &&
cd    build &&

meson setup ..                \
      --prefix=/usr           \
      --buildtype=release     \
      -D png=disabled         \
      -D gif=disabled         \
      -D jpeg=disabled        \
      -D tiff=disabled        \
      -D thumbnailer=disabled \
      -D man=false            \
      --wrap-mode=nofallback  \
      $(pkgconf glycin-2 || echo -D glycin=disabled) &&
ninja
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 1 rc=$_rc"; exit 1; }
# --- blok 2 ---
# Now, as the root user:
ninja install
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 2 rc=$_rc"; exit 1; }

