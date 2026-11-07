#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapters 8.78.1-8.78.2: Systemd-261.2 (64-bit, then 32-bit).
# Test suite: the book's test run needs /etc/os-release set to "Linux From Scratch". The file is
# backed up and restored afterwards when it existed before. Some tests fail in the chroot (book).
set -euo pipefail

PKG=systemd-261.2.tar.gz
DIR=systemd-261.2
MANPKG=systemd-man-pages-261.2.tar.xz
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.78.1 Installation of Systemd
sed -e 's/GROUP="render"/GROUP="video"/' \
    -e 's/GROUP="sgx", //' \
    -i rules.d/50-udev-default.rules.in

mkdir -p build
cd build
meson setup .. \
      --prefix=/usr \
      --buildtype=release \
      -D default-dnssec=no \
      -D firstboot=false \
      -D install-tests=false \
      -D ldconfig=false \
      -D sysusers=false \
      -D rpmmacrosdir=no \
      -D homed=disabled \
      -D man=disabled \
      -D mode=release \
      -D pamconfdir=no \
      -D dev-kvm-mode=0660 \
      -D nobody-group=nogroup \
      -D sysupdate=disabled \
      -D ukify=disabled \
      -D docdir=/usr/share/doc/systemd-261.2
ninja

# Test suite (book): os-release is needed by some tests; keep a copy of the existing file.
if [ -f /etc/os-release ]; then cp -a /etc/os-release "$TESTS/os-release.before-systemd-test"; fi
echo 'NAME="Linux From Scratch"' > /etc/os-release
# Book command is "unshare -m ninja test" (LFS 13.1-systemd, chapter 8, systemd). Inside the chroot
# that unshare fails: "unshare: cannot change root filesystem propagation: Invalid argument" (SYSTEMD-CH8-TESTS).
# The runner is started as "unshare -m --propagation private run-chroot.sh", so the tests already run in a
# private mount namespace and the inner unshare is dropped here.
ninja test > "$TESTS/systemd-test.log" 2>&1 || echo "NOTE systemd test exited $? (book: some tests fail in the chroot; see $TESTS/systemd-test.log)"
tail -n 3 "$TESTS/systemd-test.log"
if [ -f "$TESTS/os-release.before-systemd-test" ]; then
    cp -a "$TESTS/os-release.before-systemd-test" /etc/os-release
fi

ninja install
tar -xf /sources/$MANPKG --no-same-owner --strip-components=1 -C /usr/share/man
systemd-machine-id-setup
systemctl preset-all

# 8.78.2 Installation of Systemd - 32-bit
rm -rf ./*
LANG=en_US.UTF-8 \
meson setup --prefix=/usr \
            --buildtype=release \
            --cross-file=/usr/share/meson/cross/lib32 \
            -D default-dnssec=no \
            -D firstboot=false \
            -D install-tests=false \
            -D ldconfig=false \
            -D sysusers=false \
            -D rpmmacrosdir=no \
            -D homed=disabled \
            -D userdb=false \
            -D man=disabled \
            -D mode=release \
            -D nobody-group=nogroup \
            -D sysupdate=disabled \
            -D ukify=disabled \
            ..
LANG=en_US.UTF-8 ninja
LANG=en_US.UTF-8 DESTDIR=$PWD/DESTDIR ninja install
cp -av DESTDIR/usr/lib32/libsystemd.so* /usr/lib32/
cp -av DESTDIR/usr/lib32/libudev.so* /usr/lib32/
cp -v DESTDIR/usr/lib32/pkgconfig/* /usr/lib32/pkgconfig/
rm -rf DESTDIR

cd /sources
rm -rf "$DIR"
echo "OK 76-systemd"
