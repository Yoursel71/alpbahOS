# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libogg-1.3.6   (order.txt row 033, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/multimedia/libogg.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make check

# --- [BUILD] ---
# Install libogg by running the following commands:
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/libogg-1.3.6 &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
