# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: taglib-2.1.1   (order.txt row 278, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/multimedia/taglib.html

# --- [BUILD,INSTALL] ---
# Install Taglib by running the following commands:
mkdir build &&
cd    build &&

cmake -D CMAKE_INSTALL_PREFIX=/usr \
      -D CMAKE_BUILD_TYPE=Release  \
      -D BUILD_SHARED_LIBS=ON \
      .. &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
