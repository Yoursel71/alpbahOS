# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: mtdev-1.1.7   (order.txt row 117, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/mtdev.html

# --- [BUILD] ---
# Install mtdev by running the following commands:
./configure --prefix=/usr --disable-static &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
