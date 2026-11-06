# popt 1.19 build commands (added 2026-11-06 as order row 341; BLFS 12.4-systemd book page general/popt.html).
# source: https://ftp.osuosl.org/pub/rpm/popt/releases/popt-1.x/popt-1.19.tar.gz
# verification: book MD5 eaa2135fddb6eb03f2c87ee1823e5a78 (book-verified, matches the downloaded file 2026-11-06); sha256 c25a4838fc8e4c1c8aacb8bd620edb3084a3d63bf8987fdad3ca2758c63240f9 (computed, not in book).
# Needed by efibootmgr (row 343). Doxygen API documentation is not built (the book's optional step).
# Note: after this row, rsync (row 339) would find a system libpopt on a rebuild; the 339 build is already done and is not changed.

# --- [BUILD] ---
./configure --prefix=/usr --disable-static &&
make

# --- [INSTALL,ROOT] ---
make install

# --- [CONFIG] ---
# smoke test: pkg-config reports the installed popt version
pkg-config --modversion popt | grep -qx '1.19'
