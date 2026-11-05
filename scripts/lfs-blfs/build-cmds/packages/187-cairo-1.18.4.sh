# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: cairo-1.18.4   (order.txt row 187, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/cairo.html

# --- [BUILD,INSTALL] ---
# Install Cairo by running the following commands:
mkdir build &&
cd    build &&

meson setup --prefix=/usr --buildtype=release .. &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install
