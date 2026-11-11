# APPS-01, in the chroot of r4-root, from the unpacked xmlto-0.0.29 tree (BLFS 13.1-systemd pst/xmlto.html). The book
# sets LINKS for its text backend; alpbahOS uses lynx (found by configure at /usr/bin/lynx).
set -e
autoreconf -fiv
./configure --prefix=/usr
make
make DESTDIR="$STAGE" install
