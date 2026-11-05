# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: cups-2.4.12   (order.txt row 184, REQ-PROM)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/pst/cups.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): LC_ALL=C make -k check

# --- [INSTALL,ROOT] ---
# You will need to add an lp user, as Cups will create some files owned by this user. (The lp user
# is the default used by Cups, but may be changed to a different user by passing a parameter to
# the configure script.) Use the following command as the root user:
useradd -c "Print Service User" -d /var/spool/cups -g lp -s /bin/false -u 9 lp

# --- [INSTALL,ROOT] ---
# You will also need a dedicated group that will contain users allowed to do Cups administrative
# tasks. Add the group by running the following command as the root user:
groupadd -g 19 lpadmin

# --- [INSTALL,ROOT,OPTIONAL] ---
# If you want to add a user to the Cups administrative group, run the following command as the
# root user:
usermod -a -G lpadmin <username>

# --- [BUILD] ---
# If you didn't install xdg-utils-1.2.1, use the following sed to change the default browser that
# will be used to access the Cups web interface:
sed -i 's#@CUPS_HTMLVIEW@#firefox#' desktop/cups.desktop.in

# --- [BUILD] ---
# Build Cups by running the following commands:
./configure --libdir=/usr/lib            \
            --with-rundir=/run/cups      \
            --with-system-groups=lpadmin \
            --with-docdir=/usr/share/cups/doc-2.4.12 &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install &&
ln -svnf ../cups/doc-2.4.12 /usr/share/doc/cups-2.4.12

# --- [INSTALL,ROOT] ---
# Create a basic Cups client configuration file by running the following command as the root user:
echo "ServerName /run/cups/cups.sock" > /etc/cups/client.conf

# --- [INSTALL,ROOT,BOX] ---
# This package installs icon files into the /usr/share/icons/hicolor hierarchy and you can improve
# system performance and memory usage by updating /usr/share/icons/hicolor/index.theme. To perform
# the update you must have GTK-3.24.50 installed and issue the following command as the root user:
# SKIPPED-BOX: gtk-update-icon-cache -qtf /usr/share/icons/hicolor

# --- [CONFIG,ROOT] ---
# Issue the following command as the root user to create the configuration file for Linux PAM:
cat > /etc/pam.d/cups << "EOF"
# Begin /etc/pam.d/cups

auth    include system-auth
account include system-account
session include system-session

# End /etc/pam.d/cups
EOF

# --- [CONFIG,ROOT] ---
# To start the cupsd daemon when something tries to access it, enable the previously installed
# systemd units by running the following command as the root user:
systemctl enable cups
