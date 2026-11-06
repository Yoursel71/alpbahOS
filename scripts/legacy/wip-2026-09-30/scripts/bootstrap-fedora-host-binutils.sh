#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly HOST_TOOLS="$DATA/host-tools/lfs-host"
readonly SOURCE_ARCHIVE="$LFS/sources/binutils-2.45.tar.xz"
readonly PREFIX="$HOST_TOOLS/binutils-2.45"
readonly RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"
readonly WORK="$HOST_TOOLS/build/binutils-2.45-$RUN_ID"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$(id -un)" == lfs ]] || fail 'Run this build as the dedicated lfs user.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on the expected ext4 filesystem."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected ext4 build directory."
[[ -r "$SOURCE_ARCHIVE" ]] || fail "Missing verified source archive: $SOURCE_ARCHIVE"
[[ ! -e "$PREFIX" ]] || fail "Refusing to overwrite existing tool prefix: $PREFIX"
[[ ! -e "$WORK" ]] || fail "Refusing to overwrite existing build directory: $WORK"

export PATH="/mnt/alpbahOS-data/alpbahOS-build/host-tools/lfs-12.4/bin:/usr/bin:/bin"
export CC=gcc
export CXX=g++
export CONFIG_SHELL=/bin/bash

mkdir -p "$WORK/source" "$WORK/build" "$WORK/stage"
tar -xf "$SOURCE_ARCHIVE" -C "$WORK/source"
cd "$WORK/build"

"$WORK/source/binutils-2.45/configure" \
    --prefix="$PREFIX" \
    --disable-nls \
    --disable-werror \
    --enable-gprofng=no \
    --enable-default-hash-style=gnu

make -j8
make DESTDIR="$WORK/stage" install
mv -T "$WORK/stage$PREFIX" "$PREFIX"

printf 'Installed isolated host Binutils: %s\n' "$PREFIX"
printf 'Build directory: %s\n' "$WORK"
