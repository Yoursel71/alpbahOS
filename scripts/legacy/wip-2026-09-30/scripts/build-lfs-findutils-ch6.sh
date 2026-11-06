#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly SOURCES="$LFS/sources"
readonly SOURCE_DIR="$SOURCES/findutils-4.10.0"
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
[[ -x "$LFS/usr/bin/file" && -x "$LFS/usr/bin/ls" && -x "$LFS/usr/bin/bash" ]] || fail 'Chapter 6 File, Coreutils, or Bash is missing.'
[[ -r "$SOURCES/md5sums" && -r "$SOURCES/findutils-4.10.0.tar.xz" ]] || fail 'Findutils source archive or official LFS manifest is missing.'
[[ ! -e "$SOURCE_DIR" && ! -e "$LFS/usr/bin/find" && ! -e "$LFS/usr/bin/xargs" ]] || fail 'Refusing to reuse an extracted Findutils tree or overwrite existing target outputs.'

mapfile -t expected_sum < <(awk '$2 == "findutils-4.10.0.tar.xz" { print }' "$SOURCES/md5sums")
[[ "${#expected_sum[@]}" == 1 ]] || fail 'The official manifest must contain exactly one Findutils source checksum.'
printf '%s\n' "${expected_sum[0]}" | (cd "$SOURCES" && md5sum --check --status -) || fail 'Findutils source checksum failed.'
printf 'Verified official LFS checksum: findutils-4.10.0.tar.xz\n'

export LFS
export LFS_TGT="$TARGET"
export LC_ALL=C
export CONFIG_SHELL=/bin/bash
export MAKEFLAGS=-j4
export PATH="/tools/bin:$HOST_BINUTILS:$BOOK_PATH:/usr/bin:/bin"

cd "$SOURCES"
tar -xf findutils-4.10.0.tar.xz
cd "$SOURCE_DIR"

./configure \
    --prefix=/usr \
    --localstatedir=/var/lib/locate \
    --host="$LFS_TGT" \
    --build="$(build-aux/config.guess)"

make
make DESTDIR="$LFS" install

printf 'Installed LFS Chapter 6 Findutils into %s/usr\n' "$LFS"
