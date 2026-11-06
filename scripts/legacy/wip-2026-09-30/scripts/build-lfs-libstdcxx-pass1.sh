#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly SOURCES="$LFS/sources"
readonly SOURCE_DIR="$SOURCES/gcc-15.2.0"
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
[[ -x "$LFS/tools/bin/$TARGET-gcc" && -x "$LFS/tools/bin/$TARGET-g++" ]] || fail 'LFS cross GCC Pass 1 outputs are missing.'
[[ -f "$LFS/usr/lib/libc.so.6" && -d "$LFS/usr/include" ]] || fail 'Glibc or Linux API headers are missing from the LFS target.'
[[ -r "$SOURCES/md5sums" && -r "$SOURCES/gcc-15.2.0.tar.xz" && -f "$SOURCE_DIR/libstdc++-v3/configure" ]] || fail 'GCC source or official LFS manifest is missing.'
[[ ! -e "$BUILD_DIR" ]] || fail 'Refusing to reuse an existing Libstdc++ Pass 1 build directory.'

mapfile -t expected_sum < <(awk '$2 == "gcc-15.2.0.tar.xz" { print }' "$SOURCES/md5sums")
[[ "${#expected_sum[@]}" == 1 ]] || fail 'The official manifest must contain exactly one GCC source checksum.'
printf '%s\n' "${expected_sum[0]}" | (cd "$SOURCES" && md5sum --check --status -) || fail 'GCC source checksum failed.'
printf 'Verified official LFS checksum: gcc-15.2.0.tar.xz\n'

export LFS
export LFS_TGT="$TARGET"
export LC_ALL=C
export CONFIG_SHELL=/bin/bash
export MAKEFLAGS=-j4
export PATH="/tools/bin:$HOST_BINUTILS:$BOOK_PATH:/usr/bin:/bin"

cd "$SOURCE_DIR"
mkdir -v build
cd build

../libstdc++-v3/configure \
    --host="$LFS_TGT" \
    --build="$(../config.guess)" \
    --prefix=/usr \
    --disable-multilib \
    --disable-nls \
    --disable-libstdcxx-pch \
    --with-gxx-include-dir="/tools/$LFS_TGT/include/c++/15.2.0"

make
make DESTDIR="$LFS" install

for archive in libstdc++.la libstdc++exp.la libstdc++fs.la libsupc++.la; do
    [[ ! -e "$LFS/usr/lib/$archive" ]] || rm -v "$LFS/usr/lib/$archive"
done

printf 'Installed LFS Libstdc++ Pass 1 into %s/usr and toolchain include path\n' "$LFS"
