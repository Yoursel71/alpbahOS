# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: hicolor-icon-theme-0.18   (order.txt row 055, REC-INC)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/hicolor-icon-theme.html

# --- [BUILD,INSTALL] ---
# Install hicolor-icon-theme by running the following commands:
mkdir build &&
cd    build &&

meson setup --prefix=/usr --buildtype=release .. &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install
