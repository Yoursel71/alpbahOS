# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libvorbis-1.3.7   (order.txt row 034, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/multimedia/libvorbis.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make -j1 check

# --- [BUILD] ---
# Install libvorbis by running the following commands:
./configure --prefix=/usr --disable-static &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install &&
install -v -m644 doc/Vorbis* /usr/share/doc/libvorbis-1.3.7
