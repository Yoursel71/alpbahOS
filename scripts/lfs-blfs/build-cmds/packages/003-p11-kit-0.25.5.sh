# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: p11-kit-0.25.5   (order.txt row 003, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/postlfs/p11-kit.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): LC_ALL=C ninja test

# --- [BUILD] ---
# Prepare the distribution specific anchor hook:
sed '20,$ d' -i trust/trust-extract-compat &&

cat >> trust/trust-extract-compat << "EOF"
# Copy existing anchor modifications to /etc/ssl/local
/usr/libexec/make-ca/copy-trust-modifications

# Update trust stores
/usr/sbin/make-ca -r
EOF

# --- [BUILD,INSTALL] ---
# Install p11-kit by running the following commands:
mkdir p11-build &&
cd    p11-build &&

meson setup ..            \
      --prefix=/usr       \
      --buildtype=release \
      -D trust_paths=/etc/pki/anchors &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install &&
ln -sfv /usr/libexec/p11-kit/trust-extract-compat \
        /usr/bin/update-ca-certificates

# --- [CONFIG,ROOT] ---
# The p11-kit trust module (/usr/lib/pkcs11/p11-kit-trust.so) can be used as a drop-in replacement
# for /usr/lib/libnssckbi.so to transparently make the system CAs available to NSS aware
# applications, rather than the static list provided by /usr/lib/libnssckbi.so. As the root user,
# execute the following commands:
ln -sfv ./pkcs11/p11-kit-trust.so /usr/lib/libnssckbi.so
