# PRINT-01: BLFS 13.1 pst/libcupsfilters.html.
set -e
./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/libcupsfilters-2.1.1 CFLAGS="-O2 -march=x86-64 -mtune=generic" CXXFLAGS="-O2 -march=x86-64 -mtune=generic"
make
make DESTDIR="$STAGE" install
