# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: xcursor-themes-1.0.7   (order.txt row 163, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/xcursor-themes.html

# --- [BUILD] ---
# Install xcursor-themes by running the following commands:
./configure --prefix=/usr &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
