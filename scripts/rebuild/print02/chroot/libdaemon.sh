# PRINT-01 step 2: BLFS 13.1 general/libdaemon.html (no doxygen reference docs).
set -e
./configure --prefix=/usr --disable-static CFLAGS="-O2 -march=x86-64 -mtune=generic"
make
make DESTDIR="$STAGE" docdir=/usr/share/doc/libdaemon-0.14 install
rm -f "$STAGE"/usr/lib/*.la
