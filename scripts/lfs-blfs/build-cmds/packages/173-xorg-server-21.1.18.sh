# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: xorg-server-21.1.18   (order.txt row 173, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/xorg-server.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): ninja test

# --- [BUILD,OPTIONAL] ---
# First, if you need the TearFree option to work around screen tearing, apply the backported
# patch:
patch -Np1 -i ../xorg-server-21.1.18-tearfree_backport-1.patch

# --- [BUILD,INSTALL] ---
# Install the server by running the following commands:
mkdir build &&
cd    build &&

meson setup ..              \
      --prefix=$XORG_PREFIX \
      --localstatedir=/var  \
      -D glamor=true        \
      -D xkb_output_dir=/var/lib/xkb &&
ninja

# --- [INSTALL,ROOT] ---
# Now as the root user:
ninja install &&
mkdir -pv /etc/X11/xorg.conf.d
