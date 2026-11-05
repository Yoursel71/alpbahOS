# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libgpg-error-1.55   (order.txt row 038, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/libgpg-error.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make check

# --- [BUILD] ---
# Install libgpg-error by running the following commands:
./configure --prefix=/usr &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install &&
install -v -m644 -D README /usr/share/doc/libgpg-error-1.55/README
