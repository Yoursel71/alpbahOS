#!/bin/bash
# REBUILD-R4 220 sonnet-6.29.0. Sonnet needs a spell backend: the 13.1 frameworks6 page lists Aspell-0.60.8.2
# (general/aspell.html) as the dictionary backend. Aspell is not a row of the R4 list, so it is built here first,
# from the book's commands (its tarball comes from the .files line). Then the KF6 block of the frameworks6 page.
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
cd /sources/blfs-build 2>/dev/null || { mkdir -p /sources/blfs-build && cd /sources/blfs-build; }

# --- aspell 0.60.8.2 (book general/aspell.html), Sonnet backend ---
AS=aspell-0.60.8.2.tar.gz
[ -f "/sources/blfs-build/$AS" ] || { echo "KAYNAK_YOK $AS"; exit 2; }
rm -rf aspell-0.60.8.2; tar -xf "$AS"; cd aspell-0.60.8.2
# --- blok 1 ---
./configure --prefix=/usr &&
make
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 1 rc=$_rc"; exit 1; }
# --- blok 2 ---
as_root make install &&
as_root ln -svfn aspell-0.60 /usr/lib/aspell &&
as_root install -v -m755 -d /usr/share/doc/aspell-0.60.8.2/aspell{,-dev}.html &&
as_root install -v -m644 manual/aspell.html/* /usr/share/doc/aspell-0.60.8.2/aspell.html &&
as_root install -v -m644 manual/aspell-dev.html/* /usr/share/doc/aspell-0.60.8.2/aspell-dev.html
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 2 rc=$_rc"; exit 1; }
cd /sources/blfs-build && rm -rf aspell-0.60.8.2

# --- sonnet-6.29.0: KF6 block of the 13.1 frameworks6 page ---
TB="/sources/blfs-src/sonnet-6.29.0.tar.xz"; [ -f "$TB" ] || { echo "KAYNAK_YOK $TB"; exit 2; }
PKG=$(tar -tf "$TB" | sed -n 1p | cut -d/ -f1); rm -rf "$PKG"; tar -xf "$TB"; cd "$PKG"
# --- blok 3 ---
mkdir build &&
cd    build &&
cmake -D CMAKE_INSTALL_PREFIX=$KF6_PREFIX \
      -D CMAKE_INSTALL_LIBEXECDIR=libexec \
      -D CMAKE_PREFIX_PATH=$QT6DIR        \
      -D CMAKE_SKIP_INSTALL_RPATH=ON      \
      -D CMAKE_BUILD_TYPE=Release         \
      -D BUILD_TESTING=OFF                \
      -D BUILD_PYTHON_BINDINGS=OFF        \
      -W no-author .. &&
make
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 3 rc=$_rc"; exit 1; }
# --- blok 4 ---
as_root make install
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 4 rc=$_rc"; exit 1; }
as_root /sbin/ldconfig
