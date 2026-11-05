# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: xkeyboard-config-2.45   (order.txt row 113, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/xkeyboard-config.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): ninja test

# --- [BUILD,INSTALL] ---
# Install XKeyboardConfig by running the following commands:
mkdir build &&
cd    build &&

meson setup --prefix=$XORG_PREFIX --buildtype=release .. &&
ninja

# --- [INSTALL,ROOT,BOX] ---
# If upgrading from version 2.44 or earlier, the installation will fail if some files are not
# symbolic links. To fix this, run as the root user:
# SKIPPED-BOX: if [ -d $XORG_PREFIX/share/X11/xkb ]; then
# SKIPPED-BOX:   rm -rf $XORG_PREFIX/share/X11/xkb
# SKIPPED-BOX:   rm -f  $XORG_PREFIX/share/man/man7/xkeyboard-config.7
# SKIPPED-BOX:   rm -f  $XORG_PREFIX/share/pkgconfig/xkeyboard-config.pc
# SKIPPED-BOX: fi

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install
