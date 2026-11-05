# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libwacom-2.16.1   (order.txt row 120, REQ-PROM)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/libwacom.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): ninja test

# --- [BUILD,INSTALL] ---
# Install libwacom by running the following commands:
mkdir build &&
cd    build &&

meson setup ..            \
      --prefix=/usr       \
      --buildtype=release \
      -D tests=disabled    &&
ninja

# --- [INSTALL,ROOT] ---
# If upgrading from a previous version of libwacom, remove the old device database installation to
# prevent a potential duplicated match of devices in case some old database files are not
# overwritten:
rm -rf /usr/share/libwacom

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install
