# PRINT-01: BLFS 13.1 general/qpdf.html.
set -e
mkdir build && cd build
cmake -D CMAKE_INSTALL_PREFIX=/usr -D CMAKE_BUILD_TYPE=Release -D BUILD_STATIC_LIBS=OFF \
      -D CMAKE_INSTALL_DOCDIR=/usr/share/doc/qpdf-12.4.0 -D CMAKE_C_FLAGS="-O2 -march=x86-64 -mtune=generic" ..
make
make DESTDIR="$STAGE" install
