#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly SOURCE_ARCHIVE=perl-5.42.0.tar.xz
readonly SOURCE_DIR=perl-5.42.0

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$(id -u)" == 0 ]] || fail 'Run as root inside the LFS chroot.'
[[ -d /sources && -r "/sources/$SOURCE_ARCHIVE" && -r /sources/md5sums ]] || fail 'Perl source archive or official LFS manifest is missing.'
[[ ! -e "/sources/$SOURCE_DIR" ]] || fail 'Refusing to reuse an extracted Perl source tree.'
[[ ! -e /usr/bin/perl ]] || fail 'Refusing to overwrite an existing /usr/bin/perl.'
for tool in /usr/bin/sh /usr/bin/tar /usr/bin/make /usr/bin/md5sum /usr/bin/awk; do
    [[ -x "$tool" ]] || fail "Required Chapter 6/7 tool is missing: $tool"
done

mapfile -t expected < <(awk -v file="$SOURCE_ARCHIVE" '$2 == file { print }' /sources/md5sums)
[[ "${#expected[@]}" == 1 ]] || fail "Expected exactly one official LFS checksum for $SOURCE_ARCHIVE."
printf '%s\n' "${expected[0]}" | (cd /sources && md5sum --check -)

cd /sources
tar -xf "$SOURCE_ARCHIVE"
cd "$SOURCE_DIR"

sh Configure -des \
    -D prefix=/usr \
    -D vendorprefix=/usr \
    -D useshrplib \
    -D privlib=/usr/lib/perl5/5.42/core_perl \
    -D archlib=/usr/lib/perl5/5.42/core_perl \
    -D sitelib=/usr/lib/perl5/5.42/site_perl \
    -D sitearch=/usr/lib/perl5/5.42/site_perl \
    -D vendorlib=/usr/lib/perl5/5.42/vendor_perl \
    -D vendorarch=/usr/lib/perl5/5.42/vendor_perl

make
make install

printf 'Installed LFS Chapter 7 Perl 5.42.0.\n'
