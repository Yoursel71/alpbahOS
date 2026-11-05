# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: duktape-2.7.0   (order.txt row 046, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/duktape.html

# --- [BUILD] ---
# Install duktape by running the following commands:
sed -i 's/-Os/-O2/' Makefile.sharedlibrary
make -f Makefile.sharedlibrary INSTALL_PREFIX=/usr

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make -f Makefile.sharedlibrary INSTALL_PREFIX=/usr install
