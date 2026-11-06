#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly SOURCE_ARCHIVE=iana-etc-20250807.tar.gz
readonly SOURCE_DIR=iana-etc-20250807

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$(id -u)" == 0 ]] || fail 'Run as root inside the LFS chroot.'
[[ -d /sources && -r "/sources/$SOURCE_ARCHIVE" && -r /sources/md5sums ]] || fail 'Iana-Etc source archive or official LFS manifest is missing.'
[[ ! -e "/sources/$SOURCE_DIR" ]] || fail 'Refusing to reuse an extracted Iana-Etc source tree.'
[[ ! -e /etc/services && ! -e /etc/protocols ]] || fail 'Refusing to overwrite existing /etc/services or /etc/protocols.'
for tool in /usr/bin/bash /usr/bin/tar /usr/bin/md5sum /usr/bin/awk /usr/bin/cp; do
    [[ -x "$tool" ]] || fail "Required Chapter 6/7 tool is missing: $tool"
done

mapfile -t expected < <(awk -v file="$SOURCE_ARCHIVE" '$2 == file { print }' /sources/md5sums)
[[ "${#expected[@]}" == 1 ]] || fail "Expected exactly one official LFS checksum for $SOURCE_ARCHIVE."
printf '%s\n' "${expected[0]}" | (cd /sources && md5sum --check -)

cd /sources
tar -xf "$SOURCE_ARCHIVE"
cd "$SOURCE_DIR"
[[ -f services && -f protocols ]] || fail 'Iana-Etc source files services/protocols are missing.'
cp -v services protocols /etc

printf 'Installed LFS Chapter 8 Iana-Etc 20250807.\n'
