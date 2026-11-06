#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly SOURCE_ARCHIVE=util-linux-2.41.1.tar.xz
readonly SOURCE_DIR=util-linux-2.41.1

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$(id -u)" == 0 ]] || fail 'Run as root inside the LFS chroot.'
[[ -d /sources && -r "/sources/$SOURCE_ARCHIVE" && -r /sources/md5sums ]] || fail 'Util-linux source archive or official LFS manifest is missing.'
[[ ! -e "/sources/$SOURCE_DIR" ]] || fail 'Refusing to reuse an extracted Util-linux source tree.'
[[ ! -e /usr/bin/mount ]] || fail 'Refusing to overwrite an existing /usr/bin/mount.'
for tool in /usr/bin/bash /usr/bin/tar /usr/bin/make /usr/bin/md5sum /usr/bin/awk /usr/bin/install; do
    [[ -x "$tool" ]] || fail "Required Chapter 6/7 tool is missing: $tool"
done

mapfile -t expected < <(awk -v file="$SOURCE_ARCHIVE" '$2 == file { print }' /sources/md5sums)
[[ "${#expected[@]}" == 1 ]] || fail "Expected exactly one official LFS checksum for $SOURCE_ARCHIVE."
printf '%s\n' "${expected[0]}" | (cd /sources && md5sum --check -)

mkdir -pv /var/lib/hwclock
cd /sources
tar -xf "$SOURCE_ARCHIVE"
cd "$SOURCE_DIR"

./configure \
    --libdir=/usr/lib \
    --runstatedir=/run \
    --disable-chfn-chsh \
    --disable-login \
    --disable-nologin \
    --disable-su \
    --disable-setpriv \
    --disable-runuser \
    --disable-pylibmount \
    --disable-static \
    --disable-liblastlog2 \
    --without-python \
    ADJTIME_PATH=/var/lib/hwclock/adjtime \
    --docdir=/usr/share/doc/util-linux-2.41.1
make
make install

printf 'Installed LFS Chapter 7 Util-linux 2.41.1.\n'
