# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: xf86-input-wacom-1.2.3   (order.txt row 175, REQ-PROM)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/x7driver.html#xorg-wacom-driver
# section: anchor #xorg-wacom-driver
# INLINE-TEST (test command given in a sentence on the page, not an active block): make check

# --- [BUILD] ---
# Install Xorg Wacom Driver by running the following commands:
./configure $XORG_CONFIG &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
