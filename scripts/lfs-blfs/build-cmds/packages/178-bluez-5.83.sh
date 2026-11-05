# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: bluez-5.83   (order.txt row 178, REQ-PROM)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/bluez.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make check

# --- [BUILD] ---
# Install BlueZ by running the following commands:
./configure --prefix=/usr         \
            --sysconfdir=/etc     \
            --localstatedir=/var  \
            --disable-manpages    \
            --enable-library      &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install &&
ln -svf ../libexec/bluetooth/bluetoothd /usr/sbin

# --- [INSTALL,ROOT] ---
# Install the main configuration file as the root user:
install -v -dm755 /etc/bluetooth &&
install -v -m644 src/main.conf /etc/bluetooth/main.conf

# --- [INSTALL,ROOT,OPTIONAL] ---
# If desired, install the API documentation as the root user:
install -v -dm755 /usr/share/doc/bluez-5.83 &&
install -v -m644 doc/*.txt /usr/share/doc/bluez-5.83

# --- [CONFIG,ROOT,OPTIONAL] ---
# /etc/bluetooth/main.conf is installed automatically during the installation. Additionally, there
# are two supplementary configuration files. You can optionally install the following files as the
# root user:
cat > /etc/bluetooth/rfcomm.conf << "EOF"
# Start rfcomm.conf
# Set up the RFCOMM configuration of the Bluetooth subsystem in the Linux kernel.
# Use one line per command
# See the rfcomm man page for options


# End of rfcomm.conf
EOF

# --- [CONFIG,ROOT] ---
# (section: Configuration Files)
cat > /etc/bluetooth/uart.conf << "EOF"
# Start uart.conf
# Attach serial devices via UART HCI to BlueZ stack
# Use one line per device
# See the hciattach man page for options

# End of uart.conf
EOF

# --- [CONFIG,ROOT] ---
# To start the bluetoothd daemon at boot, enable the previously installed systemd unit by running
# the following command as the root user:
systemctl enable bluetooth

# --- [CONFIG,ROOT] ---
# To start the obexd daemon for a user session (to support some Bluetooth programs using it),
# enable the previously installed systemd unit for all users by running the following command as
# the root user:
systemctl enable --global obex
