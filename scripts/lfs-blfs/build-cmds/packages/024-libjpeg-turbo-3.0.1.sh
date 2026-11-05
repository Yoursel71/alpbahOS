# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libjpeg-turbo-3.0.1   (order.txt row 024, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/libjpeg.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make test

# --- [BUILD,INSTALL] ---
# Install libjpeg-turbo by running the following commands:
mkdir build &&
cd    build &&

cmake -D CMAKE_INSTALL_PREFIX=/usr        \
      -D CMAKE_BUILD_TYPE=RELEASE         \
      -D ENABLE_STATIC=FALSE              \
      -D CMAKE_INSTALL_DEFAULT_LIBDIR=lib \
      -D CMAKE_POLICY_VERSION_MINIMUM=3.5 \
      -D CMAKE_SKIP_INSTALL_RPATH=ON      \
      -D CMAKE_INSTALL_DOCDIR=/usr/share/doc/libjpeg-turbo-3.0.1 \
      .. &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
