# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: qcoro-0.12.0   (order.txt row 194, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/qcoro.html

# --- [BUILD,INSTALL] ---
# Install qcoro by running the following commands:
mkdir build &&
cd    build &&

cmake -D CMAKE_INSTALL_PREFIX=$QT6DIR \
      -D CMAKE_BUILD_TYPE=Release     \
      -D BUILD_TESTING=OFF            \
      -D QCORO_BUILD_EXAMPLES=OFF     \
      -D BUILD_SHARED_LIBS=ON         \
       ..                             &&
make

# --- [TEST] ---
# To test this package, remove the 'BUILD_TESTING=OFF' parameter above and run:
make test

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
