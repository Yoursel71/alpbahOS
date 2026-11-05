# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libgudev-238   (order.txt row 065, REQ-PROM)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/libgudev.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): ninja test

# --- [BUILD,INSTALL] ---
# Install libgudev by running the following commands:
mkdir build &&
cd    build &&

meson setup --prefix=/usr --buildtype=release .. &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install
