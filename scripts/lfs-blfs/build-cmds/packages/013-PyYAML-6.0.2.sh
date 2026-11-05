# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: PyYAML-6.0.2   (order.txt row 013, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/python-modules.html#PyYAML
# section: anchor #PyYAML
# INLINE-TEST (test command given in a sentence on the page, not an active block): pytest

# --- [BUILD] ---
# Build PyYAML with the following command:
pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir $PWD

# --- [INSTALL,ROOT] ---
# Now, install the module as the root user:
pip3 install --no-index --find-links dist --no-user PyYAML
