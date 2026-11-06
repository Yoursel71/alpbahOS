#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.33.1: GCC-16.2.0 (final, C and C++, multilib m64 and m32).
# Important test suite (book): make -k check. The failures listed in the book are tolerated;
# any other FAIL line stops this script (stop and investigate).
set -euo pipefail

PKG=gcc-16.2.0.tar.xz
DIR=gcc-16.2.0
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.33.1 Installation of GCC
sed -e '/m64=/s/lib64/lib/' \
    -e '/m32=/s/m32=.*/m32=..\/lib32$(call if_multiarch,:i386-linux-gnu)/' \
    -i.orig gcc/config/i386/t-linux64

# Make -mstackrealign a default for 32-bit objects (book).
sed '/STACK_REALIGN_DEFAULT/s/0/(!TARGET_64BIT \&\& TARGET_SSE)/' \
    -i gcc/config/i386/i386.h

mkdir -v build
cd build
../configure --prefix=/usr \
             LD=ld \
             --enable-languages=c,c++ \
             --enable-default-pie \
             --enable-default-ssp \
             --enable-host-pie \
             --enable-multilib \
             --with-multilib-list=m64,m32 \
             --disable-bootstrap \
             --disable-fixincludes \
             --with-system-zlib
make

# Important test suite. Run as the unprivileged tester user, keep going on errors.
ulimit -s -H unlimited
chown -R tester .
set +e
su tester -c "PATH=$PATH make -k check" > "$TESTS/gcc-check.log" 2>&1
rc=$?
set -e
echo "gcc make -k check rc=$rc"
../contrib/test_summary -t > "$TESTS/gcc-test-summary.txt" 2>&1 || true
tail -n 40 "$TESTS/gcc-test-summary.txt"
grep -h '^FAIL:' $(find . -name '*.sum') 2>/dev/null | sort -u > "$TESTS/gcc-fails.txt" || true
echo "gcc: FAIL lines: $(wc -l < "$TESTS/gcc-fails.txt")"

KNOWN='gcc\.target/i386/(auto-init-padding-9|builtin-memmove-|mem(cpy|set)-pr120683-|pr111657-1|pr115102|pr116896|pr120881-2a|pr122343-4a|shift-gf2p8affine-2)|g\+\+\.target/i386/(memset-pr108585-1[ab]|mvc?-symbols|pr112824-2|pr116896-1)|gcc\.dg/ipa/pr122458|gcc\.dg/lto/toplevel-.*-asm-|gcc\.dg/plugin/crash-test-nested-|g\+\+\.dg/gomp/deprecate-1'
unexpected=$(grep -v -E "$KNOWN" "$TESTS/gcc-fails.txt" || true)
if [ -n "$unexpected" ]; then
    echo "STOP: gcc test failures outside the book's list:"
    echo "$unexpected"
    exit 1
fi
echo "gcc check: every FAIL is in the book's known list (or there are none)"

make install

# Book: header ownership and the cpp/cc/plugin links.
chown -v -R root:root $(gcc -print-file-name=include){,-fixed}
ln -svr /usr/bin/cpp /usr/lib
ln -sv gcc.1 /usr/share/man/man1/cc.1
ln -sfvr $(gcc -print-prog-name=liblto_plugin.so) /usr/lib/bfd-plugins/

# Sanity checks (book): the new toolchain finds crt files, libc and the dynamic linker.
cd /root
echo 'int main(){}' | cc -x c - -v -Wl,--verbose &> dummy.log
readelf -l a.out | grep ': /lib' | tee /root/ch8-tests/gcc-sanity-readelf.txt
grep -q '/lib64/ld-linux-x86-64.so.2' /root/ch8-tests/gcc-sanity-readelf.txt
grep -E -o '/usr/lib.*/S?crt[1in].*succeeded' dummy.log
grep -B4 '^ /usr/include' dummy.log
grep 'SEARCH.*/usr/lib' dummy.log | sed 's|; |\n|g'
grep "/lib.*/libc.so.6 " dummy.log
grep found dummy.log
rm -v a.out dummy.log

# 32-bit multilib sanity check (not in the book; checks the m32 multilib built above).
echo 'int main(){}' > dummy32.c
cc -m32 dummy32.c -o dummy32
readelf -h dummy32 | grep -q 'ELF32'
readelf -l dummy32 | grep -q 'ld-linux.so.2'
rm -v dummy32.c dummy32

mkdir -pv /usr/share/gdb/auto-load/usr/lib
mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib

cd /sources
rm -rf "$DIR"
echo "OK 31-gcc"
