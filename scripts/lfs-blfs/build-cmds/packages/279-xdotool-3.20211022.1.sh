# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: xdotool-3.20211022.1   (order.txt row 279, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/xdotool.html

# --- [BUILD] ---
# Install xdotool by running the following commands:
make WITHOUT_RPATH_FIX=1

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make PREFIX=/usr INSTALLMAN=/usr/share/man install
