#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly SOURCE_ARCHIVE=man-pages-6.15.tar.xz
readonly SOURCE_DIR=man-pages-6.15

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$(id -u)" == 0 ]] || fail 'Run as root inside the LFS chroot.'
[[ -d /sources && -r "/sources/$SOURCE_ARCHIVE" && -r /sources/md5sums ]] || fail 'Man-pages source archive or official LFS manifest is missing.'
[[ ! -e "/sources/$SOURCE_DIR" ]] || fail 'Refusing to reuse an extracted Man-pages source tree.'
[[ ! -e /usr/share/man/man2/open.2 ]] || fail 'Refusing to overwrite an existing installed Man-pages tree.'
for tool in /usr/bin/bash /usr/bin/tar /usr/bin/make /usr/bin/md5sum /usr/bin/awk; do
    [[ -x "$tool" ]] || fail "Required Chapter 6/7 tool is missing: $tool"
done

mapfile -t expected < <(awk -v file="$SOURCE_ARCHIVE" '$2 == file { print }' /sources/md5sums)
[[ "${#expected[@]}" == 1 ]] || fail "Expected exactly one official LFS checksum for $SOURCE_ARCHIVE."
printf '%s\n' "${expected[0]}" | (cd /sources && md5sum --check -)

cd /sources
tar -xf "$SOURCE_ARCHIVE"
cd "$SOURCE_DIR"

# LFS excludes obsolete crypt(3) manual pages from this disposable extraction;
# the downloaded source archive remains unchanged in /sources.
compgen -G 'man3/crypt*' >/dev/null || fail 'Expected LFS-excluded man3/crypt* pages are missing.'
rm -v man3/crypt*

make -R GIT=false prefix=/usr install

printf 'Installed LFS Chapter 8 Man-pages 6.15.\n'
