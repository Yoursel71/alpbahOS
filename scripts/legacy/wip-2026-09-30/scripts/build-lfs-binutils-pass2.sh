#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly SOURCES="$LFS/sources"
readonly SOURCE_DIR="$SOURCES/binutils-2.45"
readonly BUILD_DIR="$SOURCE_DIR/build"
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
[[ -x "$HOST_BINUTILS/ld" && -x "/tools/bin/$TARGET-gcc" && -x "/tools/bin/$TARGET-ld" ]] || fail 'Host Binutils 2.45 or LFS cross toolchain is missing.'
[[ -f "$LFS/usr/lib/libc.so.6" && -x "$LFS/usr/bin/xz" && -x "$LFS/usr/bin/tar" ]] || fail 'LFS Glibc or Chapter 6 temporary tools are missing.'
[[ -r "$SOURCES/md5sums" && -r "$SOURCES/binutils-2.45.tar.xz" && -f "$SOURCE_DIR/configure" ]] || fail 'Binutils source archive, source tree, or official LFS manifest is missing.'
[[ ! -e "$BUILD_DIR" && ! -e "$LFS/usr/bin/ld" && ! -e "$LFS/usr/bin/as" ]] || fail 'Refusing to reuse a Pass 2 build tree or overwrite target Binutils outputs.'

mapfile -t expected_sum < <(awk '$2 == "binutils-2.45.tar.xz" { print }' "$SOURCES/md5sums")
[[ "${#expected_sum[@]}" == 1 ]] || fail 'The official manifest must contain exactly one Binutils source checksum.'
printf '%s\n' "${expected_sum[0]}" | (cd "$SOURCES" && md5sum --check --status -) || fail 'Binutils source checksum failed.'
printf 'Verified official LFS checksum: binutils-2.45.tar.xz\n'

export LFS
export LFS_TGT="$TARGET"
export LC_ALL=C
export CONFIG_SHELL=/bin/bash
export MAKEFLAGS=-j4
export PATH="/tools/bin:$HOST_BINUTILS:$BOOK_PATH:/usr/bin:/bin"

cd "$SOURCE_DIR"
sed '6031s/$add_dir//' -i ltmain.sh
mkdir -v build
cd build

../configure \
    --prefix=/usr \
    --build="$(../config.guess)" \
    --host="$LFS_TGT" \
    --disable-nls \
    --enable-shared \
    --enable-gprofng=no \
    --disable-werror \
    --enable-64-bit-bfd \
    --enable-new-dtags \
    --enable-default-hash-style=gnu

make
make DESTDIR="$LFS" install
rm -fv "$LFS/usr/lib"/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}

printf 'Installed LFS Binutils Pass 2 into %s/usr\n' "$LFS"
