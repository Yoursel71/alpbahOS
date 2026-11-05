# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libXau-1.0.12   (order.txt row 070, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/libXau.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make check

# --- [BUILD] ---
# Install libXau by running the following commands:
./configure $XORG_CONFIG &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
