# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libxcvt-0.1.3   (order.txt row 111, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/libxcvt.html

# --- [BUILD,INSTALL] ---
# Install libxcvt by running the following commands:
mkdir build &&
cd    build &&

meson setup --prefix=$XORG_PREFIX --buildtype=release .. &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install
