# APPS-02, in the chroot of r4-root: BLFS 13.1 general/openjpeg2.html (commands as in the book; DESTDIR stage).
set -e
mkdir -v build && cd build
cmake -D CMAKE_BUILD_TYPE=Release -D CMAKE_INSTALL_PREFIX=/usr -D BUILD_STATIC_LIBS=OFF \
      -D CMAKE_C_FLAGS="-O2 -march=x86-64 -mtune=generic" ..
make
make DESTDIR="$STAGE" install
