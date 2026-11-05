# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: Linux-PAM-1.7.1   (order.txt row 058, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/postlfs/linux-pam.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): ninja test

# --- [BUILD] ---
# If you've installed docbook-xml-5.0, docbook-xsl-ns-1.79.2, libxslt-1.1.43, and Lynx-2.9.2 and
# you wish to generate the plain text format of the documentations, modify meson.build to use
# Lynx-2.9.2 instead of W3m or Elinks that BLFS does not provide:
sed -e "s/'elinks'/'lynx'/"                       \
    -e "s/'-no-numbering', '-no-references'/      \
          '-force-html', '-nonumbers', '-stdin'/" \
    -i meson.build

# --- [BUILD,INSTALL] ---
# Compile and link Linux PAM by running the following commands:
mkdir build &&
cd    build &&

meson setup ..        \
  --prefix=/usr       \
  --buildtype=release \
  -D docdir=/usr/share/doc/Linux-PAM-1.7.1 &&

ninja

# --- [INSTALL,ROOT] ---
# For a first-time installation, create a configuration file by issuing the following commands as
# the root user:
install -v -m755 -d /etc/pam.d &&

cat > /etc/pam.d/other << "EOF"
auth     required       pam_deny.so
account  required       pam_deny.so
password required       pam_deny.so
session  required       pam_deny.so
EOF

# --- [INSTALL,ROOT] ---
# For a first-time installation, remove the configuration file created earlier by issuing the
# following command as the root user:
rm -fv /etc/pam.d/other

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install &&
chmod -v 4755 /usr/sbin/unix_chkpwd

# --- [INSTALL,ROOT,OPTIONAL] ---
# If you do not have the optional dependencies installed to build the documentation and downloaded
# the optional pre-built documentation, again as the root user:
tar -C / -xvf ../../Linux-PAM-1.7.1-docs.tar.xz

# --- [CONFIG,ROOT] ---
# Now create some generic configuration files. As the root user:
install -vdm755 /etc/pam.d &&
cat > /etc/pam.d/system-account << "EOF" &&
# Begin /etc/pam.d/system-account

account   required    pam_unix.so

# End /etc/pam.d/system-account
EOF

cat > /etc/pam.d/system-auth << "EOF" &&
# Begin /etc/pam.d/system-auth

auth      required    pam_unix.so

# End /etc/pam.d/system-auth
EOF

cat > /etc/pam.d/system-session << "EOF" &&
# Begin /etc/pam.d/system-session

session   required    pam_unix.so

# End /etc/pam.d/system-session
EOF

cat > /etc/pam.d/system-password << "EOF"
# Begin /etc/pam.d/system-password

# use yescrypt hash for encryption, use shadow, and try to use any
# previously defined authentication token (chosen password) set by any
# prior module.
password  required    pam_unix.so       yescrypt shadow try_first_pass

# End /etc/pam.d/system-password
EOF

# --- [CONFIG,ROOT] ---
# Next, add a restrictive /etc/pam.d/other configuration file. With this file, programs that are
# PAM aware will not run unless a configuration file specifically for that application exists.
cat > /etc/pam.d/other << "EOF"
# Begin /etc/pam.d/other

auth        required        pam_warn.so
auth        required        pam_deny.so
account     required        pam_warn.so
account     required        pam_deny.so
password    required        pam_warn.so
password    required        pam_deny.so
session     required        pam_warn.so
session     required        pam_deny.so

# End /etc/pam.d/other
EOF
