# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: sentry-sdk-2.35.0   (order.txt row 019, REQ-PROM)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/python-modules.html#sentry-sdk
# section: anchor #sentry-sdk

# --- [BUILD] ---
# Build the module:
pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir $PWD

# --- [INSTALL,ROOT] ---
# Now, as the root user:
pip3 install --no-index --find-links dist --no-user sentry-sdk
