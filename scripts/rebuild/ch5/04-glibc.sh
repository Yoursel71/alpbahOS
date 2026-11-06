#!/bin/bash
# Multilib LFS 13.1, Chapter 5.5 "Glibc-2.44" (5.5.1 64-bit build, 5.5.2 32-bit build)
# https://linuxfromscratch.org/mlfs/view/13.1/chapter05/glibc.html
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../config.sh"
lfs_guard

PKG=glibc-2.44.tar.xz
DIR=glibc-2.44

# Sanity-check helper: fail unless the expected text appears in the captured output.
expect() { # expect <label> <expected text> <captured output>
    if ! grep -qF -- "$2" <<<"$3"; then
        echo "SANITY FAIL: $1: expected output containing: $2" >&2
        exit 1
    fi
}

cd "$LFS/sources"
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# ---- 5.5.1 Installation of Glibc (64-bit) ----

ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3

patch -Np1 -i ../glibc-fhs-1.patch
patch -Np1 -i ../glibc-2.44-upstream_fixes-1.patch

mkdir -v build
cd       build

echo "rootsbindir=/usr/sbin" > configparms

../configure                             \
      --prefix=/usr                      \
      --host=$LFS_TGT                    \
      --build=$(../scripts/config.guess) \
      --disable-nscd                     \
      libc_cv_slibdir=/usr/lib           \
      --enable-kernel=5.10

make

make DESTDIR=$LFS install

sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd

# Sanity checks (book 5.5.1). Each expected line from the book must appear.
echo 'int main(){}' | $LFS_TGT-gcc -x c - -v -Wl,--verbose &> dummy.log
out=$($LFS_TGT-readelf -l a.out | grep ': /lib' || true)
echo "$out"
expect "dynamic linker (64-bit)" "[Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]" "$out"

out=$(grep -E -o "$LFS/lib.*/S?crt[1in].*succeeded" dummy.log || true)
echo "$out"
expect "start file Scrt1.o" "$LFS/lib/../lib/Scrt1.o succeeded" "$out"
expect "start file crti.o" "$LFS/lib/../lib/crti.o succeeded" "$out"
expect "start file crtn.o" "$LFS/lib/../lib/crtn.o succeeded" "$out"

out=$(grep -B3 "^ $LFS/usr/include" dummy.log || true)
echo "$out"
expect "include search start" "#include <...> search starts here:" "$out"
expect "gcc internal include" " $LFS/tools/lib/gcc/$LFS_TGT/16.2.0/include" "$out"
expect "sysroot usr/include" " $LFS/usr/include" "$out"

out=$(grep 'SEARCH.*/usr/lib' dummy.log | sed 's|; |\n|g' || true)
echo "$out"
expect "linker search /usr/lib" 'SEARCH_DIR("=/usr/lib")' "$out"
bad=$(grep -o 'SEARCH_DIR("[^=][^"]*")' <<<"$out" | grep -v -- '-linux-gnu' || true)
if [ -n "$bad" ]; then
    echo "SANITY FAIL: linker search paths without '=' sysroot prefix: $bad" >&2
    exit 1
fi

out=$(grep "/lib.*/libc.so.6 " dummy.log || true)
echo "$out"
expect "libc.so.6 from sysroot" "attempt to open $LFS/usr/lib/libc.so.6 succeeded" "$out"

out=$(grep found dummy.log || true)
echo "$out"
expect "dynamic linker lookup" "found ld-linux-x86-64.so.2 at $LFS/usr/lib/ld-linux-x86-64.so.2" "$out"

rm -v a.out dummy.log

# ---- 5.5.2 Building Glibc - 32-bit ----

make clean
find .. -name "*.a" -delete

CC="$LFS_TGT-gcc -m32"                   \
CXX="$LFS_TGT-g++ -m32"                  \
../configure                             \
      --prefix=/usr                      \
      --host=$LFS_TGT32                  \
      --build=$(../scripts/config.guess) \
      --disable-nscd                     \
      --with-headers=$LFS/usr/include    \
      --libdir=/usr/lib32                \
      --libexecdir=/usr/lib32            \
      libc_cv_slibdir=/usr/lib32         \
      --enable-kernel=5.10

# Serial make here. With -j16 the 32-bit 'others' programs (debug/pcprofiledump,
# posix/getconf) were linked while build/libc.so was still being written, giving
# 'undefined reference to printf' (run 2026-11-06 16:45, log 04-glibc.log). The same
# tree finished with rc 0 under 'make -j1' (retry 2026-11-06 16:54).
make -j1

make DESTDIR=$PWD/DESTDIR install
cp -a DESTDIR/usr/lib32 $LFS/usr/
install -vm644 DESTDIR/usr/include/gnu/{lib-names,stubs}-32.h \
               $LFS/usr/include/gnu/
ln -svf ../lib32/ld-linux.so.2 $LFS/lib/ld-linux.so.2

# Caution block sanity check (book 5.5.2)
echo 'int main(){}' > dummy.c
$LFS_TGT-gcc -m32 dummy.c
out=$(readelf -l a.out | grep '/ld-linux' || true)
echo "$out"
expect "dynamic linker (32-bit)" "[Requesting program interpreter: /lib/ld-linux.so.2]" "$out"

rm -v dummy.c a.out

cd "$LFS/sources"
rm -rf "$DIR"

echo "OK 04-glibc"
