# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: NetworkManager-1.54.0   (order.txt row 064, REQ-PROM)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/basicnet/networkmanager.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): ninja test

# --- [BUILD] ---
# Fix the python scripts so that they use Python 3:
grep -rl '^#!.*python$' | xargs sed -i '1s/python/&3/'

# --- [BUILD,INSTALL] ---
# Install NetworkManager by running the following commands:
mkdir build &&
cd    build &&

meson setup ..                    \
      --prefix=/usr               \
      --buildtype=release         \
      -D libaudit=no              \
      -D nmtui=true               \
      -D ovs=false                \
      -D ppp=false                \
      -D nbft=false               \
      -D selinux=false            \
      -D qt=false                 \
      -D session_tracking=systemd \
      -D nm_cloud_setup=false     \
      -D modem_manager=false      &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install &&
mv -v /usr/share/doc/NetworkManager{,-1.54.0}

# --- [INSTALL,ROOT] ---
# If you have not passed the -D docs=true option to meson, you can install the pregenerated manual
# pages with (as the root user):
for file in $(echo ../man/*.[1578]); do
    section=${file##*.} &&
    install -vdm 755 /usr/share/man/man$section
    install -vm 644 $file /usr/share/man/man$section/
done

# --- [INSTALL,ROOT] ---
# If you have not used -D docs=true, the pregenerated HTML documentation can also be installed
# with (as the root user):
cp -Rv ../docs/{api,libnm} /usr/share/doc/NetworkManager-1.54.0

# --- [CONFIG,ROOT] ---
# For NetworkManager to work, at least a minimal configuration file must be present. Such a file
# is not installed with make install. Issue the following command as the root user to create a
# minimal NetworkManager.conf file:
cat >> /etc/NetworkManager/NetworkManager.conf << "EOF"
[main]
plugins=keyfile
EOF

# --- [CONFIG,ROOT] ---
# To allow polkit to manage authorizations, add the following configuration file:
cat > /etc/NetworkManager/conf.d/polkit.conf << "EOF"
[main]
auth-polkit=true
EOF

# --- [CONFIG] ---
# To use something other than the built-in dhcp client (recommended if using only nmcli), use the
# following configuration (valid values include either dhcpcd or internal):
cat > /etc/NetworkManager/conf.d/dhcp.conf << "EOF"
[main]
dhcp=dhcpcd
EOF

# --- [CONFIG] ---
# To prevent NetworkManager from updating the /etc/resolv.conf file, add the following
# configuration file:
cat > /etc/NetworkManager/conf.d/no-dns-update.conf << "EOF"
[main]
dns=none
EOF

# --- [CONFIG,ROOT] ---
# To allow regular users to configure network connections, you should add them to the netdev
# group, and create a polkit rule that grants access. Run the following commands as the root user:
groupadd -fg 86 netdev &&
/usr/sbin/usermod -a -G netdev <username>

cat > /usr/share/polkit-1/rules.d/org.freedesktop.NetworkManager.rules << "EOF"
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.freedesktop.NetworkManager.") == 0 && subject.isInGroup("netdev")) {
        return polkit.Result.YES;
    }
});
EOF

# --- [CONFIG,ROOT] ---
# To start the NetworkManager daemon at boot, enable the previously installed systemd unit by
# running the following command as the root user: [Note] If using Network Manager to manage an
# interface, any previous configuration for that interface should be removed, and the interface
# brought down prior to starting Network Manager.
systemctl enable NetworkManager

# --- [CONFIG,ROOT] ---
# Starting in version 1.11.2 of NetworkManager, a systemd unit named NetworkManager-wait-
# online.service is enabled, which is used to prevent services that require network connectivity
# from starting until NetworkManager establishes a connection. To disable this behavior, run the
# following command as the root user:
systemctl disable NetworkManager-wait-online
