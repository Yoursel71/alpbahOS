# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libXrender-0.9.12   (order.txt row 092, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/x7lib.html
# SHARED-SECTION: this page section is shared by 32 order rows (xtrans-1.6.0, libX11-1.8.12, libXext-1.3.6, libFS-1.0.10, libICE-1.1.2, libSM-1.2.6, libXScrnSaver-1.2.4, libXt-1.3.1, libXmu-1.2.1, libXpm-3.5.17, libXaw-1.0.16, libXfixes-6.0.1, libXcomposite-0.4.6, libXrender-0.9.12, libXcursor-1.2.3, libXdamage-1.1.6, libfontenc-1.1.8, libXfont2-2.0.7, libXft-2.3.9, libXi-1.8.2, libXinerama-1.1.5, libXrandr-1.5.4, libXres-1.2.2, libXtst-1.2.5, libXv-1.0.13, libXvMC-1.0.14, libXxf86dga-1.1.6, libXxf86vm-1.1.6, libpciaccess-0.18.1, libxkbfile-1.1.3, libxshmfence-1.3.3, libXpresent-1.0.1); same blocks in each file.
# INLINE-TEST (test command given in a sentence on the page, not an active block): make check
# INLINE-TEST (test command given in a sentence on the page, not an active block): make check ...

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

# --- [TEST,OPTIONAL] ---
# Some libraries come with a test suite. If you wish to execute them, either comment out the rm
# -rf ... below, so that, after all libraries are installed, you can come back to the
# corresponding directory and run make check, or do individual builds, running the tests for each
# of those distributed with working test suites. Alternatively, you can uncomment the line #make
# check ..., and at the end, check the test results with:
grep -A9 summary *make_check.log

# --- [BUILD] ---
# First, start a subshell that will exit on error:
bash -e

# --- [BUILD,INSTALL] ---
# Install all of the packages by running the following commands:
for package in $(grep -v '^#' ../lib-7.md5 | awk '{print $2}')
do
  packagedir=${package%.tar.?z*}
  echo "Building $packagedir"

  tar -xf $package
  pushd $packagedir
  docdir="--docdir=$XORG_PREFIX/share/doc/$packagedir"
  
  case $packagedir in
    libXfont2-[0-9]* )
      ./configure $XORG_CONFIG $docdir --disable-devel-docs
    ;;

    libXt-[0-9]* )
      ./configure $XORG_CONFIG $docdir \
                  --with-appdefaultdir=/etc/X11/app-defaults
    ;;

    libXpm-[0-9]* )
      ./configure $XORG_CONFIG $docdir --disable-open-zfile
    ;;
  
    libpciaccess* )
      mkdir build
      cd    build
        meson setup --prefix=$XORG_PREFIX --buildtype=release ..
        ninja
        #ninja test
        as_root ninja install
      popd     # $packagedir
      continue # for loop
    ;;

    * )
      ./configure $XORG_CONFIG $docdir
    ;;
  esac

  make
  #make check 2>&1 | tee ../$packagedir-make_check.log
  as_root make install
  popd
  rm -rf $packagedir
  as_root /sbin/ldconfig
done

# --- [BUILD] ---
# Finally, exit the shell that was started earlier:
exit

# --- [CONFIG,ROOT,OPTIONAL] ---
# If you've chosen to install Xorg into /usr, then no further configuration is necessary and you
# can skip the rest of this section. If you've opted for an alternate prefix, you should create
# two symlinks to satisfy the expected environment of several packages. Execute the following
# commands as the root user:
ln -sv $XORG_PREFIX/lib/X11 /usr/lib/X11 &&
ln -sv $XORG_PREFIX/include/X11 /usr/include/X11
