# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libdrm-2.4.125   (order.txt row 116, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/libdrm.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): ninja test

# --- [BUILD,INSTALL] ---
# Install libdrm by running the following commands:
mkdir build &&
cd    build &&

meson setup --prefix=$XORG_PREFIX \
            --buildtype=release   \
            -D udev=true          \
            -D valgrind=disabled  \
            ..                    &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install
