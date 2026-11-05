# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: systemd-257.8   (order.txt row 061, LFS-REBUILD)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/systemd.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): ninja test

# --- [BUILD] ---
# Remove two unneeded groups, render and sgx, from the default udev rules:
sed -i -e 's/GROUP="render"/GROUP="video"/' \
       -e 's/GROUP="sgx", //' rules.d/50-udev-default.rules.in

# --- [BUILD,INSTALL] ---
# Rebuild systemd by running the following commands:
mkdir build &&
cd    build &&

meson setup ..                 \
      --prefix=/usr            \
      --buildtype=release      \
      -D default-dnssec=no     \
      -D firstboot=false       \
      -D install-tests=false   \
      -D ldconfig=false        \
      -D man=auto              \
      -D sysusers=false        \
      -D rpmmacrosdir=no       \
      -D homed=disabled        \
      -D userdb=false          \
      -D mode=release          \
      -D pam=enabled           \
      -D pamconfdir=/etc/pam.d \
      -D dev-kvm-mode=0660     \
      -D nobody-group=nogroup  \
      -D sysupdate=disabled    \
      -D ukify=disabled        \
      -D docdir=/usr/share/doc/systemd-257.8 &&

ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install

# --- [CONFIG,ROOT] ---
# The /etc/pam.d/system-session file needs to be modified and a new file needs to be created in
# order for systemd-logind to work correctly. Run the following commands as the root user:
grep 'pam_systemd' /etc/pam.d/system-session ||
cat >> /etc/pam.d/system-session << "EOF"
# Begin Systemd addition

session  required    pam_loginuid.so
session  optional    pam_systemd.so

# End Systemd addition
EOF

cat > /etc/pam.d/systemd-user << "EOF"
# Begin /etc/pam.d/systemd-user

account  required    pam_access.so
account  include     system-account

session  required    pam_env.so
session  required    pam_limits.so
session  required    pam_loginuid.so
session  optional    pam_keyinit.so force revoke
session  optional    pam_systemd.so

auth     required    pam_deny.so
password required    pam_deny.so

# End /etc/pam.d/systemd-user
EOF

# --- [CONFIG,ROOT] ---
# As the root user, replace the running systemd manager (the init process) with the systemd
# executable newly built and installed:
systemctl daemon-reexec
