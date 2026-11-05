# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: sqlite-3.50.4   (order.txt row 031, REC-INC)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/server/sqlite.html

# --- [BUILD,OPTIONAL] ---
# If you downloaded the optional documentation, issue the following command to install the
# documentation into the source tree:
unzip -q ../sqlite-doc-3500400.zip

# --- [BUILD] ---
# Install SQLite by running the following commands:
./configure --prefix=/usr     \
            --disable-static  \
            --enable-fts{4,5} \
            CPPFLAGS="-D SQLITE_ENABLE_COLUMN_METADATA=1 \
                      -D SQLITE_ENABLE_UNLOCK_NOTIFY=1   \
                      -D SQLITE_ENABLE_DBSTAT_VTAB=1     \
                      -D SQLITE_SECURE_DELETE=1"         &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install

# --- [INSTALL,ROOT,OPTIONAL] ---
# If you downloaded the optional documentation, issue the following commands as the root user to
# install it:
install -v -m755 -d /usr/share/doc/sqlite-3.50.4 &&
cp -v -R sqlite-doc-3500400/* /usr/share/doc/sqlite-3.50.4
