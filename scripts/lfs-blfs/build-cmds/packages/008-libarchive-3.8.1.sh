# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libarchive-3.8.1   (order.txt row 008, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/libarchive.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make check

# --- [BUILD] ---
# Install libarchive by running the following commands:
./configure --prefix=/usr --disable-static &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install

# --- [INSTALL,ROOT] ---
# Still as the root user, create a symlink so we can use bsdunzip as unzip, instead of relying on
# the unmaintained Unzip package:
ln -sfv bsdunzip /usr/bin/unzip
