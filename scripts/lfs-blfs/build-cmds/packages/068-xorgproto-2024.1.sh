# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: xorgproto-2024.1   (order.txt row 068, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/xorgproto.html

# --- [BUILD,INSTALL] ---
# Install xorgproto by running the following commands:
mkdir build &&
cd    build &&

meson setup --prefix=$XORG_PREFIX .. &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install &&
mv -v $XORG_PREFIX/share/doc/xorgproto{,-2024.1}
