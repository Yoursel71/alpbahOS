#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly SOURCES="$LFS/sources"
readonly SOURCE_DIR="$SOURCES/ncurses-6.5-20250809"
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
[[ -x "/tools/bin/$TARGET-gcc" && -x "/tools/bin/$TARGET-ld" && -x "$LFS/usr/bin/m4" ]] || fail 'Chapter 5 cross tools or Chapter 6 M4 are missing.'
[[ -f "$LFS/usr/lib/libc.so.6" && -d "$LFS/usr/include" && -f "$LFS/usr/lib/libstdc++.so.6" ]] || fail 'Chapter 5 Glibc, headers, or Libstdc++ output is missing.'
[[ -r "$SOURCES/md5sums" && -r "$SOURCES/ncurses-6.5-20250809.tgz" ]] || fail 'Ncurses source archive or official LFS manifest is missing.'
[[ ! -e "$SOURCE_DIR" && ! -e "$LFS/tools/bin/tic" && ! -e "$LFS/usr/lib/libncurses.so" && ! -e "$LFS/usr/include/curses.h" ]] || fail 'Refusing to reuse an extracted Ncurses source tree or overwrite existing target outputs.'

mapfile -t expected_sum < <(awk '$2 == "ncurses-6.5-20250809.tgz" { print }' "$SOURCES/md5sums")
[[ "${#expected_sum[@]}" == 1 ]] || fail 'The official manifest must contain exactly one Ncurses source checksum.'
printf '%s\n' "${expected_sum[0]}" | (cd "$SOURCES" && md5sum --check --status -) || fail 'Ncurses source checksum failed.'
printf 'Verified official LFS checksum: ncurses-6.5-20250809.tgz\n'

export LFS
export LFS_TGT="$TARGET"
export LC_ALL=C
export CONFIG_SHELL=/bin/bash
export MAKEFLAGS=-j4
export PATH="/tools/bin:$HOST_BINUTILS:$BOOK_PATH:/usr/bin:/bin"

cd "$SOURCES"
tar -xf ncurses-6.5-20250809.tgz
cd "$SOURCE_DIR"

mkdir build
pushd build
../configure --prefix="$LFS/tools" AWK=gawk
make -C include
make -C progs tic
install progs/tic "$LFS/tools/bin"
popd

./configure \
    --prefix=/usr \
    --host="$LFS_TGT" \
    --build="$(./config.guess)" \
    --mandir=/usr/share/man \
    --with-manpage-format=normal \
    --with-shared \
    --without-normal \
    --with-cxx-shared \
    --without-debug \
    --without-ada \
    --disable-stripping \
    AWK=gawk

make
make DESTDIR="$LFS" install
ln -sv libncursesw.so "$LFS/usr/lib/libncurses.so"
sed -e 's/^#if.*XOPEN.*$/#if 1/' -i "$LFS/usr/include/curses.h"

printf 'Installed LFS Chapter 6 Ncurses target libraries and host tic into %s\n' "$LFS"
