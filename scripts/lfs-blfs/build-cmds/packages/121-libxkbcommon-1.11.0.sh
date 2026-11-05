# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libxkbcommon-1.11.0   (order.txt row 121, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/libxkbcommon.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): ninja test

# --- [BUILD,INSTALL] ---
# Install libxkbcommon by running the following commands:
mkdir build &&
cd    build &&

meson setup ..             \
      --prefix=/usr        \
      --buildtype=release  \
      -D enable-docs=false &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install
