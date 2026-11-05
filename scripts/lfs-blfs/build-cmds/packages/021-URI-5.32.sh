# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: URI-5.32   (order.txt row 021, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/perl-modules.html#perl-uri
# section: anchor #perl-uri

# --- [BUILD,TEST] ---
# This module uses the standard build and installation instructions:
perl Makefile.PL &&
make             &&
make test

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
