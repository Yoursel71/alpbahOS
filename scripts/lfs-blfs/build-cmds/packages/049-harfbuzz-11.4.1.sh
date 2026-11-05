# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: harfbuzz-11.4.1   (order.txt row 049, REC-INC)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/harfbuzz.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): ninja test

# --- [BUILD,INSTALL] ---
# Install HarfBuzz by running the following commands:
mkdir build &&
cd    build &&

meson setup ..             \
      --prefix=/usr        \
      --buildtype=release  \
      -D graphite2=enabled &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install
