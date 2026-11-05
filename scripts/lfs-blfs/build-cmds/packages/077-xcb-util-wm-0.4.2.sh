# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: xcb-util-wm-0.4.2   (order.txt row 077, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/xcb-utilities.html
# SHARED-SECTION: this page section is shared by 5 order rows (xcb-util-image-0.4.1, xcb-util-keysyms-0.4.1, xcb-util-renderutil-0.3.10, xcb-util-wm-0.4.2, xcb-util-cursor-0.1.5); same blocks in each file.

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
for package in $(grep -v '^#' ../xcb-utils.md5 | awk '{print $2}')
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
