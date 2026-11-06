#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapters 8.82.1-8.82.2: Util-linux-2.42.2 (64-bit, then 32-bit).
# Test suite (book): run as tester; the scsi_debug test is run after boot (book) and is not run here.
set -euo pipefail

PKG=util-linux-2.42.2.tar.xz
DIR=util-linux-2.42.2
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.82.1 Installation of Util-linux
./configure --bindir=/usr/bin \
            --libdir=/usr/lib \
            --runstatedir=/run \
            --sbindir=/usr/sbin \
            --disable-chfn-chsh \
            --disable-login \
            --disable-nologin \
            --disable-su \
            --disable-setpriv \
            --disable-runuser \
            --disable-pylibmount \
            --disable-liblastlog2 \
            --disable-static \
            --without-python \
            ADJTIME_PATH=/var/lib/hwclock/adjtime \
            --docdir=/usr/share/doc/util-linux-2.42.2
make

# Book: a dummy /etc/fstab satisfies two tests.
touch /etc/fstab
chown -R tester .
su tester -c "make -k check" > "$TESTS/util-linux-check.log" 2>&1 || echo "NOTE util-linux check exited $? (see $TESTS/util-linux-check.log)"
tail -n 3 "$TESTS/util-linux-check.log"

make install
make distclean

# Book: move a tool out of the way that configure would otherwise use for multilib builds.
mv /usr/bin/ncursesw6-config{,.tmp}
CC="gcc -m32" \
./configure --host=i686-pc-linux-gnu \
            --libdir=/usr/lib32 \
            --runstatedir=/run \
            --sbindir=/usr/sbin \
            --disable-chfn-chsh \
            --disable-login \
            --disable-nologin \
            --disable-su \
            --disable-setpriv \
            --disable-runuser \
            --disable-pylibmount \
            --disable-liblastlog2 \
            --disable-static \
            --without-python \
            ADJTIME_PATH=/var/lib/hwclock/adjtime
mv /usr/bin/ncursesw6-config{.tmp,}
make
make DESTDIR=$PWD/DESTDIR install
cp -Rv DESTDIR/usr/lib32/* /usr/lib32
rm -rf DESTDIR

cd /sources
rm -rf "$DIR"
echo "OK 80-util-linux"
