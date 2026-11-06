#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly SOURCES="$LFS/sources"
readonly ARCHIVE="$SOURCES/linux-6.16.1.tar.xz"
readonly SOURCE_DIR="$SOURCES/linux-6.16.1"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$(id -un)" == lfs ]] || fail 'Run this build as the dedicated lfs user.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on the expected ext4 filesystem."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected ext4 build directory."
[[ -r "$SOURCES/md5sums" && -r "$ARCHIVE" ]] || fail 'Linux source archive or official LFS checksum manifest is missing.'
[[ -d "$LFS/usr" && -w "$LFS/usr" ]] || fail 'Prepare the LFS Chapter 4 target directories as documented before installing headers.'
[[ ! -e "$SOURCE_DIR" ]] || fail 'Refusing to run make mrproper in a reused Linux source tree.'

mapfile -t expected_sum < <(awk '$2 == "linux-6.16.1.tar.xz" { print }' "$SOURCES/md5sums")
[[ "${#expected_sum[@]}" == 1 ]] || fail 'The official manifest must contain exactly one Linux headers checksum.'
printf '%s\n' "${expected_sum[0]}" | (cd "$SOURCES" && md5sum --check --status -) || fail 'Linux source checksum failed.'
printf 'Verified official LFS checksum: linux-6.16.1.tar.xz\n'

export LC_ALL=C
export MAKEFLAGS=-j4
cd "$SOURCES"
tar -xf "$ARCHIVE"
cd "$SOURCE_DIR"

make mrproper
make headers
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include "$LFS/usr"

printf 'Installed Linux API headers into %s/usr/include\n' "$LFS"
