# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: icu-77.1   (order.txt row 025, REC-INC)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/icu.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make check

# --- [TEST] ---
# A part of a test cannot be run on i686. Avoid executing it when building for that platform:
case $(uname -m) in
  i?86) sed -e "s/U_PLATFORM_IS_LINUX_BASED/__X86_64__ \&\& &/" \
            -i source/test/intltest/ustrtest.cpp ;;
esac

# --- [BUILD] ---
# Install ICU by running the following commands:
cd source                 &&
./configure --prefix=/usr &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
