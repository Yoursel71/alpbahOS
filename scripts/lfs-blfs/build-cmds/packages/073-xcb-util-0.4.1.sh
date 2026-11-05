# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: xcb-util-0.4.1   (order.txt row 073, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/xcb-util.html

# --- [BUILD] ---
# Install xcb-util by running the following commands:
./configure $XORG_CONFIG &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
