# APPS-02: BLFS 13.1 general/poppler.html. ENABLE_GPGME=OFF: gpgmepp is not in the image (book: recommended).
set -e
mkdir build && cd build
cmake -D CMAKE_BUILD_TYPE=Release -D CMAKE_INSTALL_PREFIX=/usr -D CMAKE_PREFIX_PATH=/opt/qt6 \
      -D ENABLE_QT5=OFF -D ENABLE_UNSTABLE_API_ABI_HEADERS=ON -D ENABLE_GPGME=OFF -G Ninja ..
ninja
DESTDIR="$STAGE" ninja install
