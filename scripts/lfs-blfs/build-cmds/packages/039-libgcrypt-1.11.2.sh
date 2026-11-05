# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libgcrypt-1.11.2   (order.txt row 039, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/libgcrypt.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make check

# --- [BUILD] ---
# Install libgcrypt by running the following commands:
./configure --prefix=/usr &&
make                      &&

make -C doc html                                                       &&
makeinfo --html --no-split -o doc/gcrypt_nochunks.html doc/gcrypt.texi &&
makeinfo --plaintext       -o doc/gcrypt.txt           doc/gcrypt.texi

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install &&
install -v -dm755   /usr/share/doc/libgcrypt-1.11.2 &&
install -v -m644    README doc/{README.apichanges,fips*,libgcrypt*} \
                    /usr/share/doc/libgcrypt-1.11.2 &&

install -v -dm755   /usr/share/doc/libgcrypt-1.11.2/html &&
install -v -m644 doc/gcrypt.html/* \
                    /usr/share/doc/libgcrypt-1.11.2/html &&
install -v -m644 doc/gcrypt_nochunks.html \
                    /usr/share/doc/libgcrypt-1.11.2      &&
install -v -m644 doc/gcrypt.{txt,texi} \
                    /usr/share/doc/libgcrypt-1.11.2
