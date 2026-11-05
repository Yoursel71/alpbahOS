# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: shared-mime-info-2.4   (order.txt row 054, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/shared-mime-info.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): ninja test

# --- [BUILD,TEST,OPTIONAL] ---
# If you wish to run the test suite, you must first extract the xdgmime tarball into the current
# directory, and compile it so that meson can find it:
tar -xf ../xdgmime.tar.xz &&
make -C xdgmime

# --- [BUILD,INSTALL] ---
# Now build the package:
mkdir build &&
cd    build &&

meson setup --prefix=/usr --buildtype=release -D update-mimedb=true .. &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install
