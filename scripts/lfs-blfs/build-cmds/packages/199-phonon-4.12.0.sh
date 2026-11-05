# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: phonon-4.12.0   (order.txt row 199, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/kde/phonon.html

# --- [BUILD,INSTALL] ---
# Install Phonon by running the following commands:
mkdir build &&
cd    build &&

cmake -D CMAKE_INSTALL_PREFIX=/usr \
      -D CMAKE_BUILD_TYPE=Release  \
      -D PHONON_BUILD_QT5=OFF      \
      -W no-dev .. &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
