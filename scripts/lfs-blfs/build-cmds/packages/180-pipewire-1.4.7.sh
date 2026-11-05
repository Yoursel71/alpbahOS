# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: pipewire-1.4.7   (order.txt row 180, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/multimedia/pipewire.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): ninja test

# --- [BUILD,INSTALL] ---
# Install pipewire by running the following commands:
mkdir build &&
cd    build &&

meson setup ..                 \
      --prefix=/usr            \
      --buildtype=release      \
      -D session-managers="[]" &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install
