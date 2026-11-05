# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libevdev-1.13.4   (order.txt row 118, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/x7driver.html#libevdev
# section: anchor #libevdev

# --- [BUILD,INSTALL] ---
# Install libevdev by running the following commands:
mkdir build &&
cd    build &&

meson setup ..                  \
      --prefix=$XORG_PREFIX     \
      --buildtype=release       \
      -D documentation=disabled \
      -D tests=disabled         &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install
