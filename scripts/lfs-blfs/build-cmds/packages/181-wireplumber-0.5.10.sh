# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: wireplumber-0.5.10   (order.txt row 181, REC-INC)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/multimedia/wireplumber.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): ninja test

# --- [BUILD,INSTALL] ---
# Install Wireplumber by running the following commands:
mkdir build &&
cd    build &&

meson setup --prefix=/usr --buildtype=release -D system-lua=true .. &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install

# --- [INSTALL,ROOT] ---
# Finally, rename the documentation directory to a versioned directory as the root user:
mv -v /usr/share/doc/wireplumber{,-0.5.10}

# --- [CONFIG,ROOT] ---
# Pipewire now provides it's own Pulseaudio server implementation, which causes runtime conflicts
# with the server provided by Pulseaudio itself. This generally presents itself by applications
# hanging or malfunctioning when trying to play or record audio and video. First, prevent
# Pulseaudio from starting it's own server implementation by running the following commands as the
# root user:
rm -vf /etc/xdg/autostart/pulseaudio.desktop         &&
rm -vf /etc/xdg/Xwayland-session.d/00-pulseaudio-x11 &&
sed -e '$a autospawn = no' -i /etc/pulse/client.conf

# --- [CONFIG,ROOT] ---
# Next, configure Wireplumber to start when a desktop environment is started. Run the following
# commands as the root user to enable the systemd user units:
systemctl enable --global pipewire.socket       &&
systemctl enable --global pipewire-pulse.socket &&
systemctl enable --global wireplumber
