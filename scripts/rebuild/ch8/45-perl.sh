#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.47.1: Perl-5.44.0 (threaded, shared libperl).
set -euo pipefail

PKG=perl-5.44.0.tar.xz
DIR=perl-5.44.0
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.47.1 Installation of Perl
export BUILD_ZLIB=False
export BUILD_BZIP2=0

sh Configure -des \
             -D prefix=/usr \
             -D vendorprefix=/usr \
             -D privlib=/usr/lib/perl5/5.44/core_perl \
             -D archlib=/usr/lib/perl5/5.44/core_perl \
             -D sitelib=/usr/lib/perl5/5.44/site_perl \
             -D sitearch=/usr/lib/perl5/5.44/site_perl \
             -D vendorlib=/usr/lib/perl5/5.44/vendor_perl \
             -D vendorarch=/usr/lib/perl5/5.44/vendor_perl \
             -D man1dir=/usr/share/man/man1 \
             -D man3dir=/usr/share/man/man3 \
             -D pager="/usr/bin/less -isR" \
             -D useshrplib \
             -D usethreads
make
TEST_JOBS=$(nproc) make test_harness > "$TESTS/perl-test.log" 2>&1 || echo "NOTE perl test exited $? (see $TESTS/perl-test.log)"
tail -n 3 "$TESTS/perl-test.log"
make install
unset BUILD_ZLIB BUILD_BZIP2

cd /sources
rm -rf "$DIR"
echo "OK 45-perl"
