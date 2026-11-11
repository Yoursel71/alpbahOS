# APPS-01, in the chroot of r4-root, from the unpacked Archive-Zip-1.68 tree (BLFS 13.1-systemd
# general/perl-modules.html#perl-archive-zip; build requirement of LibreOffice).
set -e
perl Makefile.PL
make
make DESTDIR="$STAGE" install
