# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: breeze-icons-6.17.0   (order.txt row 197, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/breeze-icons.html

# --- [BUILD,INSTALL] ---
# Install Breeze Icons by running the following commands:
mkdir build &&
cd    build &&

cmake -D CMAKE_INSTALL_PREFIX=/usr \
      -D BUILD_TESTING=OFF         \
      -W no-dev ..                 &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
