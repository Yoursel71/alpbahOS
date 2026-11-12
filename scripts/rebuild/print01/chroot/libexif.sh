# PRINT-01: BLFS 13.1 general/libexif.html.
set -e
./configure --prefix=/usr --disable-static --with-doc-dir=/usr/share/doc/libexif-0.6.26 CFLAGS="-O2 -march=x86-64 -mtune=generic"
make
make DESTDIR="$STAGE" install
