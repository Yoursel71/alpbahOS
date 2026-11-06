#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly SOURCES="$LFS/sources"
readonly SOURCE_DIR="$SOURCES/file-5.46"
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
[[ -x "$LFS/usr/bin/diff" && -x "$LFS/usr/bin/bash" && -e "$LFS/usr/lib/libncurses.so" ]] || fail 'Chapter 6 Diffutils, Bash, or Ncurses output is missing.'
[[ -r "$SOURCES/md5sums" && -r "$SOURCES/file-5.46.tar.gz" ]] || fail 'File source archive or official LFS manifest is missing.'
[[ ! -e "$SOURCE_DIR" && ! -e "$LFS/usr/bin/file" && ! -e "$LFS/usr/lib/libmagic.la" ]] || fail 'Refusing to reuse an extracted File tree or overwrite target outputs.'

mapfile -t expected_sum < <(awk '$2 == "file-5.46.tar.gz" { print }' "$SOURCES/md5sums")
[[ "${#expected_sum[@]}" == 1 ]] || fail 'The official manifest must contain exactly one File source checksum.'
printf '%s\n' "${expected_sum[0]}" | (cd "$SOURCES" && md5sum --check --status -) || fail 'File source checksum failed.'
printf 'Verified official LFS checksum: file-5.46.tar.gz\n'

export LFS
export LFS_TGT="$TARGET"
export LC_ALL=C
export CONFIG_SHELL=/bin/bash
export MAKEFLAGS=-j4
export PATH="/tools/bin:$HOST_BINUTILS:$BOOK_PATH:/usr/bin:/bin"

cd "$SOURCES"
tar -xf file-5.46.tar.gz
cd "$SOURCE_DIR"

mkdir build
pushd build
../configure \
    --disable-bzlib \
    --disable-libseccomp \
    --disable-xzlib \
    --disable-zlib
make
popd

./configure \
    --prefix=/usr \
    --host="$LFS_TGT" \
    --build="$(./config.guess)"

make FILE_COMPILE="$(pwd)/build/src/file"
make DESTDIR="$LFS" install
rm -v "$LFS/usr/lib/libmagic.la"

printf 'Installed LFS Chapter 6 File into %s/usr\n' "$LFS"
