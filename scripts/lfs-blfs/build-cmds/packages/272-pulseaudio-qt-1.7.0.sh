# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: pulseaudio-qt-1.7.0   (order.txt row 272, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/kde/pulseaudio-qt.html

# --- [BUILD,INSTALL] ---
# Install pulseaudio-qt by running the following commands:
mkdir build &&
cd    build &&

cmake -D CMAKE_INSTALL_PREFIX=$KF6_PREFIX \
      -D CMAKE_PREFIX_PATH=$QT6DIR        \
      -D CMAKE_SKIP_INSTALL_RPATH=ON      \
      -D CMAKE_BUILD_TYPE=Release         \
      -D BUILD_TESTING=OFF                \
      .. &&
make

# --- [INSTALL,ROOT] ---
# Now as the root user:
make install
