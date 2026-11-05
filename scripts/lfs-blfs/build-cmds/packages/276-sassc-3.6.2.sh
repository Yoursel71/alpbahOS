# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: sassc-3.6.2   (order.txt row 276, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/sassc.html

# --- [BUILD] ---
# Build the command line wrapper:
popd &&
autoreconf -fi &&

./configure --prefix=/usr &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
