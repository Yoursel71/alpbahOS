# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libqalculate-5.7.0   (order.txt row 044, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/libqalculate.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make check

# --- [BUILD] ---
# Install libqalculate by running the following commands:
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/libqalculate-5.7.0 &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install

# --- [INSTALL,ROOT] ---
# The libtool archive file from this package is referring to the libraries from ICU-77.1. Such a
# reference may cause packages depending on this package to be unnecessary linked against the ICU
# libraries and increase the burden to rebuild packages if ICU is updated to a new major version.
# As we've explained in Libtool archive (.la) files, these libtool archive files are unneeded
# anyway. So as the root user, remove the libtool archive file now:
rm -v /usr/lib/libqalculate.la
