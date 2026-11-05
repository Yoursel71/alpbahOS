# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: pango-1.56.4   (order.txt row 188, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/pango.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): ninja test

# --- [BUILD,INSTALL] ---
# Install Pango by running the following commands:
mkdir build &&
cd    build &&

meson setup --prefix=/usr            \
            --buildtype=release      \
            --wrap-mode=nofallback   \
            -D introspection=enabled \
            ..                       &&
ninja

# --- [BUILD] ---
# If you have Gi-DocGen-2025.4 installed and wish to build the API documentation for this package,
# issue:
sed "/docs_dir =/s@\$@ / 'pango-1.56.4'@" -i ../docs/meson.build &&
meson configure -D documentation=true                            &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install
