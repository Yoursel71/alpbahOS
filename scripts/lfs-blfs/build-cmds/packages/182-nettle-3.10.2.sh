# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: nettle-3.10.2   (order.txt row 182, REQ-PROM)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/postlfs/nettle.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make check

# --- [BUILD] ---
# Install Nettle by running the following commands:
./configure --prefix=/usr --disable-static &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install &&
chmod   -v   755 /usr/lib/lib{hogweed,nettle}.so &&
install -v -m755 -d /usr/share/doc/nettle-3.10.2 &&
install -v -m644 nettle.{html,pdf} /usr/share/doc/nettle-3.10.2
