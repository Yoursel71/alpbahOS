# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: wayland-1.24.0   (order.txt row 114, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/wayland.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): env -u XDG_RUNTIME_DIR ninja test

# --- [BUILD,INSTALL] ---
# Install Wayland by running the following commands:
mkdir build &&
cd    build &&

meson setup ..            \
      --prefix=/usr       \
      --buildtype=release \
      -D documentation=false &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install
