#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.81.1: Procps-ng-4.0.7.
set -euo pipefail

PKG=procps-ng-4.0.7.tar.xz
DIR=procps-ng-4.0.7
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.81.1 Installation of Procps-ng
./configure --prefix=/usr \
            --docdir=/usr/share/doc/procps-ng-4.0.7 \
            --disable-static \
            --disable-kill \
            --enable-watch8bit \
            --with-systemd
make
chown -R tester .
su tester -c "PATH=$PATH make check" > "$TESTS/procps-ng-check.log" 2>&1 || echo "NOTE procps-ng check exited $? (book: ps bsdtime test needs BSD process accounting; see $TESTS/procps-ng-check.log)"
tail -n 3 "$TESTS/procps-ng-check.log"
make install

cd /sources
rm -rf "$DIR"
echo "OK 79-procps-ng"
