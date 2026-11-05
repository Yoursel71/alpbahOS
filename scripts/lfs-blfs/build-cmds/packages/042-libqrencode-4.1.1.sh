# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libqrencode-4.1.1   (order.txt row 042, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/libqrencode.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make check

# --- [BUILD] ---
# Install libqrencode by running the following commands:
sh autogen.sh             &&
./configure --prefix=/usr &&
make

# --- [BUILD] ---
# If you have installed Doxygen-1.14.0, you can build the documentation by issuing:
doxygen

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install

# --- [INSTALL,ROOT,OPTIONAL] ---
# If you have built the optional documentation, install it as the root user:
install -vdm 755 /usr/share/doc/libqrencode-4.1.1 &&
mv html/*        /usr/share/doc/libqrencode-4.1.1
