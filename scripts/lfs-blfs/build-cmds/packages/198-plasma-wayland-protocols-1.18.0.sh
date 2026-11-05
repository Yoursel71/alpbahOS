# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: plasma-wayland-protocols-1.18.0   (order.txt row 198, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/kde/plasma-wayland-protocols.html

# --- [BUILD,INSTALL] ---
# Install Plasma-wayland-protocols by running the following commands:
mkdir build &&
cd    build &&

cmake -D CMAKE_INSTALL_PREFIX=/usr ..

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
