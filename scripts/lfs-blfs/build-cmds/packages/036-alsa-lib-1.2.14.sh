# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: alsa-lib-1.2.14   (order.txt row 036, REC-INC)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/multimedia/alsa-lib.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make check

# --- [TEST] ---
# If running the test suite, remove a test that GCC-15 or later fails to build:
sed 's/playmidi1//' -i test/Makefile.am &&
autoreconf -fi

# --- [BUILD] ---
# Install ALSA Library by running the following commands:
./configure &&
make

# --- [BUILD] ---
# If you have Doxygen installed and you wish to build the library API documentation, run the
# following commands from the top-level directory of the source tree:
make doc

# --- [INSTALL,ROOT] ---
# Now, as the root user, install the package and recommended configuration files:
make install &&
tar -C /usr/share/alsa --strip-components=1 -xf ../alsa-ucm-conf-1.2.14.tar.bz2

# --- [INSTALL,ROOT] ---
# To install the API documentation, run the following command as the root user:
install -v -d -m755 /usr/share/doc/alsa-lib-1.2.14/html/search &&
install -v -m644 doc/doxygen/html/*.* \
                /usr/share/doc/alsa-lib-1.2.14/html &&
install -v -m644 doc/doxygen/html/search/* \
                /usr/share/doc/alsa-lib-1.2.14/html/search
