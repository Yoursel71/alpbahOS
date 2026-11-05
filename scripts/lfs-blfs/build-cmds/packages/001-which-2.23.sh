# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: which-2.23   (order.txt row 001, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/which.html

# --- [BUILD] ---
# Install which by running the following commands:
./configure --prefix=/usr &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install

# --- [INSTALL,ROOT,OPTIONAL] ---
# The second option (for those who don't want to install the package) is to create a simple script
# (execute as the root user):
cat > /usr/bin/which << "EOF"
#!/bin/bash
type -pa "$@" | head -n 1 ; exit ${PIPESTATUS[0]}
EOF
chmod -v 755 /usr/bin/which
chown -v root:root /usr/bin/which
