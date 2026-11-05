# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libpng-1.6.50   (order.txt row 023, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/libpng.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make check

# --- [BUILD,OPTIONAL] ---
# If you want to patch libpng to support apng files, apply it here:
gzip -cd ../libpng-1.6.47-apng.patch.gz | patch -p1

# --- [BUILD] ---
# Install libpng by running the following commands:
./configure --prefix=/usr --disable-static &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install &&
mkdir -v /usr/share/doc/libpng-1.6.50 &&
cp -v README libpng-manual.txt /usr/share/doc/libpng-1.6.50
