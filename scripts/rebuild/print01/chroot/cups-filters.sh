# PRINT-01: BLFS 13.1 pst/cups-filters.html (the book's sed and security patch).
set -e
sed -i '/proc_func)()/s/()/(FILE*, FILE*, void*)/' filter/foomatic-rip/process.h
patch -Np1 -i ../cups-filters-2.0.1-security_fix-1.patch
./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/cups-filters-2.0.1 CFLAGS="-O2 -march=x86-64 -mtune=generic" CXXFLAGS="-O2 -march=x86-64 -mtune=generic"
make
make DESTDIR="$STAGE" install
