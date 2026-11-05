# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: krunner-6.17.0   (order.txt row 258, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/kde/frameworks6.html
# SHARED-SECTION: this page section is shared by 70 order rows (attica-6.17.0, kapidox-6.17.0, karchive-6.17.0, kcodecs-6.17.0, kconfig-6.17.0, kcoreaddons-6.17.0, kdbusaddons-6.17.0, kdnssd-6.17.0, kguiaddons-6.17.0, ki18n-6.17.0, kidletime-6.17.0, kimageformats-6.17.0, kitemmodels-6.17.0, kitemviews-6.17.0, kplotting-6.17.0, kwidgetsaddons-6.17.0, kwindowsystem-6.17.0, networkmanager-qt-6.17.0, solid-6.17.0, sonnet-6.17.0, threadweaver-6.17.0, kauth-6.17.0, kcompletion-6.17.0, kcrash-6.17.0, kdoctools-6.17.0, kpty-6.17.0, kunitconversion-6.17.0, kcolorscheme-6.17.0, kconfigwidgets-6.17.0, kservice-6.17.0, kglobalaccel-6.17.0, kpackage-6.17.0, kdesu-6.17.0, kiconthemes-6.17.0, knotifications-6.17.0, kjobwidgets-6.17.0, ktextwidgets-6.17.0, kxmlgui-6.17.0, kbookmarks-6.17.0, kwallet-6.17.0, kded-6.17.0, kio-6.17.0, kdeclarative-6.17.0, kcmutils-6.17.0, kirigami-6.17.0, syndication-6.17.0, knewstuff-6.17.0, frameworkintegration-6.17.0, kparts-6.17.0, syntax-highlighting-6.17.0, ktexteditor-6.17.0, modemmanager-qt-6.17.0, kcontacts-6.17.0, kpeople-6.17.0, bluez-qt-6.17.0, kfilemetadata-6.17.0, baloo-6.17.0, krunner-6.17.0, prison-6.17.0, qqc2-desktop-style-6.17.0, kholidays-6.17.0, purpose-6.17.0, kcalendarcore-6.17.0, kquickcharts-6.17.0, knotifyconfig-6.17.0, kdav-6.17.0, kstatusnotifieritem-6.17.0, ksvg-6.17.0, ktexttemplate-6.17.0, kuserfeedback-6.17.0); same blocks in each file.

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

# --- [INSTALL,ROOT,BOX] ---
# If installing in /opt and there is an existing /opt/kf6 either as a regular directory or a
# symbolic link, it should be reinitialized (as root):
# SKIPPED-BOX: mv -v /opt/kf6 /opt/kf6.old                         &&
# SKIPPED-BOX: install -v -dm755           $KF6_PREFIX/{etc,share} &&
# SKIPPED-BOX: ln -sfv /etc/dbus-1         $KF6_PREFIX/etc         &&
# SKIPPED-BOX: ln -sfv /usr/share/dbus-1   $KF6_PREFIX/share       &&
# SKIPPED-BOX: ln -sfv /usr/share/polkit-1 $KF6_PREFIX/share       &&
# SKIPPED-BOX: install -v -dm755           $KF6_PREFIX/lib         &&
# SKIPPED-BOX: ln -sfv /usr/lib/systemd    $KF6_PREFIX/lib

# --- [BUILD] ---
# First, start a subshell that will exit on error:
bash -e

# --- [BUILD,INSTALL] ---
# Install all of the packages by running the following commands:
while read -r line; do

    # Get the file name, ignoring comments and blank lines
    if $(echo $line | grep -E -q '^ *$|^#' ); then continue; fi
    file=$(echo $line | cut -d" " -f2)

    pkg=$(echo $file|sed 's|^.*/||')          # Remove directory
    packagedir=$(echo $pkg|sed 's|\.tar.*||') # Package directory

    name=$(echo $pkg|sed 's|-6.*$||') # Isolate package name

    tar -xf $file
    pushd $packagedir

      # kapidox is a python module
      case $name in
        kapidox)
          pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir $PWD
          as_root pip3 install --no-index --find-links dist --no-user kapidox
          popd
          rm -rf $packagedir
          continue
          ;;
      esac

      mkdir build
      cd    build

      cmake -D CMAKE_INSTALL_PREFIX=$KF6_PREFIX \
            -D CMAKE_INSTALL_LIBEXECDIR=libexec \
            -D CMAKE_PREFIX_PATH=$QT6DIR        \
            -D CMAKE_SKIP_INSTALL_RPATH=ON      \
            -D CMAKE_BUILD_TYPE=Release         \
            -D BUILD_TESTING=OFF                \
            -D BUILD_PYTHON_BINDINGS=OFF        \
            -W no-dev ..
      make
      as_root make install
    popd

  as_root rm -rf $packagedir
  as_root /sbin/ldconfig

done < frameworks-6.17.0.md5

exit

# --- [INSTALL,ROOT] ---
# Sometimes the installation paths are hardcoded into installed files. If the installed directory
# is not /usr, rename the directory and create a symlink:
mv -v /opt/kf6 /opt/kf6-6.17.0
ln -sfvn kf6-6.17.0 /opt/kf6
