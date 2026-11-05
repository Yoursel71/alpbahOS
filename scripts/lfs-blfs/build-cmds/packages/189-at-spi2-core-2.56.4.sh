# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: at-spi2-core-2.56.4   (order.txt row 189, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/at-spi2-core.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): dbus-run-session ninja test

# --- [BUILD,INSTALL] ---
# Install At-Spi2 Core by running the following commands:
mkdir build &&
cd    build &&

meson setup ..                  \
      --prefix=/usr             \
      --buildtype=release       \
      -D gtk2_atk_adaptor=false &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install
