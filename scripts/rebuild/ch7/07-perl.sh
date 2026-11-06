#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 7, section 7.9: Perl-5.44.0 (chroot paths).
set -euo pipefail

PKG=perl-5.44.0.tar.xz
DIR=perl-5.44.0

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 7.9.1 Installation of Perl
sh Configure -des                                         \
             -D prefix=/usr                               \
             -D vendorprefix=/usr                         \
             -D useshrplib                                \
             -D privlib=/usr/lib/perl5/5.44/core_perl     \
             -D archlib=/usr/lib/perl5/5.44/core_perl     \
             -D sitelib=/usr/lib/perl5/5.44/site_perl     \
             -D sitearch=/usr/lib/perl5/5.44/site_perl    \
             -D vendorlib=/usr/lib/perl5/5.44/vendor_perl \
             -D vendorarch=/usr/lib/perl5/5.44/vendor_perl
make
make install

cd /sources
rm -rf "$DIR"
echo "OK 07-perl"
