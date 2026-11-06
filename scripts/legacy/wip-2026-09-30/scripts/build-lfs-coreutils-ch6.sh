#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly SOURCES="$LFS/sources"
readonly SOURCE_DIR="$SOURCES/coreutils-9.7"
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
[[ -x "$LFS/usr/bin/bash" && -x "$LFS/usr/bin/m4" && -e "$LFS/usr/lib/libncurses.so" ]] || fail 'Chapter 6 Bash, M4, or Ncurses is missing.'
[[ -r "$SOURCES/md5sums" && -r "$SOURCES/coreutils-9.7.tar.xz" ]] || fail 'Coreutils source archive or official LFS manifest is missing.'
[[ ! -e "$SOURCE_DIR" && ! -e "$LFS/usr/bin/ls" && ! -e "$LFS/usr/bin/chroot" && ! -e "$LFS/usr/sbin/chroot" ]] || fail 'Refusing to reuse an extracted Coreutils tree or overwrite existing target outputs.'

mapfile -t expected_sum < <(awk '$2 == "coreutils-9.7.tar.xz" { print }' "$SOURCES/md5sums")
[[ "${#expected_sum[@]}" == 1 ]] || fail 'The official manifest must contain exactly one Coreutils source checksum.'
printf '%s\n' "${expected_sum[0]}" | (cd "$SOURCES" && md5sum --check --status -) || fail 'Coreutils source checksum failed.'
printf 'Verified official LFS checksum: coreutils-9.7.tar.xz\n'

export LFS
export LFS_TGT="$TARGET"
export LC_ALL=C
export CONFIG_SHELL=/bin/bash
export MAKEFLAGS=-j4
export PATH="/tools/bin:$HOST_BINUTILS:$BOOK_PATH:/usr/bin:/bin"

cd "$SOURCES"
tar -xf coreutils-9.7.tar.xz
cd "$SOURCE_DIR"

./configure \
    --prefix=/usr \
    --host="$LFS_TGT" \
    --build="$(build-aux/config.guess)" \
    --enable-install-program=hostname \
    --enable-no-install-program=kill,uptime

make
make DESTDIR="$LFS" install
mv -v "$LFS/usr/bin/chroot" "$LFS/usr/sbin"
mkdir -pv "$LFS/usr/share/man/man8"
mv -v "$LFS/usr/share/man/man1/chroot.1" "$LFS/usr/share/man/man8/chroot.8"
sed -i 's/"1"/"8"/' "$LFS/usr/share/man/man8/chroot.8"

printf 'Installed LFS Chapter 6 Coreutils and relocated chroot into %s/usr\n' "$LFS"
