# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: qca-2.3.10   (order.txt row 193, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/qca.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make test

# --- [BUILD] ---
# Fix the location of the CA certificates:
sed -i 's@cert.pem@certs/ca-bundle.crt@' CMakeLists.txt

# --- [BUILD,INSTALL] ---
# Install Qca by running the following commands:
mkdir build &&
cd    build &&

cmake -D CMAKE_INSTALL_PREFIX=$QT6DIR            \
      -D CMAKE_BUILD_TYPE=Release                \
      -D QT6=ON                                  \
      -D QCA_INSTALL_IN_QT_PREFIX=ON             \
      -D QCA_MAN_INSTALL_DIR:PATH=/usr/share/man \
      .. &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
