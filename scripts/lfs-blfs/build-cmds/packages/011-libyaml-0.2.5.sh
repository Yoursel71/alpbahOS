# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libyaml-0.2.5   (order.txt row 011, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/libyaml.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make check

# --- [BUILD] ---
# Install libyaml by running the following commands:
./configure --prefix=/usr --disable-static &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
