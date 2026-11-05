# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libcanberra-0.30   (order.txt row 037, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/multimedia/libcanberra.html

# --- [BUILD] ---
# First, apply a patch to fix an issue causing some applications to crash in Wayland-based desktop
# environments:
patch -Np1 -i ../libcanberra-0.30-wayland-1.patch

# --- [BUILD] ---
# Install libcanberra by running the following commands:
./configure --prefix=/usr --disable-oss &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make docdir=/usr/share/doc/libcanberra-0.30 install
