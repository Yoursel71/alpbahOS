# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libsndfile-1.2.2   (order.txt row 035, REQ-PROM)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/multimedia/libsndfile.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make check

# --- [BUILD] ---
# Fix building with GCC-15:
sed '/typedef enum/,/bool ;/d' -i \
  src/ALAC/alac_{en,de}coder.c

# --- [BUILD] ---
# Install libsndfile by running the following commands:
./configure --prefix=/usr    \
            --docdir=/usr/share/doc/libsndfile-1.2.2 &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
