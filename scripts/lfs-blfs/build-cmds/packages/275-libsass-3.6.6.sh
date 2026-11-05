# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libsass-3.6.6   (order.txt row 275, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/sassc.html

# --- [BUILD] ---
# First, build the library:
tar -xf ../libsass-3.6.6.tar.gz &&
pushd libsass-3.6.6 &&

autoreconf -fi &&

./configure --prefix=/usr --disable-static &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
