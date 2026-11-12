# APPS-02: BLFS 13.1 general/exiv2.html. inih and brotli (book: recommended) are not in the image: off.
set -e
mkdir build && cd build
cmake -D CMAKE_INSTALL_PREFIX=/usr -D CMAKE_BUILD_TYPE=Release -D EXIV2_ENABLE_VIDEO=yes -D EXIV2_ENABLE_WEBREADY=yes \
      -D EXIV2_ENABLE_CURL=yes -D EXIV2_BUILD_SAMPLES=no -D EXIV2_ENABLE_INIH=no -D EXIV2_ENABLE_BROTLI=no \
      -D CMAKE_SKIP_INSTALL_RPATH=ON -G Ninja ..
ninja
DESTDIR="$STAGE" ninja install
