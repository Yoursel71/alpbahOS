#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly SOURCES="$LFS/sources"
readonly BUILD_DIR="$SOURCES/gcc-build"
readonly GCC_SOURCE="$SOURCES/gcc-15.2.0"
readonly HOST_BINUTILS="$DATA/host-tools/lfs-host/binutils-2.45/bin"
readonly BOOK_PATH="$DATA/host-tools/lfs-12.4/bin"
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
[[ -f "$BUILD_DIR/Makefile" && -f "$GCC_SOURCE/gcc/Makefile.in" ]] || fail 'Configured GCC Pass 1 source/build state is missing.'
[[ ! -x "$LFS/tools/bin/$TARGET-gcc" ]] || fail 'GCC Pass 1 appears already installed; inspect the toolchain before resuming.'

export LFS
export LFS_TGT="$TARGET"
export LC_ALL=C
export MAKEFLAGS=-j4
export PATH="/tools/bin:$HOST_BINUTILS:$BOOK_PATH:/usr/bin:/bin"

verify_source gcc-15.2.0.tar.xz
verify_source gmp-6.3.0.tar.xz
verify_source mpfr-4.2.2.tar.xz
verify_source mpc-1.3.1.tar.gz

cd "$BUILD_DIR"
make
make install

gcc_libdir="$(dirname "$("$TARGET-gcc" -print-libgcc-file-name)")"
mkdir -pv "$gcc_libdir/include"
cat "$GCC_SOURCE/gcc/limitx.h" "$GCC_SOURCE/gcc/glimits.h" "$GCC_SOURCE/gcc/limity.h" > "$gcc_libdir/include/limits.h"

printf 'Installed LFS GCC Pass 1 and limits.h into %s/tools\n' "$LFS"
