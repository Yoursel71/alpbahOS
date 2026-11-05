# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: utfcpp-4.0.6   (order.txt row 010, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/utfcpp.html

# --- [BUILD,INSTALL] ---
# Install utfcpp by running the following commands:
mkdir build &&
cd    build &&

cmake -D CMAKE_INSTALL_PREFIX=/usr ..

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
