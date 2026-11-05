# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: fontconfig-2.17.1   (order.txt row 052, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/fontconfig.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make check

# --- [BUILD] ---
# Install Fontconfig by running the following commands:
./configure --prefix=/usr        \
            --sysconfdir=/etc    \
            --localstatedir=/var \
            --disable-docs       \
            --docdir=/usr/share/doc/fontconfig-2.17.1 &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install

# --- [INSTALL,ROOT] ---
# If you did not remove the --disable-docs parameter from the configure command, you can install
# the pre-generated documentation by using the following commands as the root user:
install -v -dm755 \
        /usr/share/{man/man{1,3,5},doc/fontconfig-2.17.1} &&
install -v -m644 fc-*/*.1         /usr/share/man/man1 &&
install -v -m644 doc/*.3          /usr/share/man/man3 &&
install -v -m644 doc/fonts-conf.5 /usr/share/man/man5 &&
install -v -m644 doc/*.{pdf,sgml,txt,html} \
                                  /usr/share/doc/fontconfig-2.17.1
