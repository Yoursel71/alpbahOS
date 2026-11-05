# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libxcb-1.17.0   (order.txt row 072, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/libxcb.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make check

# --- [BUILD] ---
# Install libxcb by running the following commands:
./configure $XORG_CONFIG      \
            --without-doxygen \
            --docdir='${datadir}'/doc/libxcb-1.17.0 &&
LC_ALL=en_US.UTF-8 make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install

# --- [INSTALL,ROOT] ---
# If the package was built as a non-root user, the installed documentation is now owned by this
# user. As the root user, fix the ownership:
chown -Rv root:root $XORG_PREFIX/share/doc/libxcb-1.17.0
