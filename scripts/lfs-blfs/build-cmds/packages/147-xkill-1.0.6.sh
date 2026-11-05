# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: xkill-1.0.6   (order.txt row 147, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/x7app.html
# SHARED-SECTION: this page section is shared by 33 order rows (iceauth-1.0.10, mkfontscale-1.2.3, sessreg-1.1.4, setxkbmap-1.3.4, smproxy-1.0.8, xauth-1.1.4, xcmsdb-1.0.7, xcursorgen-1.0.9, xdpyinfo-1.4.0, xdriinfo-1.0.8, xev-1.2.6, xgamma-1.0.8, xhost-1.0.10, xinput-1.6.4, xkbcomp-1.4.7, xkbevd-1.1.6, xkbutils-1.0.6, xkill-1.0.6, xlsatoms-1.1.4, xlsclients-1.1.5, xmessage-1.0.7, xmodmap-1.0.11, xpr-1.2.0, xprop-1.2.8, xrandr-1.5.3, xrdb-1.2.2, xrefresh-1.1.0, xset-1.2.5, xsetroot-1.1.3, xvinfo-1.1.5, xwd-1.0.9, xwininfo-1.1.6, xwud-1.0.7); same blocks in each file.

# --- [BUILD,BOX] ---
# One way to handle this situation is to create a short bash function that automatically selects
# the appropriate method. Once the command is set in the environment, it does not need to be set
# again.
# SKIPPED-BOX: as_root()
# SKIPPED-BOX: {
# SKIPPED-BOX:   if   [ $EUID = 0 ];        then $*
# SKIPPED-BOX:   elif [ -x /usr/bin/sudo ]; then sudo $*
# SKIPPED-BOX:   else                            su -c \\"$*\\"
# SKIPPED-BOX:   fi
# SKIPPED-BOX: }
# SKIPPED-BOX:
# SKIPPED-BOX: export -f as_root

# --- [BUILD] ---
# First, start a subshell that will exit on error:
bash -e

# --- [BUILD,INSTALL] ---
# Install all of the packages by running the following commands:
for package in $(grep -v '^#' ../app-7.md5 | awk '{print $2}')
do
  packagedir=${package%.tar.?z*}
  tar -xf $package
  pushd $packagedir
     ./configure $XORG_CONFIG
     make
     as_root make install
  popd
  rm -rf $packagedir
done

# --- [BUILD] ---
# Finally, exit the shell that was started earlier:
exit

# --- [BUILD,OPTIONAL] ---
# Unless you installed the optional dependencies, remove an undocumented script which is reported
# to be broken (xkeystone provided by the xrandr package).
as_root rm -f $XORG_PREFIX/bin/xkeystone
