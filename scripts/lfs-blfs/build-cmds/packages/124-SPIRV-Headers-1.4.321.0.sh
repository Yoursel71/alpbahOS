# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: SPIRV-Headers-1.4.321.0   (order.txt row 124, COND)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/spirv-headers.html

# --- [BUILD,INSTALL] ---
# Install SPIRV-Headers by running the following commands:
mkdir build &&
cd    build &&

cmake -D CMAKE_INSTALL_PREFIX=/usr -G Ninja .. &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install
