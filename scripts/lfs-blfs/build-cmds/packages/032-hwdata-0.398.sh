# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: hwdata-0.398   (order.txt row 032, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/hwdata.html

# --- [BUILD] ---
# Install hwdata by running the following commands:
./configure --prefix=/usr --disable-blacklist

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
