# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: ModemManager-1.24.2   (order.txt row 066, REQ-PROM)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/ModemManager.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): ninja test

# --- [BUILD,INSTALL] ---
# Install ModemManager by running the following commands:
mkdir build &&
cd    build &&

meson setup ..                 \
      --prefix=/usr            \
      --buildtype=release      \
      -D bash_completion=false \
      -D qrtr=false            &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install

# --- [CONFIG,ROOT] ---
# To start the ModemManager daemon at boot, enable the previously installed systemd unit by
# running the following command as the root user:
systemctl enable ModemManager
