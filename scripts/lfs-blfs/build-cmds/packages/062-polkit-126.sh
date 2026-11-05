# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: polkit-126   (order.txt row 062, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/postlfs/polkit.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): ninja test

# --- [INSTALL,ROOT] ---
# There should be a dedicated user and group to take control of the polkitd daemon after it is
# started. Issue the following commands as the root user:
groupadd -fg 27 polkitd &&
useradd -c "PolicyKit Daemon Owner" -d /etc/polkit-1 -u 27 \
        -g polkitd -s /bin/false polkitd

# --- [BUILD,INSTALL] ---
# Install Polkit by running the following commands:
mkdir build &&
cd    build &&

meson setup ..                   \
      --prefix=/usr              \
      --buildtype=release        \
      -D man=true                \
      -D session_tracking=logind \
      -D tests=true

# --- [BUILD] ---
# Build the package:
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install
