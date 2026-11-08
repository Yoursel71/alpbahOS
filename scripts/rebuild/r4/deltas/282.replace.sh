#!/bin/bash
# REBUILD-R4 282 libksysguard-6.7.4: one Plasma package per script (option b). Block of the 13.1 plasma-all.html
# per-package loop (cmake with BUILD_QT5=OFF, BUILD_TESTING=OFF); the page builds all in one loop.
export LANG=C LC_ALL=C
set -eo pipefail
export XORG_PREFIX=/usr
export XORG_CONFIG="--prefix=$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static"
export KF6_PREFIX=/usr
export QT6DIR=/opt/qt6
export QT6PREFIX=/opt/qt6
export PATH=/opt/qt6/bin:$PATH
export PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig:${PKG_CONFIG_PATH:-}
as_root() { "$@"; }; export -f as_root

# --- lm-sensors 3.6.2 (13.1 book general/lm-sensors.html): REQUIRED "Sensors" of this package. It is not a
# row of the R4 list (order.txt lists it as 279a), built here first from the book commands. Tarball: .files line.
LS=lm-sensors-3-6-2.tar.gz
[ -f "/sources/blfs-build/$LS" ] || { echo "KAYNAK_YOK $LS"; exit 2; }
cd /sources/blfs-build && LSD=$(tar -tf "$LS" | sed -n 1p | cut -d/ -f1); rm -rf "$LSD"; tar -xf "$LS"; cd "$LSD"
# --- lm-sensors blok 1 ---
make PREFIX=/usr        \
     BUILD_STATIC_LIB=0 \
     MANDIR=/usr/share/man
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL LS1 rc=$_rc"; exit 1; }
# --- lm-sensors blok 2 ---
as_root make PREFIX=/usr        \
     BUILD_STATIC_LIB=0 \
     MANDIR=/usr/share/man install &&
as_root install -v -m755 -d /usr/share/doc/lm-sensors-3-6-2 &&
as_root cp -rv README INSTALL doc/* /usr/share/doc/lm-sensors-3-6-2
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL LS2 rc=$_rc"; exit 1; }
as_root /sbin/ldconfig
cd /sources/blfs-build && rm -rf "$LSD"

# --- libksysguard-6.7.4 ---
cd /sources/blfs-build 2>/dev/null || { mkdir -p /sources/blfs-build && cd /sources/blfs-build; }
TB="/sources/blfs-src/libksysguard-6.7.4.tar.xz"; [ -f "$TB" ] || { echo "KAYNAK_YOK $TB"; exit 2; }
PKG=$(tar -tf "$TB" | sed -n 1p | cut -d/ -f1); rm -rf "$PKG"; tar -xf "$TB"; cd "$PKG"
# --- blok 1 ---
mkdir build &&
cd    build &&
cmake -D CMAKE_INSTALL_PREFIX=$KF6_PREFIX \
      -D CMAKE_INSTALL_LIBEXECDIR=libexec \
      -D CMAKE_BUILD_TYPE=Release         \
      -D BUILD_QT5=OFF                    \
      -D BUILD_TESTING=OFF                \
      -W no-author .. &&
make
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 1 rc=$_rc"; exit 1; }
# --- blok 2 ---
as_root make install
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 2 rc=$_rc"; exit 1; }
as_root /sbin/ldconfig
