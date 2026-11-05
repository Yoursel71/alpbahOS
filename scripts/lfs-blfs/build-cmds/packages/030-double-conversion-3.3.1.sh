# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: double-conversion-3.3.1   (order.txt row 030, REC-INC)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/double-conversion.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make test

# --- [BUILD,INSTALL] ---
# Install Double-conversion by running the following commands:
mkdir build &&
cd    build &&

cmake -D CMAKE_INSTALL_PREFIX=/usr        \
      -D CMAKE_POLICY_VERSION_MINIMUM=3.5 \
      -D BUILD_SHARED_LIBS=ON             \
      -D BUILD_TESTING=ON                 \
      ..                                  &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
