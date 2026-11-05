# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: util-macros-1.20.2   (order.txt row 067, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/util-macros.html

# --- [BUILD] ---
# Install util-macros by running the following commands:
./configure $XORG_CONFIG

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
