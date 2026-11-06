#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.22.1: Binutils-2.47 (final).
# Critical test suite (book): make -k check. Only the book's gprofng failure is tolerated.
set -euo pipefail

PKG=binutils-2.47.tar.xz
DIR=binutils-2.47
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.22.1 Installation of Binutils
mkdir -v build
cd build
../configure --prefix=/usr \
             --sysconfdir=/etc \
             --enable-ld=default \
             --enable-plugins \
             --enable-shared \
             --disable-werror \
             --enable-64-bit-bfd \
             --enable-new-dtags \
             --with-system-zlib \
             --with-lib-path=/usr/lib \
             --enable-default-hash-style=gnu
make tooldir=/usr

# Critical test suite. -k keeps going so every failure is listed.
chown -R tester /sources/$DIR
set +e
su tester -c "PATH=$PATH make -k check" > "$TESTS/binutils-check.log" 2>&1
set -e
grep -h '^FAIL:' $(find . -name '*.log') 2>/dev/null | sort -u | tee "$TESTS/binutils-fails.txt" || true
unexpected=$(grep -v -i 'gprofng' "$TESTS/binutils-fails.txt" 2>/dev/null || true)
if [ -n "$unexpected" ]; then
    echo "STOP: binutils test failures outside the book's list (gprofng):"
    echo "$unexpected"
    exit 1
fi
echo "binutils check: only the book's gprofng failure(s) (or none)"

make tooldir=/usr install
rm -rfv /usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a \
        /usr/share/doc/gprofng/

cd /sources
rm -rf "$DIR"
echo "OK 20-binutils"
