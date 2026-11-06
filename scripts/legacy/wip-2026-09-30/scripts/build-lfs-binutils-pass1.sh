#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly SOURCES="$LFS/sources"
readonly HOST_BINUTILS="$DATA/host-tools/lfs-host/binutils-2.45/bin"
readonly BOOK_PATH="$DATA/host-tools/lfs-12.4/bin"
readonly SOURCE_ARCHIVE="$SOURCES/binutils-2.45.tar.xz"
readonly SOURCE_DIR="$SOURCES/binutils-2.45"
readonly BUILD_DIR="$SOURCES/binutils-build"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$(id -un)" == lfs ]] || fail 'Run this build as the dedicated lfs user.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on the expected ext4 filesystem."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected ext4 build directory."
[[ -x "$HOST_BINUTILS/ld" ]] || fail 'The isolated host Binutils 2.45 prerequisite is missing.'
[[ -r "$SOURCE_ARCHIVE" && -r "$SOURCES/md5sums" ]] || fail 'The LFS archive or official checksum manifest is missing.'
[[ ! -e "$SOURCE_DIR" && ! -e "$BUILD_DIR" ]] || fail 'Refusing to reuse an existing Binutils source or build directory.'

cd "$SOURCES"
mapfile -t expected_sum < <(awk '$2 == "binutils-2.45.tar.xz" { print }' md5sums)
[[ "${#expected_sum[@]}" == 1 ]] || fail 'The official manifest must contain exactly one Binutils checksum.'
printf '%s\n' "${expected_sum[0]}" | md5sum --check --status - || fail 'Binutils source checksum failed.'

export LFS
export LFS_TGT=x86_64-lfs-linux-gnu
export LC_ALL=C
export PATH="/tools/bin:$HOST_BINUTILS:$BOOK_PATH:/usr/bin:/bin"

tar -xf "$SOURCE_ARCHIVE"
mkdir -v "$BUILD_DIR"
cd "$BUILD_DIR"

"$SOURCE_DIR/configure" \
    --prefix="$LFS/tools" \
    --with-sysroot="$LFS" \
    --target="$LFS_TGT" \
    --disable-nls \
    --enable-gprofng=no \
    --disable-werror \
    --enable-new-dtags \
    --enable-default-hash-style=gnu

make
make install

printf 'Installed LFS Binutils Pass 1 into %s/tools\n' "$LFS"
