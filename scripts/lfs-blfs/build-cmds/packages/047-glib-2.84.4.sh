# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: glib-2.84.4   (order.txt row 047, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/glib2.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): ninja -C gi-build test
# INLINE-TEST (test command given in a sentence on the page, not an active block): LC_ALL=C ninja test

# --- [BUILD,OPTIONAL] ---
# For instance export GLIB_LOG_LEVEL=4 will skip output of Warning and Notice messages (and
# Info/Debug messages if they are turned on). If GLIB_LOG_LEVEL is not defined, normal message
# output will not be affected.
patch -Np1 -i ../glib-skip_warnings-1.patch

# --- [INSTALL,ROOT,BOX] ---
# If a previous version of glib is installed, move the headers out of the way so that later
# packages do not encounter conflicts:
# SKIPPED-BOX: if [ -e /usr/include/glib-2.0 ]; then
# SKIPPED-BOX:     rm -rf /usr/include/glib-2.0.old &&
# SKIPPED-BOX:     mv -vf /usr/include/glib-2.0{,.old}
# SKIPPED-BOX: fi

# --- [BUILD,INSTALL] ---
# Install GLib by running the following commands:
mkdir build &&
cd    build &&

meson setup ..                  \
      --prefix=/usr             \
      --buildtype=release       \
      -D introspection=disabled \
      -D glib_debug=disabled    \
      -D man-pages=enabled      \
      -D sysprof=disabled       &&
ninja

# --- [INSTALL,ROOT] ---
# As the root user, install this package for the first time to allow building GObject
# Introspection:
ninja install

# --- [BUILD] ---
# Build GObject Introspection:
tar xf ../../gobject-introspection-1.84.0.tar.xz &&

meson setup gobject-introspection-1.84.0 gi-build \
            --prefix=/usr --buildtype=release     &&
ninja -C gi-build

# --- [INSTALL,ROOT] ---
# As the root user, install GObject Introspection for generating the introspection data of GLib
# libraries (required by various packages using Glib, especially some GNOME packages):
ninja -C gi-build install

# --- [BUILD] ---
# Now generate the introspection data:
meson configure -D introspection=enabled &&
ninja

# --- [BUILD] ---
# If you have Gi-DocGen-2025.4 installed and wish to build the API documentation for this package,
# issue:
sed "/docs_dir =/s|$| / 'glib-' + meson.project_version()|" \
    -i ../docs/reference/meson.build                        &&
meson configure -D documentation=true                       &&
ninja

# --- [INSTALL,ROOT,OPTIONAL] ---
# As the root user, install this package again for the introspection data (and optionally, the
# documentation):
ninja install
