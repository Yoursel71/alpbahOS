# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: gsettings-desktop-schemas-48.0   (order.txt row 185, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/gnome/gsettings-desktop-schemas.html

# --- [BUILD,INSTALL] ---
# Install GSettings Desktop Schemas by running the following commands:
sed -i -r 's:"(/system):"/org/gnome\1:g' schemas/*.in &&

mkdir build &&
cd    build &&

meson setup --prefix=/usr --buildtype=release .. &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install

# --- [INSTALL,ROOT,BOX] ---
# If you installed the package to your system using a “DESTDIR” method,
# /usr/share/glib-2.0/schemas/gschemas.compiled was not updated/created. Create (or update) the
# file using the following command as the root user:
# SKIPPED-BOX: glib-compile-schemas /usr/share/glib-2.0/schemas
