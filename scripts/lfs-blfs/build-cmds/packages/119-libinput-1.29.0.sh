# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libinput-1.29.0   (order.txt row 119, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/x7driver.html#libinput
# section: anchor #libinput
# INLINE-TEST (test command given in a sentence on the page, not an active block): meson configure -D tests=true && ninja test
# INLINE-TEST (test command given in a sentence on the page, not an active block): meson test --suite=root

# --- [BUILD,INSTALL] ---
# Install libinput by running the following commands:
mkdir build &&
cd    build &&

meson setup ..              \
      --prefix=$XORG_PREFIX \
      --buildtype=release   \
      -D debug-gui=false    \
      -D tests=false        \
      -D libwacom=false     \
      -D udev-dir=/usr/lib/udev &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install

# --- [INSTALL,ROOT] ---
# If you have passed -D documentation=true to meson, you can install the generated documentation
# by running the following commands as the root user:
install -v -dm755      /usr/share/doc/libinput-1.29.0/html &&
cp -rv Documentation/* /usr/share/doc/libinput-1.29.0/html
