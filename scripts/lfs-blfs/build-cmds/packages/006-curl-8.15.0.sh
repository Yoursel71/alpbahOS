# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: curl-8.15.0   (order.txt row 006, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/basicnet/curl.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make test

# --- [BUILD] ---
# Install cURL by running the following commands:
./configure --prefix=/usr    \
            --disable-static \
            --with-openssl   \
            --with-ca-path=/etc/ssl/certs &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install &&

rm -rf docs/examples/.deps &&

find docs \( -name Makefile\* -o  \
             -name \*.1       -o  \
             -name \*.3       -o  \
             -name CMakeLists.txt \) -delete &&

cp -v -R docs -T /usr/share/doc/curl-8.15.0
