#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly SOURCES="$LFS/sources"
readonly HOST_BINUTILS="$DATA/host-tools/lfs-host/binutils-2.45/bin"
readonly BOOK_PATH="$DATA/host-tools/lfs-12.4/bin"
readonly GCC_ARCHIVE="$SOURCES/gcc-15.2.0.tar.xz"
readonly GCC_SOURCE="$SOURCES/gcc-15.2.0"
readonly BUILD_DIR="$SOURCES/gcc-build"
readonly TARGET=x86_64-lfs-linux-gnu

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

verify_source() {
    local archive="$1"
    local -a expected
    mapfile -t expected < <(awk -v file="$archive" '$2 == file { print }' "$SOURCES/md5sums")
    [[ "${#expected[@]}" == 1 ]] || fail "Expected exactly one official checksum for $archive."
    printf '%s\n' "${expected[0]}" | (cd "$SOURCES" && md5sum --check --status -) || fail "Checksum failed: $archive"
    printf 'Verified official LFS checksum: %s\n' "$archive"
}

[[ "$(id -un)" == lfs ]] || fail 'Run this build as the dedicated lfs user.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on the expected ext4 filesystem."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected ext4 build directory."
[[ -x "$HOST_BINUTILS/ld" ]] || fail 'The isolated host Binutils 2.45 prerequisite is missing.'
[[ -x "$LFS/tools/bin/$TARGET-as" && -x "$LFS/tools/bin/$TARGET-ld" ]] || fail 'LFS Binutils Pass 1 outputs are missing.'
[[ -r "$SOURCES/md5sums" ]] || fail 'The official LFS checksum manifest is missing.'
[[ ! -e "$GCC_SOURCE" && ! -e "$BUILD_DIR" ]] || fail 'Refusing to reuse an existing GCC source or build directory.'

export LFS
export LFS_TGT="$TARGET"
export LC_ALL=C
export MAKEFLAGS=-j4
export PATH="/tools/bin:$HOST_BINUTILS:$BOOK_PATH:/usr/bin:/bin"

verify_source gcc-15.2.0.tar.xz
verify_source gmp-6.3.0.tar.xz
verify_source mpfr-4.2.2.tar.xz
verify_source mpc-1.3.1.tar.gz

cd "$SOURCES"
tar -xf "$GCC_ARCHIVE"
cd "$GCC_SOURCE"

tar -xf ../gmp-6.3.0.tar.xz
mv -v gmp-6.3.0 gmp
tar -xf ../mpfr-4.2.2.tar.xz
mv -v mpfr-4.2.2 mpfr
tar -xf ../mpc-1.3.1.tar.gz
mv -v mpc-1.3.1 mpc

sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
mkdir -v "$BUILD_DIR"
cd "$BUILD_DIR"

"$GCC_SOURCE/configure" \
    --target="$TARGET" \
    --prefix="$LFS/tools" \
    --with-glibc-version=2.42 \
    --with-sysroot="$LFS" \
    --with-newlib \
    --without-headers \
    --enable-default-pie \
    --enable-default-ssp \
    --disable-nls \
    --disable-shared \
    --disable-multilib \
    --disable-threads \
    --disable-libatomic \
    --disable-libgomp \
    --disable-libquadmath \
    --disable-libssp \
    --disable-libvtv \
    --disable-libstdcxx \
    --enable-languages=c,c++

make
make install

gcc_libdir="$(dirname "$("$TARGET-gcc" -print-libgcc-file-name)")"
mkdir -pv "$gcc_libdir/include"
cat "$GCC_SOURCE/gcc/limitx.h" "$GCC_SOURCE/gcc/glimits.h" "$GCC_SOURCE/gcc/limity.h" > "$gcc_libdir/include/limits.h"

printf 'Installed LFS GCC Pass 1 and limits.h into %s/tools\n' "$LFS"
