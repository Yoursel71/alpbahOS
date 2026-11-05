# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libpwquality-1.4.5   (order.txt row 060, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/postlfs/libpwquality.html

# --- [BUILD] ---
# Install libpwquality by running the following commands:
./configure --prefix=/usr                      \
            --disable-static                   \
            --with-securedir=/usr/lib/security \
            --disable-python-bindings          &&
make &&
pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir $PWD/python

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install &&
pip3 install --no-index --find-links dist --no-user pwquality

# --- [CONFIG,ROOT] ---
# libpwquality is intended to be a functional replacement for the now-obsolete pam_cracklib.so PAM
# module. To configure the system to use the pam_pwquality module, execute the following commands
# as the root user:
mv /etc/pam.d/system-password{,.orig} &&
cat > /etc/pam.d/system-password << "EOF"
# Begin /etc/pam.d/system-password

# check new passwords for strength (man pam_pwquality)
password  required    pam_pwquality.so   authtok_type=UNIX retry=1 difok=1 \
                                         minlen=8 dcredit=0 ucredit=0      \
                                         lcredit=0 ocredit=0 minclass=1    \
                                         maxrepeat=0 maxsequence=0         \
                                         maxclassrepeat=0 gecoscheck=0     \
                                         dictcheck=1 usercheck=1           \
                                         enforcing=1 badwords=""           \
                                         dictpath=/usr/lib/cracklib/pw_dict

# use yescrypt hash for encryption, use shadow, and try to use any
# previously defined authentication token (chosen password) set by any
# prior module.
password  required    pam_unix.so        yescrypt shadow try_first_pass

# End /etc/pam.d/system-password
EOF
