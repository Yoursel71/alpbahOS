# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: kirigami-addons-1.9.0   (order.txt row 271, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/kde/kirigami-addons.html

# --- [BUILD,INSTALL] ---
# Install kirigami-addons by running the following commands:
mkdir build &&
cd    build &&

cmake -D CMAKE_INSTALL_PREFIX=$KF6_PREFIX \
      -D CMAKE_BUILD_TYPE=Release         \
      -D BUILD_TESTING=OFF                \
       ..                                 &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
