# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: polkit-qt-0.200.0   (order.txt row 195, REQ-PROM)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/kde/polkit-qt.html

# --- [BUILD,INSTALL] ---
# Install Polkit-Qt by running the following commands:
mkdir build &&
cd    build &&

cmake -D CMAKE_INSTALL_PREFIX=/usr \
      -D CMAKE_BUILD_TYPE=Release  \
      -D QT_MAJOR_VERSION=6        \
      -W no-dev .. &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
