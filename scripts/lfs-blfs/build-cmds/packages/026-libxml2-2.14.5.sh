# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libxml2-2.14.5   (order.txt row 026, REC-INC)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/libxml2.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make check > check.log

# --- [BUILD] ---
# Install libxml2 by running the following commands:
./configure --prefix=/usr     \
            --sysconfdir=/etc \
            --disable-static  \
            --with-history    \
            --with-icu        \
            PYTHON=/usr/bin/python3 \
            --docdir=/usr/share/doc/libxml2-2.14.5 &&
make

# --- [TEST,OPTIONAL] ---
# If you downloaded the test suite, issue the following command:
tar xf ../xmlts20130923.tar.gz

# --- [TEST,ROOT,BOX] ---
# The tests use http://localhost/ to test parsing of external entities. If the machine where you
# run the tests serves as a web site, the tests may hang, depending on the content of the file
# served. It is therefore recommended to shut down the server during the tests, as the root user:
# SKIPPED-BOX: systemctl stop httpd.service

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install

# --- [INSTALL,ROOT] ---
# Finally, prevent some packages from unnecessarily linking to ICU using the following commands as
# the root user:
rm -vf /usr/lib/libxml2.la &&
sed '/libs=/s/xml2.*/xml2"/' -i /usr/bin/xml2-config
