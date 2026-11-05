# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: zxing-cpp-2.3.0   (order.txt row 056, REQ-PROM)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/zxing-cpp.html

# --- [BUILD,INSTALL] ---
# Install zxing-cpp by running the following commands:
mkdir build &&
cd    build &&

cmake -D CMAKE_INSTALL_PREFIX=/usr \
      -D CMAKE_BUILD_TYPE=Release  \
      -D ZXING_EXAMPLES=OFF        \
      -W no-dev ..                 &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
