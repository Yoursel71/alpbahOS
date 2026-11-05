# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: opencv-4.12.0   (order.txt row 277, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/opencv.html

# --- [BUILD,OPTIONAL] ---
# If you downloaded the optional modules, unpack them now:
tar -xf ../opencv_contrib-4.12.0.tar.gz

# --- [BUILD,INSTALL] ---
# Install opencv by running the following commands:
mkdir build &&
cd    build &&

cmake -D CMAKE_INSTALL_PREFIX=/usr        \
      -D CMAKE_BUILD_TYPE=Release         \
      -D ENABLE_CXX11=ON                  \
      -D BUILD_PERF_TESTS=OFF             \
      -D WITH_XINE=ON                     \
      -D BUILD_TESTS=OFF                  \
      -D ENABLE_PRECOMPILED_HEADERS=OFF   \
      -D CMAKE_SKIP_INSTALL_RPATH=ON      \
      -D BUILD_WITH_DEBUG_INFO=OFF        \
      -D OPENCV_GENERATE_PKGCONFIG=ON     \
      -D CMAKE_POLICY_VERSION_MINIMUM=3.5 \
      -W no-dev  ..                       &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
