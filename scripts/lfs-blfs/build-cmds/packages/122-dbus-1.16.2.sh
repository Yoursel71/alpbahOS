# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: dbus-1.16.2   (order.txt row 122, LFS-REBUILD)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/dbus.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): ninja test

# --- [BUILD,INSTALL] ---
# Install D-Bus by running the following commands (you may wish to review the meson_options.txt
# file first and add any additional desired options to the meson setup line below):
mkdir build &&
cd    build &&

meson setup --prefix=/usr          \
            --buildtype=release    \
            --wrap-mode=nofallback \
            .. &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install

# --- [INSTALL,ROOT] ---
# If you are using a DESTDIR install, dbus-daemon-launch-helper needs to be fixed afterwards.
# Issue, as root user:
chown -v root:messagebus /usr/libexec/dbus-daemon-launch-helper &&
chmod -v      4750       /usr/libexec/dbus-daemon-launch-helper

# --- [INSTALL,ROOT,OPTIONAL] ---
# Finally, still as the root user, rename the documentation directory (it only exists if the
# optional dependencies are satisfied for at least one documentation format) to make it versioned:
if [ -e /usr/share/doc/dbus ]; then
  rm -rf /usr/share/doc/dbus-1.16.2    &&
  mv -v  /usr/share/doc/dbus{,-1.16.2}
fi

# --- [BUILD,TEST,OPTIONAL] ---
# If you want to run the unit regression tests, meson requires additional parameters which expose
# additional functionality in the binaries that are not intended to be used in a production build
# of D-Bus. If you would like to run the tests, issue the following commands (for the tests, you
# don't need to build the docs):
meson configure -D asserts=true -D intrusive_tests=true &&
ninja test

# --- [CONFIG,ROOT] ---
# If any packages install a D-Bus .service file outside of the standard /usr/share/dbus-1/services
# directory, that directory should be added to the local session configuration. For instance,
# /usr/local/share/dbus-1/services can be added by performing the following commands as the root
# user:
cat > /etc/dbus-1/session-local.conf << "EOF"
<!DOCTYPE busconfig PUBLIC
 "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>

  <!-- Search for .service files in /usr/local -->
  <servicedir>/usr/local/share/dbus-1/services</servicedir>

</busconfig>
EOF

# --- [CONFIG] ---
# The examples shown previously use dbus-launch to specify a program to be run. This has the
# benefit (when also using the --exit-with-x11 parameter) of stopping the session daemon when the
# specified program is stopped. You can also start the session daemon in your system or personal
# startup scripts by adding the following lines:
# Start the D-Bus session daemon
eval `dbus-launch`
export DBUS_SESSION_BUS_ADDRESS

# --- [CONFIG] ---
# This method will not stop the session daemon when you exit your shell, therefore you should add
# the following line to your ~/.bash_logout file:
# Kill the D-Bus session daemon
kill $DBUS_SESSION_BUS_PID
