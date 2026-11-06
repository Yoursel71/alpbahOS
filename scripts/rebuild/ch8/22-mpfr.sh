#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.24.1: MPFR-4.2.2.
# Critical test suite (book): all 198 tests must pass.
set -euo pipefail

PKG=mpfr-4.2.2.tar.xz
DIR=mpfr-4.2.2
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.24.1 Installation of MPFR
./configure --prefix=/usr \
            --disable-static \
            --enable-thread-safe \
            --docdir=/usr/share/doc/mpfr-4.2.2
make
make html

set +e
make check > "$TESTS/mpfr-check.log" 2>&1
rc=$?
set -e
passes=$(awk '/^# PASS:/{total+=$3} END{print total+0}' "$TESTS/mpfr-check.log")
echo "mpfr: '# PASS' total=$passes (book expects 198), make check rc=$rc"
if [ "$rc" -ne 0 ] || [ "$passes" -ne 198 ]; then
    echo "STOP: mpfr test suite did not pass completely"
    exit 1
fi
make install
make install-html

cd /sources
rm -rf "$DIR"
echo "OK 22-mpfr"
