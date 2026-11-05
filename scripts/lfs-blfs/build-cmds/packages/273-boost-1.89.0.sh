# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: boost-1.89.0   (order.txt row 273, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/boost.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): pushd tools/build/test; python3 test_all.py; popd

# --- [BUILD] ---
# First, fix a build issue which occurs in the stacktrace library. This issue is specific to i686
# systems.
case $(uname -m) in
   i?86)
      sed -e "s/defined(__MINGW32__)/& || defined(__i386__)/" \
          -i ./libs/stacktrace/src/exception_headers.h ;;
esac

# --- [BUILD] ---
# This package can be built with several jobs running in parallel. In the instructions below, all
# available logical cores are used. Replace $(nproc) with the number of logical cores you want to
# use if you don't want to use all. Install Boost by running the following commands:
./bootstrap.sh --prefix=/usr --with-python=python3 &&
./b2 stage -j$(nproc) threading=multi link=shared

# --- [BUILD,INSTALL,ROOT,BOX] ---
# Boost installs many versioned directories in /usr/lib/cmake. If a new version of Boost is
# installed over a previous version, the older cmake directories need to be explicitly removed. To
# do this, run as the root user:
# SKIPPED-BOX: rm -rf /usr/lib/cmake/[Bb]oost*

# --- [BUILD,INSTALL,ROOT] ---
# Now, as the root user:
./b2 install threading=multi link=shared
