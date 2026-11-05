# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: xf86-input-evdev-2.11.0   (order.txt row 174, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/x7driver.html#xorg-evdev-driver
# section: anchor #xorg-evdev-driver

# --- [BUILD] ---
# Install Xorg Evdev Driver by running the following commands:
./configure $XORG_CONFIG &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
