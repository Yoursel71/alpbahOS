# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: psutil-7.0.0   (order.txt row 015, REQ-PROM)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/python-modules.html#psutil
# section: anchor #psutil
# INLINE-TEST (test command given in a sentence on the page, not an active block): make test

# --- [BUILD] ---
# Build the module:
pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir $PWD

# --- [INSTALL,ROOT] ---
# Now, as the root user:
pip3 install --no-index --find-links dist --no-user psutil
