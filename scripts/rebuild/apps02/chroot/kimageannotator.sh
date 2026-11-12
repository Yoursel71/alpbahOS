# APPS-02, in the chroot of r4-root: BLFS 13.1 x/kimageannotator.html (KF6_PREFIX=/usr, Qt 6 in /opt/qt6; DESTDIR stage).
set -e
mkdir build && cd build
cmake -D CMAKE_INSTALL_PREFIX=/usr -D CMAKE_PREFIX_PATH=/opt/qt6 -D CMAKE_BUILD_TYPE=Release -D BUILD_TESTING=OFF \
      -D BUILD_SHARED_LIBS=ON -D BUILD_WITH_QT6=ON -W no-author ..
make
make DESTDIR="$STAGE" install
