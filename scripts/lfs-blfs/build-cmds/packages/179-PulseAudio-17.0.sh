# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: PulseAudio-17.0   (order.txt row 179, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/multimedia/pulseaudio.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): ninja test

# --- [BUILD,INSTALL] ---
# Install PulseAudio by running the following commands:
mkdir build &&
cd    build &&

meson setup --prefix=/usr       \
            --buildtype=release \
            -D database=gdbm    \
            -D doxygen=false    \
            -D bluez5=disabled  \
            -D tests=false      \
            ..                  &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install

# --- [INSTALL,ROOT] ---
# Running PulseAudio as a system-wide daemon is possible but not recommended. See
# https://www.freedesktop.org/wiki/Software/PulseAudio/Documentation/User/SystemWide/ for more
# information. While still as the root user, remove the D-Bus configuration file for the system
# wide daemon to avoid creating unnecessary system users and groups:
rm /usr/share/dbus-1/system.d/pulseaudio-system.conf
