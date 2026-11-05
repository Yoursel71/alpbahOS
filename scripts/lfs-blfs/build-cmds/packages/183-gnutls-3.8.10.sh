# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: gnutls-3.8.10   (order.txt row 183, REQ-PROM)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/postlfs/gnutls.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make check

# --- [BUILD] ---
# Install GnuTLS by running the following commands:
./configure --prefix=/usr \
            --docdir=/usr/share/doc/gnutls-3.8.10 \
            --with-default-trust-store-pkcs11="pkcs11:" &&
make

# --- [INSTALL,ROOT] ---
# Now, install the package as the root user:
make install
