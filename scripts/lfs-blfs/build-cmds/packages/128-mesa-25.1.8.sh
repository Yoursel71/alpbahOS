# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: mesa-25.1.8   (order.txt row 128, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/mesa.html

# --- [TEST] ---
# If you have downloaded the xdemos patch (needed if testing the Xorg installation per BLFS
# instructions), apply it by running the following command:
patch -Np1 -i ../mesa-add_xdemos-4.patch

# --- [BUILD,INSTALL] ---
# Install Mesa by running the following commands:
mkdir build &&
cd    build &&

meson setup ..                 \
      --prefix=$XORG_PREFIX    \
      --buildtype=release      \
      -D platforms=x11,wayland \
      -D gallium-drivers=auto  \
      -D vulkan-drivers=auto   \
      -D valgrind=disabled     \
      -D video-codecs=all      \
      -D libunwind=disabled    &&

ninja

# --- [BUILD,TEST] ---
# To test the results, issue:
meson configure -D build-tests=true &&
sed '/float rsqrtf/,/^}/d' \
    -i ../src/gallium/drivers/llvmpipe/lp_test_arit.c &&
ninja test

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install

# --- [INSTALL,ROOT,OPTIONAL] ---
# If desired, install the optional documentation by running the following commands as the root
# user:
cp -rv ../docs -T /usr/share/doc/mesa-25.1.8
