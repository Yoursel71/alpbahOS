# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: gtk3-3.24.50   (order.txt row 190, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/gtk3.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): dbus-run-session ninja test

# --- [BUILD,INSTALL] ---
# Install GTK3 by running the following commands:
mkdir build &&
cd    build &&

meson setup ..            \
      --prefix=/usr       \
      --buildtype=release \
      -D man=true         \
      -D broadway_backend=true &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install

# --- [INSTALL,ROOT,BOX] ---
# If you installed the package on to your system using a “DESTDIR” method, an important file was
# not installed and must be copied and/or generated. Generate it using the following command as
# the root user:
# SKIPPED-BOX: gtk-query-immodules-3.0 --update-cache

# --- [INSTALL,ROOT,BOX] ---
# If you installed the package to your system using a “DESTDIR” method,
# /usr/share/glib-2.0/schemas/gschemas.compiled was not updated/created. Create (or update) the
# file using the following command as the root user:
# SKIPPED-BOX: glib-compile-schemas /usr/share/glib-2.0/schemas

# --- [CONFIG,ROOT] ---
# GTK3 themes change the way a GTK3 application looks. An icon theme can be used to change the
# icons that appear on the application's toolbar. If you have installed a GTK3 theme (e.g. the
# Adwaita theme built in GTK3), an icon theme (such as oxygen-icons-6.0.0) and/or a font (Dejavu
# fonts), you can set your preferences in ~/.config/gtk-3.0/settings.ini, or the default system
# wide configuration file (as the root user), in /etc/gtk-3.0/settings.ini. For the local user an
# example is:
mkdir -vp ~/.config/gtk-3.0
cat > ~/.config/gtk-3.0/settings.ini << "EOF"
[Settings]
gtk-theme-name = Adwaita
gtk-icon-theme-name = oxygen
gtk-font-name = DejaVu Sans 12
gtk-cursor-theme-size = 18
gtk-toolbar-style = GTK_TOOLBAR_BOTH_HORIZ
gtk-xft-antialias = 1
gtk-xft-hinting = 1
gtk-xft-hintstyle = hintslight
gtk-xft-rgba = rgb
gtk-cursor-theme-name = Adwaita
EOF

# --- [CONFIG] ---
# As part of GTK-3.0's redesign, the scroll bar buttons are no longer visible on the scrollbar in
# many applications. If this functionality is desired, modify the gtk.css file and restore them
# using the following command:
cat > ~/.config/gtk-3.0/gtk.css << "EOF"
*  {
   -GtkScrollbar-has-backward-stepper: 1;
   -GtkScrollbar-has-forward-stepper: 1;
}
EOF
