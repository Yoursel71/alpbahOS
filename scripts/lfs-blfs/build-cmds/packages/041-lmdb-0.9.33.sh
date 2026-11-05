# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: lmdb-0.9.33   (order.txt row 041, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/server/lmdb.html

# --- [BUILD] ---
# Install lmdb by running the following commands:
cd libraries/liblmdb &&
make                 &&
sed -i 's| liblmdb.a||' Makefile

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make prefix=/usr install
