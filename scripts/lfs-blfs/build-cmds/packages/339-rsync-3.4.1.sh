# rsync 3.4.1 build commands (added 2026-11-06 as order row 339; BLFS 12.4-systemd book page basicnet/rsync.html).
# source: https://www.samba.org/ftp/rsync/src/rsync-3.4.1.tar.gz
# verification: book MD5 04ce67866db04fd7a1cde0b78168406e (book-verified); sha256 2924bcb3a1ed8b551fc101f740b9f0fe0a202b115027647cf69850d65fd88c52 (computed 2026-11-06, not in book)
# book flags: --disable-xxhash (xxhash is not in /mnt/lfs) and --without-included-zlib (system zlib 1.3.1 in /mnt/lfs).
# popt: the book recommends popt-1.19, but no system libpopt is in /mnt/lfs; configure then uses rsync's bundled popt/ (automatic, no flag needed).
# zstd, lz4, openssl and libacl are present in /mnt/lfs and are auto-detected by configure.

# --- [BUILD] ---
./configure --prefix=/usr    \
            --disable-xxhash \
            --without-included-zlib &&
make

# --- [INSTALL,ROOT] ---
make install

# --- [CONFIG] ---
# smoke test: rsync binary runs and reports its version
rsync --version
