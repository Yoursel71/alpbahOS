# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libndp-1.9   (order.txt row 063, REQ-PROM)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/basicnet/libndp.html

# --- [BUILD] ---
# Install libndp by running the following command:
./configure --prefix=/usr        \
            --sysconfdir=/etc    \
            --localstatedir=/var \
            --disable-static     &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
