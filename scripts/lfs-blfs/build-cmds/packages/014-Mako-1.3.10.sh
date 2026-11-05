# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: Mako-1.3.10   (order.txt row 014, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/python-modules.html#Mako
# section: anchor #Mako
# INLINE-TEST (test command given in a sentence on the page, not an active block): pytest

# --- [BUILD] ---
# Build the module:
pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir $PWD

# --- [INSTALL,ROOT] ---
# Install the module as the root user:
pip3 install --no-index --find-links dist --no-user Mako
