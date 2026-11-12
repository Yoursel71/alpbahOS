# PRINT-01: BLFS 13.1 general/pdfio.html.
set -e
./configure --prefix=/usr --disable-static --enable-shared CFLAGS="-O2 -march=x86-64 -mtune=generic"
make
make DESTDIR="$STAGE" install
mv -v "$STAGE/usr/share/doc/pdfio" "$STAGE/usr/share/doc/pdfio-1.6.4" 2>/dev/null || true
