#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.62.1: Coreutils-9.11.
# Test suite (book, not critical): run as tester with the expensive tests enabled; the
# book's temporary group is used so the group-membership tests are not skipped.
set -euo pipefail

PKG=coreutils-9.11.tar.xz
DIR=coreutils-9.11
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.62.1 Installation of Coreutils
patch -Np1 -i ../coreutils-9.11-i18n-1.patch
autoreconf -fv
automake -af
FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr
make
make NON_ROOT_USERNAME=tester check-root > "$TESTS/coreutils-check-root.log" 2>&1 || echo "NOTE coreutils check-root exited $?"
tail -n 3 "$TESTS/coreutils-check-root.log"

groupadd -g 102 dummy -U tester
chown -R tester .
set +e
su tester -c "PATH=$PATH make -k RUN_EXPENSIVE_TESTS=yes check" < /dev/null > "$TESTS/coreutils-check.log" 2>&1
echo "NOTE coreutils check exited $? (see $TESTS/coreutils-check.log)"
set -e
tail -n 3 "$TESTS/coreutils-check.log"
groupdel dummy

make install
mv -v /usr/bin/chroot /usr/sbin
mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8

cd /sources
rm -rf "$DIR"
echo "OK 60-coreutils"
