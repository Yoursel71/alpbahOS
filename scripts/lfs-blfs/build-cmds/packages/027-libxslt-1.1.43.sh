# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libxslt-1.1.43   (order.txt row 027, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/libxslt.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make check

# --- [BUILD] ---
# Install libxslt by running the following commands:
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/libxslt-1.1.43 &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
