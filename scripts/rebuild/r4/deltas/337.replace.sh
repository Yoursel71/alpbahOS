#!/bin/bash
# REBUILD-R4 337 zsh-5.9.2: 13.1 postlfs/zsh.html. DEVIATION: --enable-pcre dropped (pcre2 is not in the 13.1 book index; no page to take its md5).
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
TB="/sources/blfs-src/zsh-5.9.2.tar.xz"; [ -f "$TB" ] || { echo "KAYNAK_YOK $TB"; exit 2; }
PKG=$(tar -tf "$TB" | sed -n 1p | cut -d/ -f1); rm -rf "$PKG"; tar -xf "$TB"; cd "$PKG"

# --- blok 1 ---
./configure --prefix=/usr            \
            --sysconfdir=/etc/zsh    \
            --enable-etcdir=/etc/zsh \
            --enable-cap             \
            --enable-gdbm &&
make &&
makeinfo  Doc/zsh.texi --html      -o Doc/html &&
makeinfo  Doc/zsh.texi --plaintext -o zsh.txt  &&
makeinfo  Doc/zsh.texi --html --no-split --no-headers -o zsh.html
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 1 rc=$_rc"; exit 1; }
# --- blok 2 ---
as_root make install &&
as_root make infodir=/usr/share/info install.info
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 2 rc=$_rc"; exit 1; }
cd /sources/blfs-build && rm -rf "$PKG"
