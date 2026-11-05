# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: freetype-2.13.3:pass1   (order.txt row 048, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/freetype2.html
# SHARED-SECTION: this page section is shared by 2 order rows (freetype-2.13.3:pass1, freetype-2.13.3:pass2); same blocks in each file.

# --- [BUILD,OPTIONAL] ---
# If you downloaded the additional documentation, unpack it into the source tree using the
# following command:
tar -xf ../freetype-doc-2.13.3.tar.xz --strip-components=2 -C docs

# --- [BUILD] ---
# Install FreeType2 by running the following commands:
sed -ri "s:.*(AUX_MODULES.*valid):\1:" modules.cfg &&

sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" \
    -i include/freetype/config/ftoption.h  &&

./configure --prefix=/usr --enable-freetype-config --disable-static &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install

# --- [INSTALL,ROOT,OPTIONAL] ---
# If you downloaded the optional documentation, install it as the root user:
cp -v -R docs -T /usr/share/doc/freetype-2.13.3 &&
rm -v /usr/share/doc/freetype-2.13.3/freetype-config.1
