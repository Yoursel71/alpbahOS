# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libtasn1-4.20.0   (order.txt row 002, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/libtasn1.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make check

# --- [BUILD] ---
# Install libtasn1 by running the following commands:
./configure --prefix=/usr --disable-static &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install

# --- [INSTALL,ROOT] ---
# If you did not pass the --enable-gtk-doc parameter to the configure script, you can install the
# API documentation using the following command as the root user:
make -C doc/reference install-data-local
