#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly SOURCE_ARCHIVE=texinfo-7.2.tar.xz
readonly SOURCE_DIR=texinfo-7.2

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$(id -u)" == 0 ]] || fail 'Run as root inside the LFS chroot.'
[[ -d /sources && -r "/sources/$SOURCE_ARCHIVE" && -r /sources/md5sums ]] || fail 'Texinfo source archive or official LFS manifest is missing.'
[[ ! -e "/sources/$SOURCE_DIR" ]] || fail 'Refusing to reuse an extracted Texinfo source tree.'
[[ ! -e /usr/bin/makeinfo ]] || fail 'Refusing to overwrite an existing /usr/bin/makeinfo.'
for tool in /usr/bin/bash /usr/bin/tar /usr/bin/make /usr/bin/md5sum /usr/bin/awk; do
    [[ -x "$tool" ]] || fail "Required Chapter 6/7 tool is missing: $tool"
done

mapfile -t expected < <(awk -v file="$SOURCE_ARCHIVE" '$2 == file { print }' /sources/md5sums)
[[ "${#expected[@]}" == 1 ]] || fail "Expected exactly one official LFS checksum for $SOURCE_ARCHIVE."
printf '%s\n' "${expected[0]}" | (cd /sources && md5sum --check -)

cd /sources
tar -xf "$SOURCE_ARCHIVE"
cd "$SOURCE_DIR"

./configure --prefix=/usr
make
make install

printf 'Installed LFS Chapter 7 Texinfo 7.2.\n'
