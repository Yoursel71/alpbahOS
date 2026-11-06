#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly SOURCE_ARCHIVE=gettext-0.26.tar.xz
readonly SOURCE_DIR=gettext-0.26

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$(id -u)" == 0 ]] || fail 'Run as root inside the LFS chroot.'
[[ -d /sources && -r "/sources/$SOURCE_ARCHIVE" && -r /sources/md5sums ]] || fail 'Gettext source archive or official LFS manifest is missing.'
[[ ! -e "/sources/$SOURCE_DIR" ]] || fail 'Refusing to reuse an extracted Gettext source tree.'
for tool in /usr/bin/bash /usr/bin/tar /usr/bin/make /usr/bin/md5sum /usr/bin/awk /usr/bin/cp; do
    [[ -x "$tool" ]] || fail "Required Chapter 6 tool is missing: $tool"
done
for binary in msgfmt msgmerge xgettext; do
    [[ ! -e "/usr/bin/$binary" ]] || fail "Refusing to overwrite existing /usr/bin/$binary"
done

mapfile -t expected < <(awk -v file="$SOURCE_ARCHIVE" '$2 == file { print }' /sources/md5sums)
[[ "${#expected[@]}" == 1 ]] || fail "Expected exactly one official LFS checksum for $SOURCE_ARCHIVE."
printf '%s\n' "${expected[0]}" | (cd /sources && md5sum --check -)

cd /sources
tar -xf "$SOURCE_ARCHIVE"
cd "$SOURCE_DIR"

./configure --disable-shared
make
cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin

printf 'Installed temporary LFS Chapter 7 Gettext tools.\n'
