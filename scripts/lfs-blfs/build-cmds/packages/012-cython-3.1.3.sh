# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: cython-3.1.3   (order.txt row 012, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/python-modules.html#cython
# section: anchor #cython

# --- [BUILD] ---
# Build the module:
pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir $PWD

# --- [INSTALL,ROOT] ---
# Now, as the root user:
pip3 install --no-index --find-links dist --no-user Cython
