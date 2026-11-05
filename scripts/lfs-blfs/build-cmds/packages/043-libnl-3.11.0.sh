# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libnl-3.11.0   (order.txt row 043, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/basicnet/libnl.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make check

# --- [BUILD] ---
# Install libnl by running the following commands:
./configure --prefix=/usr     \
            --sysconfdir=/etc \
            --disable-static  &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install

# --- [INSTALL,ROOT,OPTIONAL] ---
# If you wish to install the API documentation, as the root user:
mkdir -vp /usr/share/doc/libnl-3.11.0 &&
tar -xf ../libnl-doc-3.11.0.tar.gz --strip-components=1 --no-same-owner \
    -C  /usr/share/doc/libnl-3.11.0
