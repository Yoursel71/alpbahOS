# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libical-3.0.20   (order.txt row 040, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/libical.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make test

# --- [BUILD,INSTALL] ---
# Install libical by running the following commands:
mkdir build &&
cd    build &&

cmake -D CMAKE_INSTALL_PREFIX=/usr  \
      -D CMAKE_BUILD_TYPE=Release   \
      -D SHARED_ONLY=yes            \
      -D ICAL_BUILD_DOCS=false      \
      -D GOBJECT_INTROSPECTION=true \
      -D ICAL_GLIB_VAPI=true        \
      .. &&
make -j1

# --- [BUILD] ---
# If you have Doxygen-1.14.0, Graphviz-13.1.2, and GTK-Doc-1.34.0 installed and wish to build the
# API documentation, you should remove the -D ICAL_BUILD_DOCS=false switch and issue:
make docs

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install

# --- [INSTALL,ROOT] ---
# If you have built the API documentation, install by issuing, as root user:
install -vdm755 /usr/share/doc/libical-3.0.20/html &&
cp -vr apidocs/html/* /usr/share/doc/libical-3.0.20/html
