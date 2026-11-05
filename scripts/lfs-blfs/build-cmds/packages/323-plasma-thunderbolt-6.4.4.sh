# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: plasma-thunderbolt-6.4.4   (order.txt row 323, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/kde/plasma-all.html
# SHARED-SECTION: this page section is shared by 56 order rows (kdecoration-6.4.4, libkscreen-6.4.4, libksysguard-6.4.4, breeze-6.4.4, breeze-gtk-6.4.4, layer-shell-qt-6.4.4, plasma-activities-6.4.4, libplasma-6.4.4, kscreenlocker-6.4.4, kinfocenter-6.4.4, kglobalacceld-6.4.4, kwayland-6.4.4, aurorae-6.4.4, kwin-x11-6.4.4, kwin-6.4.4, plasma5support-6.4.4, plasma-activities-stats-6.4.4, kpipewire-6.4.4, plasma-workspace-6.4.4, plasma-disks-6.4.4, bluedevil-6.4.4, kde-gtk-config-6.4.4, kmenuedit-6.4.4, kscreen-6.4.4, kwallet-pam-6.4.4, kwrited-6.4.4, milou-6.4.4, plasma-nm-6.4.4, plasma-pa-6.4.4, plasma-workspace-wallpapers-6.4.4, polkit-kde-agent-1-6.4.4, powerdevil-6.4.4, plasma-desktop-6.4.4, kgamma-6.4.4, ksshaskpass-6.4.4, sddm-kcm-6.4.4, kactivitymanagerd-6.4.4, plasma-integration-6.4.4, xdg-desktop-portal-kde-6.4.4, drkonqi-6.4.4, plasma-vault-6.4.4, kde-cli-tools-6.4.4, systemsettings-6.4.4, plasma-thunderbolt-6.4.4, plasma-firewall-6.4.4, plasma-systemmonitor-6.4.4, qqc2-breeze-style-6.4.4, ksystemstats-6.4.4, oxygen-sounds-6.4.4, kdeplasma-addons-6.4.4, plasma-welcome-6.4.4, ocean-sound-theme-6.4.4, print-manager-6.4.4, wacomtablet-6.4.4, oxygen-6.4.4, spectacle-6.4.4); same blocks in each file.

# --- [BUILD,BOX] ---
# One way to handle this situation is to create a short bash function that automatically selects
# the appropriate method. Once the command is set in the environment, it does not need to be set
# again.
# SKIPPED-BOX: as_root()
# SKIPPED-BOX: {
# SKIPPED-BOX:   if   [ $EUID = 0 ];        then $*
# SKIPPED-BOX:   elif [ -x /usr/bin/sudo ]; then sudo $*
# SKIPPED-BOX:   else                            su -c \\"$*\\"
# SKIPPED-BOX:   fi
# SKIPPED-BOX: }
# SKIPPED-BOX:
# SKIPPED-BOX: export -f as_root

# --- [BUILD] ---
# First, start a subshell that will exit on error:
bash -e

# --- [BUILD,INSTALL] ---
# Install all of the packages by running the following commands:
while read -r line; do

    # Get the file name, ignoring comments and blank lines
    if $(echo $line | grep -E -q '^ *$|^#' ); then continue; fi
    file=$(echo $line | cut -d" " -f2)

    pkg=$(       echo $file|sed 's|^.*/||')    # Remove directory
    name=$(      echo $pkg |sed 's|-6.*$||')   # Isolate package name
    packagedir=$(echo $pkg |sed 's|\.tar.*||') # Source directory

    tar -xf $file
    pushd $packagedir

       mkdir build
       cd    build

       cmake -D CMAKE_INSTALL_PREFIX=$KF6_PREFIX \
             -D CMAKE_INSTALL_LIBEXECDIR=libexec \
             -D CMAKE_BUILD_TYPE=Release         \
             -D BUILD_QT5=OFF                    \
             -D BUILD_TESTING=OFF                \
             -W no-dev ..  &&

        make
        as_root make install
    popd


    as_root rm -rf $packagedir
    as_root /sbin/ldconfig

done < plasma-6.4.4.md5

exit

# --- [INSTALL,ROOT] ---
# If you did not set $KF6_PREFIX to /usr, create symlinks to allow display managers to find
# Plasma, and to allow the XDG Desktop Portal to be detected. As the root user:
# Setup xsessions (X11 sessions)
install -dvm 755 /usr/share/xsessions
cd /usr/share/xsessions

[ -e plasma.desktop ] ||
ln -sfv $KF6_PREFIX/share/xsessions/plasmax11.desktop 

# Setup wayland-sessions 
install -dvm 755 /usr/share/wayland-sessions
cd /usr/share/wayland-sessions

[ -e plasmawayland.desktop ] ||
ln -sfv $KF6_PREFIX/share/wayland-sessions/plasma.desktop

# Setup xdg-desktop-portal
install -dvm 755 /usr/share/xdg-desktop-portal
cd /usr/share/xdg-desktop-portal 

[ -e kde-portals.conf ] ||
ln -sfv $KF6_PREFIX/share/xdg-desktop-portal/kde-portals.conf

# Setup kde portal
install -dvm 755 /usr/share/xdg-desktop-portal/portals
cd /usr/share/xdg-desktop-portal/portals

[ -e kde.portal ] ||
ln -sfv $KF6_PREFIX/share/xdg-desktop-portal/portals/kde.portal

# --- [CONFIG,ROOT] ---
# If you built Plasma with the recommended Linux PAM support, create necessary configuration files
# by running the following commands as the root user:
cat > /etc/pam.d/kde << "EOF"
# Begin /etc/pam.d/kde

auth     requisite      pam_nologin.so
auth     required       pam_env.so

auth     required       pam_succeed_if.so uid >= 1000 quiet
auth     include        system-auth

account  include        system-account
password include        system-password
session  include        system-session

# End /etc/pam.d/kde
EOF

cat > /etc/pam.d/kde-np << "EOF"
# Begin /etc/pam.d/kde-np

auth     requisite      pam_nologin.so
auth     required       pam_env.so

auth     required       pam_succeed_if.so uid >= 1000 quiet
auth     required       pam_permit.so

account  include        system-account
password include        system-password
session  include        system-session

# End /etc/pam.d/kde-np
EOF

cat > /etc/pam.d/kscreensaver << "EOF"
# Begin /etc/pam.d/kscreensaver

auth    include system-auth
account include system-account

# End /etc/pam.d/kscreensaver
EOF
