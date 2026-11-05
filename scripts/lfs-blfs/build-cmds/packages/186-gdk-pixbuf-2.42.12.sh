# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: gdk-pixbuf-2.42.12   (order.txt row 186, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/gdk-pixbuf.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): ninja test

# --- [BUILD,INSTALL] ---
# Install Gdk Pixbuf by running the following commands:
mkdir build &&
cd    build &&

meson setup ..            \
      --prefix=/usr       \
      --buildtype=release \
      -D others=enabled   \
      --wrap-mode=nofallback &&
ninja

# --- [BUILD] ---
# If you have Gi-DocGen-2025.4 installed and wish to build the API documentation for this package,
# issue:
sed "/docs_dir =/s@\$@ / 'gdk-pixbuf-2.42.12'@" -i ../docs/meson.build &&
meson configure -D gtk_doc=true                                        &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install

# --- [INSTALL,ROOT,BOX] ---
# If you installed the package on to your system using a “DESTDIR” method, an important file was
# not installed and should be copied and/or generated. Generate it using the following command as
# the root user:
# SKIPPED-BOX: gdk-pixbuf-query-loaders --update-cache
