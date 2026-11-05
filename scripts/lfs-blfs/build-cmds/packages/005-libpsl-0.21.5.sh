# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libpsl-0.21.5   (order.txt row 005, REQ-PROM)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/basicnet/libpsl.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): ninja test

# --- [BUILD,INSTALL] ---
# Install libpsl by running the following commands:
mkdir build &&
cd    build &&

meson setup --prefix=/usr --buildtype=release &&

ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install
