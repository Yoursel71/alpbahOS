#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly SOURCES="$LFS/sources"
readonly SOURCE_DIR="$SOURCES/gzip-1.14"
readonly HOST_BINUTILS="$DATA/host-tools/lfs-host/binutils-2.45/bin"
readonly BOOK_PATH="$DATA/host-tools/lfs-12.4/bin"
readonly TARGET=x86_64-lfs-linux-gnu

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$(id -un)" == lfs ]] || fail 'Run this build as the dedicated lfs user, not root.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on the expected ext4 filesystem."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected ext4 build directory."
[[ -x "/tools/bin/$TARGET-gcc" && -x "/tools/bin/$TARGET-ld" ]] || fail 'Chapter 5 cross compiler/linker is missing.'
[[ -x "$LFS/usr/bin/grep" && -x "$LFS/usr/bin/gawk" && -x "$LFS/usr/bin/find" ]] || fail 'Chapter 6 Grep, Gawk, or Findutils is missing.'
[[ -r "$SOURCES/md5sums" && -r "$SOURCES/gzip-1.14.tar.xz" ]] || fail 'Gzip source archive or official LFS manifest is missing.'
[[ ! -e "$SOURCE_DIR" && ! -e "$LFS/usr/bin/gzip" ]] || fail 'Refusing to reuse an extracted Gzip tree or overwrite target gzip.'

mapfile -t expected_sum < <(awk '$2 == "gzip-1.14.tar.xz" { print }' "$SOURCES/md5sums")
[[ "${#expected_sum[@]}" == 1 ]] || fail 'The official manifest must contain exactly one Gzip source checksum.'
printf '%s\n' "${expected_sum[0]}" | (cd "$SOURCES" && md5sum --check --status -) || fail 'Gzip source checksum failed.'
printf 'Verified official LFS checksum: gzip-1.14.tar.xz\n'

export LFS
export LFS_TGT="$TARGET"
export LC_ALL=C
export CONFIG_SHELL=/bin/bash
export MAKEFLAGS=-j4
export PATH="/tools/bin:$HOST_BINUTILS:$BOOK_PATH:/usr/bin:/bin"

cd "$SOURCES"
tar -xf gzip-1.14.tar.xz
cd "$SOURCE_DIR"

./configure --prefix=/usr --host="$LFS_TGT"
make
make DESTDIR="$LFS" install

printf 'Installed LFS Chapter 6 Gzip into %s/usr\n' "$LFS"
