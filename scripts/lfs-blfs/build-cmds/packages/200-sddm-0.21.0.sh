# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: sddm-0.21.0   (order.txt row 200, REQ-PROM)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/sddm.html

# --- [INSTALL,ROOT] ---
# First, create a dedicated user and group to take control of the sddm daemon after it is started.
# Issue the following commands as the root user:
groupadd -g 64 sddm &&
useradd  -c "sddm Daemon" \
         -d /var/lib/sddm \
         -u 64 -g sddm    \
         -s /bin/false sddm

# --- [BUILD,INSTALL] ---
# Install sddm by running the following commands:
mkdir build &&
cd    build &&

cmake -D CMAKE_INSTALL_PREFIX=/usr        \
      -D CMAKE_BUILD_TYPE=Release         \
      -D CMAKE_POLICY_VERSION_MINIMUM=3.5 \
      -D RUNTIME_DIR=/run/sddm            \
      -D BUILD_MAN_PAGES=ON               \
      -D BUILD_WITH_QT6=ON                \
      -D DATA_INSTALL_DIR=/usr/share/sddm \
      -D DBUS_CONFIG_FILENAME=sddm_org.freedesktop.DisplayManager.conf \
      .. &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install &&
install -v -dm755 -o sddm -g sddm /var/lib/sddm
/usr/bin/sddm --example-config > /etc/sddm.conf

# --- [CONFIG,ROOT] ---
# Normally, you want to edit this file. For example, if Xorg is installed in /opt, use your
# preferred editor as the root user to replace the default XauthPath value by /opt/xorg/bin/xauth.
# Or, as the root user, issue:
sed -i.orig '/ServerPath/ s|usr|opt/xorg|' /etc/sddm.conf

# --- [CONFIG,ROOT] ---
# For security reasons, you normally want the default ServerArguments=-nolisten tcp, unless a
# remote machine needs access to the local X server. In that case, as the root user, issue:
sed -i 's/-nolisten tcp//' /etc/sddm.conf

# --- [CONFIG,ROOT] ---
# Desktop (Notebook) users, normally want the Num Lock key on (off). For that, as root, issue:
sed -i '/Numlock/s/none/on/' /etc/sddm.conf

# --- [CONFIG,ROOT] ---
# By default, a virtual keyboard is presented for the user. If this is not desired, run as root:
sed -i 's/qtvirtualkeyboard//' /etc/sddm.conf

# --- [CONFIG,ROOT] ---
# Enable the pre-installed systemd unit by running the following command as the root user:
systemctl enable sddm

# --- [CONFIG,ROOT] ---
# If you have built sddm with Linux PAM support, create the necessary configuration files by
# running the following commands as the root user:
cat > /etc/pam.d/sddm << "EOF" &&
# Begin /etc/pam.d/sddm

auth     requisite      pam_nologin.so
auth     required       pam_env.so

auth     required       pam_succeed_if.so uid >= 1000 quiet
auth     include        system-auth

account  include        system-account
password include        system-password

session  required       pam_limits.so
session  include        system-session

# End /etc/pam.d/sddm
EOF

cat > /etc/pam.d/sddm-autologin << "EOF" &&
# Begin /etc/pam.d/sddm-autologin

auth     requisite      pam_nologin.so
auth     required       pam_env.so

auth     required       pam_succeed_if.so uid >= 1000 quiet
auth     required       pam_permit.so

account  include        system-account

password required       pam_deny.so

session  required       pam_limits.so
session  include        system-session

# End /etc/pam.d/sddm-autologin
EOF

cat > /etc/pam.d/sddm-greeter << "EOF"
# Begin /etc/pam.d/sddm-greeter

auth     required       pam_env.so
auth     required       pam_permit.so

account  required       pam_permit.so
password required       pam_deny.so
session  required       pam_unix.so
-session optional       pam_systemd.so

# End /etc/pam.d/sddm-greeter
EOF

# --- [CONFIG] ---
# In order to see the theme without leaving the session, issue:
sddm-greeter --test-mode --theme <theme path>
