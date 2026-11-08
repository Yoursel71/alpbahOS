export LANG=C LC_ALL=C
export QT6DIR=/opt/qt6
export QT6PREFIX=/opt/qt6
export PATH=/opt/qt6/bin:$PATH
export PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig:${PKG_CONFIG_PATH:-}
#!/bin/bash
set -eo pipefail
export XORG_PREFIX=/usr
export XORG_CONFIG="--prefix=$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static"
export KF6_PREFIX=/usr
as_root() { "$@"; }; export -f as_root
cd /sources/blfs-build 2>/dev/null || { mkdir -p /sources/blfs-build && cd /sources/blfs-build; }
TB="/sources/blfs-src/efivar-39.tar.gz"; [ -f "$TB" ] || { echo "KAYNAK_YOK $TB"; exit 2; }
PKG=$(tar -tf "$TB" | sed -n 1p | cut -d/ -f1); rm -rf "$PKG"; tar -xf "$TB"; cd "$PKG"

# --- blok 1 ---
# GCC 16: -Werror turns a discarded-qualifiers warning (guid.c:88, guid.c:205) into an error. Allow only that warning.
sed -i "s/-Werror /-Werror -Wno-error=discarded-qualifiers /" src/include/rules.mk &&
# GCC 16: -Werror (src/include/defaults.mk ERRORS) turns a discarded-qualifiers warning (guid.c:88, guid.c:205) into an error.
# Keep -Werror, allow only that warning.
make ENABLE_DOCS=0 ERRORS="-Werror -Wno-error=discarded-qualifiers"
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 1 rc=$_rc"; exit 1; }
# --- blok 2 ---
make install ENABLE_DOCS=0 LIBDIR=/usr/lib &&
install -vm644 docs/efivar.1 /usr/share/man/man1 &&
install -vm644 docs/*.3      /usr/share/man/man3
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 2 rc=$_rc"; exit 1; }
# --- blok 3 ---
# smoke test: pkg-config reports the installed efivar version
pkg-config --modversion efivar | grep -qx '39'
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 3 rc=$_rc"; exit 1; }
