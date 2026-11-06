#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly SOURCES="$LFS/sources"
readonly SOURCE_DIR="$SOURCES/bash-5.3"
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
[[ -x "/tools/bin/$TARGET-gcc" && -x "/tools/bin/$TARGET-ld" && -x "$LFS/usr/bin/m4" && -x "$LFS/tools/bin/tic" ]] || fail 'Chapter 5 cross tools or Chapter 6 M4/Ncurses host tools are missing.'
[[ -f "$LFS/usr/lib/libc.so.6" && -f "$LFS/usr/lib/libstdc++.so.6" && -e "$LFS/usr/lib/libncurses.so" ]] || fail 'Chapter 5 libraries or Chapter 6 Ncurses output is missing.'
[[ -r "$SOURCES/md5sums" && -r "$SOURCES/bash-5.3.tar.gz" ]] || fail 'Bash source archive or official LFS manifest is missing.'
[[ ! -e "$SOURCE_DIR" && ! -e "$LFS/usr/bin/bash" && ! -e "$LFS/bin/sh" ]] || fail 'Refusing to reuse an extracted Bash source tree or overwrite existing Bash outputs.'

mapfile -t expected_sum < <(awk '$2 == "bash-5.3.tar.gz" { print }' "$SOURCES/md5sums")
[[ "${#expected_sum[@]}" == 1 ]] || fail 'The official manifest must contain exactly one Bash source checksum.'
printf '%s\n' "${expected_sum[0]}" | (cd "$SOURCES" && md5sum --check --status -) || fail 'Bash source checksum failed.'
printf 'Verified official LFS checksum: bash-5.3.tar.gz\n'

export LFS
export LFS_TGT="$TARGET"
export LC_ALL=C
export CONFIG_SHELL=/bin/bash
export MAKEFLAGS=-j4
export PATH="/tools/bin:$HOST_BINUTILS:$BOOK_PATH:/usr/bin:/bin"

cd "$SOURCES"
tar -xf bash-5.3.tar.gz
cd "$SOURCE_DIR"

./configure \
    --prefix=/usr \
    --build="$(sh support/config.guess)" \
    --host="$LFS_TGT" \
    --without-bash-malloc

make
make DESTDIR="$LFS" install
ln -sv bash "$LFS/bin/sh"

printf 'Installed LFS Chapter 6 Bash and /bin/sh link into %s\n' "$LFS"
