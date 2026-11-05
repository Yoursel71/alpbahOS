# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: make-ca-1.16.1   (order.txt row 004, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/postlfs/make-ca.html

# --- [INSTALL,ROOT] ---
# To install the various certificate stores, first install the make-ca script into the correct
# location. As the root user:
make install &&
install -vdm755 /etc/ssl/local

# --- [BUILD,INSTALL,ROOT] ---
# As the root user, download the certificate source and prepare for system use with the following
# command: [Note] If running the script a second time with the same version of certdata.txt, for
# instance, to update the stores when make-ca is upgraded, or to add additional stores as the
# requisite software is installed, replace the -g switch with the -r switch in the command line.
# If packaging, run make-ca --help to see all available command line options.
/usr/sbin/make-ca -g

# --- [INSTALL,ROOT] ---
# You should periodically update the store with the above command, either manually, or via a
# systemd timer. A timer is installed at /usr/lib/systemd/system/update-pki.timer that, if
# enabled, will check for updates weekly. Execute the following commands, as the root user, to
# enable the systemd timer:
systemctl enable update-pki.timer

# --- [CONFIG,ROOT,OPTIONAL] ---
# If you need to override trust values, or otherwise need to create an OpenSSL trusted certificate
# manually from a regular PEM encoded file, you need to add trust arguments to the openssl
# command, and create a new certificate. For example, using the CAcert roots, if you want to trust
# both for all three roles, the following commands will create appropriate OpenSSL trusted
# certificates (run as the root user after Wget-1.25.0 is installed):
wget http://www.cacert.org/certs/root.crt &&
wget http://www.cacert.org/certs/class3.crt &&
openssl x509 -in root.crt -text -fingerprint -setalias "CAcert Class 1 root" \
        -addtrust serverAuth -addtrust emailProtection -addtrust codeSigning \
        > /etc/ssl/local/CAcert_Class_1_root.pem &&
openssl x509 -in class3.crt -text -fingerprint -setalias "CAcert Class 3 root" \
        -addtrust serverAuth -addtrust emailProtection -addtrust codeSigning \
        > /etc/ssl/local/CAcert_Class_3_root.pem &&
/usr/sbin/make-ca -r

# --- [CONFIG] ---
# Occasionally, there may be instances where you don't agree with Mozilla's inclusion of a
# particular certificate authority. If you'd like to override the default trust of a particular
# CA, simply create a copy of the existing certificate in /etc/ssl/local with different trust
# arguments. For example, if you'd like to distrust the "Makebelieve_CA_Root" file, run the
# following commands:
openssl x509 -in /etc/ssl/certs/Makebelieve_CA_Root.pem \
             -text \
             -fingerprint \
             -setalias "Disabled Makebelieve CA Root" \
             -addreject serverAuth \
             -addreject emailProtection \
             -addreject codeSigning \
       > /etc/ssl/local/Disabled_Makebelieve_CA_Root.pem &&
/usr/sbin/make-ca -r

# --- [CONFIG] ---
# To use the system certificates in Python3, you should set _PIP_STANDALONE_CERT to point to them,
# e.g for the bash shell:
export _PIP_STANDALONE_CERT=/etc/pki/tls/certs/ca-bundle.crt

# --- [CONFIG,ROOT] ---
# To use the system certificates in Python3 with the BLFS profiles, add the following variable to
# your system or personal profiles:
mkdir -pv /etc/profile.d &&
cat > /etc/profile.d/pythoncerts.sh << "EOF"
# Begin /etc/profile.d/pythoncerts.sh

export _PIP_STANDALONE_CERT=/etc/pki/tls/certs/ca-bundle.crt

# End /etc/profile.d/pythoncerts.sh
EOF
