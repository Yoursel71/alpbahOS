# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: font-bh-type1-1.0.4   (order.txt row 169, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/x7font.html
# SHARED-SECTION: this page section is shared by 9 order rows (font-util-1.4.1, encodings-1.1.0, font-alias-1.0.5, font-adobe-utopia-type1-1.0.5, font-bh-ttf-1.0.4, font-bh-type1-1.0.4, font-ibm-type1-1.0.4, font-misc-ethiopic-1.0.5, font-xfree86-type1-1.0.5); same blocks in each file.

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
for package in $(grep -v '^#' ../font-7.md5 | awk '{print $2}')
do
  packagedir=${package%.tar.?z*}
  tar -xf $package
  pushd $packagedir
    ./configure $XORG_CONFIG
    make
    as_root make install
  popd
  as_root rm -rf $packagedir
done

# --- [BUILD] ---
# Finally, exit the shell that was started earlier:
exit

# --- [INSTALL,ROOT] ---
# When all of the fonts have been installed, the system must be configured so that Fontconfig can
# find the TrueType fonts. Since the fonts are outside of the default search path of several
# packages if XORG_PREFIX is not /usr, make symlinks to the Xorg TrueType font directories in
# /usr/share/fonts by running the following commands as the root user:
install -v -d -m755 /usr/share/fonts                               &&
ln -svfn $XORG_PREFIX/share/fonts/X11/OTF /usr/share/fonts/X11-OTF &&
ln -svfn $XORG_PREFIX/share/fonts/X11/TTF /usr/share/fonts/X11-TTF
