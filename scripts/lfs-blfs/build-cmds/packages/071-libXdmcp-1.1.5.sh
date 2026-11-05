# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libXdmcp-1.1.5   (order.txt row 071, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/libXdmcp.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make check

# --- [BUILD] ---
# Install libXdmcp by running the following commands:
./configure $XORG_CONFIG --docdir=/usr/share/doc/libXdmcp-1.1.5 &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
