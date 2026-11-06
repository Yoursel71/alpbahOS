#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapters 8.79.1-8.79.2: D-Bus-1.16.2 (64-bit, then 32-bit).
# Test suite (book, not critical): the book's comprehensive tests are in BLFS; the core tests run here.
set -euo pipefail

PKG=dbus-1.16.2.tar.xz
DIR=dbus-1.16.2
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.79.1 Installation of D-Bus
mkdir build
cd build
meson setup --prefix=/usr --buildtype=release --wrap-mode=nofallback ..
ninja
ninja test > "$TESTS/dbus-test.log" 2>&1 || echo "NOTE dbus test exited $? (see $TESTS/dbus-test.log)"
tail -n 3 "$TESTS/dbus-test.log"
ninja install
ln -sfv /etc/machine-id /var/lib/dbus
rm -rf ./*

# 8.79.2 Installation of D-Bus - 32-bit
meson setup --prefix=/usr \
            --buildtype=release \
            --cross-file=/usr/share/meson/cross/lib32 \
            --wrap-mode=nofallback \
            ..
ninja
DESTDIR=$(pwd)/destdir ninja install
mkdir -pv /usr/lib32/pkgconfig
cp -av $(pwd)/destdir/usr/lib32/libdbus-1.so* /usr/lib32/
cp -av $(pwd)/destdir/usr/lib32/dbus-1.0 /usr/lib32/
cp -v $(pwd)/destdir/usr/lib32/pkgconfig/dbus-1.pc /usr/lib32/pkgconfig/
rm -rf destdir

cd /sources
rm -rf "$DIR"
echo "OK 77-dbus"
