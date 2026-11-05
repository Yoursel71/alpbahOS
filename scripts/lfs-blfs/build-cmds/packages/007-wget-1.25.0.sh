# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: wget-1.25.0   (order.txt row 007, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/basicnet/wget.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make check

# --- [BUILD] ---
# Install Wget by running the following commands:
./configure --prefix=/usr      \
            --sysconfdir=/etc  \
            --with-ssl=openssl &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
