# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: xcb-proto-1.17.0   (order.txt row 069, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/xcb-proto.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make check

# --- [BUILD] ---
# Install xcb-proto by running the following commands:
PYTHON=python3 ./configure $XORG_CONFIG

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install

# --- [INSTALL,ROOT] ---
# If you are upgrading from version 1.15.1 or lower, the old pkgconfig file needs to be removed.
# Issue, as the root user:
rm -f $XORG_PREFIX/lib/pkgconfig/xcb-proto.pc
