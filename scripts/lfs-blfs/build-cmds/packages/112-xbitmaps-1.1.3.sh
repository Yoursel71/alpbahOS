# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: xbitmaps-1.1.3   (order.txt row 112, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/xbitmaps.html

# --- [BUILD] ---
# Install xbitmaps by running the following commands:
./configure $XORG_CONFIG

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
