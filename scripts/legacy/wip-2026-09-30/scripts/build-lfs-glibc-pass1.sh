#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly SOURCES="$LFS/sources"
readonly SOURCE_DIR="$SOURCES/glibc-2.42"
readonly BUILD_DIR="$SOURCE_DIR/build"
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

[[ "$(id -un)" == lfs ]] || fail 'Run this build as the dedicated lfs user, not root.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on the expected ext4 filesystem."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected ext4 build directory."
[[ -x "$LFS/tools/bin/$TARGET-gcc" && -x "$LFS/tools/bin/$TARGET-ld" ]] || fail 'LFS cross GCC/Binutils Pass 1 outputs are missing.'
[[ -d "$LFS/usr/include" && -w "$LFS/usr/lib" && -w "$LFS/lib64" ]] || fail 'LFS Chapter 4 directories or Linux API headers are missing.'
[[ "$(readlink "$LFS/bin")" == usr/bin && "$(readlink "$LFS/lib")" == usr/lib && "$(readlink "$LFS/sbin")" == usr/sbin ]] || fail 'The LFS Chapter 4 usr symlinks are missing or unexpected.'
[[ -r "$SOURCES/md5sums" && -r "$SOURCES/glibc-2.42.tar.xz" && -r "$SOURCES/glibc-2.42-fhs-1.patch" ]] || fail 'Glibc source, FHS patch, or official manifest is missing.'
[[ ! -e "$SOURCE_DIR" && ! -e "$LFS/usr/lib/libc.so.6" ]] || fail 'Refusing to reuse a Glibc source tree or overwrite an existing target libc.'

export LFS
export LFS_TGT="$TARGET"
export LC_ALL=C
export CONFIG_SHELL=/bin/bash
export MAKEFLAGS=-j4
export PATH="/tools/bin:$HOST_BINUTILS:$BOOK_PATH:/usr/bin:/bin"

verify_source glibc-2.42.tar.xz
verify_source glibc-2.42-fhs-1.patch

cd "$SOURCES"
tar -xf glibc-2.42.tar.xz
cd "$SOURCE_DIR"
patch -Np1 -i ../glibc-2.42-fhs-1.patch

ln -sfv ../lib/ld-linux-x86-64.so.2 "$LFS/lib64/ld-linux-x86-64.so.2"
ln -sfv ../lib/ld-linux-x86-64.so.2 "$LFS/lib64/ld-lsb-x86-64.so.3"

mkdir -v build
cd build
printf 'rootsbindir=/usr/sbin\n' > configparms

../configure \
    --prefix=/usr \
    --host="$LFS_TGT" \
    --build="$(../scripts/config.guess)" \
    --disable-nscd \
    libc_cv_slibdir=/usr/lib \
    --enable-kernel=5.4

make
make DESTDIR="$LFS" install
sed '/RTLDLIST=/s@/usr@@g' -i "$LFS/usr/bin/ldd"

printf 'Installed LFS Glibc Pass 1 into %s/usr\n' "$LFS"
