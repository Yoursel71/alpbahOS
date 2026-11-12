# PRINT-01: BLFS 13.1 pst/libppd.html.
set -e
./configure --prefix=/usr --disable-static --with-cups-rundir=/run/cups --enable-ppdc-utils \
            --docdir=/usr/share/doc/libppd-2.1.1 CFLAGS="-O2 -march=x86-64 -mtune=generic" CXXFLAGS="-O2 -march=x86-64 -mtune=generic"
make
make DESTDIR="$STAGE" install
