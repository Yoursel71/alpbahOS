#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapters 8.23.1-8.23.2: GMP-6.3.0 (64-bit, then 32-bit).
# Critical test suite (book): 199 tests must pass in both builds.
# D146: --enable-fat with a generic x86-64 build host; no -march=native.
set -euo pipefail

PKG=gmp-6.3.0.tar.xz
DIR=gmp-6.3.0
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.23.1 Installation of GMP
sed -i '/long long t1;/,+1s/()/(...)/' configure
./configure --prefix=/usr \
            --build=x86_64-pc-linux-gnu \
            --enable-fat \
            --enable-cxx \
            --disable-static \
            --docdir=/usr/share/doc/gmp-6.3.0
make
make html

set +e
make check > "$TESTS/gmp64-check.log" 2>&1
rc=$?
set -e
pass64=$(cat $(find . -name '*.log') | grep -c '^PASS' || true)
echo "gmp 64-bit: PASS lines=$pass64 (book expects at least 199), make check rc=$rc"
if [ "$pass64" -lt 199 ]; then
    echo "STOP: gmp 64-bit did not reach 199 passing tests"
    exit 1
fi
make install
make install-html

# 8.23.2 Installation of GMP - 32-bit
make distclean
cp -v configfsf.guess config.guess
cp -v configfsf.sub config.sub
CFLAGS="-m32 -O2 -pedantic -fomit-frame-pointer -mtune=generic -march=i686" \
CXXFLAGS="$CFLAGS" \
ABI="32" \
PKG_CONFIG_PATH="/usr/lib32/pkgconfig" \
./configure --prefix=/usr \
            --host=i686-pc-linux-gnu \
            --disable-static \
            --enable-cxx \
            --libdir=/usr/lib32 \
            --includedir=/usr/include/m32/gmp
sed -i 's/$(exec_prefix)\/include/$\(includedir\)/' Makefile
make
set +e
make check 2>&1 | tee "$TESTS/gmp32-check.log"
set -e
pass32=$(awk '/# PASS:/{total+=$3} END{print total+0}' "$TESTS/gmp32-check.log")
echo "gmp 32-bit: '# PASS' total=$pass32 (book expects 199)"
if [ "$pass32" -lt 199 ]; then
    echo "STOP: gmp 32-bit did not reach 199 passing tests"
    exit 1
fi
make DESTDIR=$PWD/DESTDIR install
cp -Rv DESTDIR/usr/lib32/* /usr/lib32
cp -Rv DESTDIR/usr/include/m32/* /usr/include/m32/
rm -rf DESTDIR

cd /sources
rm -rf "$DIR"
echo "OK 21-gmp"
