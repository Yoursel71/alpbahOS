# dosfstools 4.2 build commands (added 2026-11-06 as order row 344; BLFS 12.4-systemd book page postlfs/dosfstools.html).
# source: https://github.com/dosfstools/dosfstools/releases/download/v4.2/dosfstools-4.2.tar.gz
# verification: book MD5 49c8e457327dc61efab5b115a27b087a (book-verified, matches the downloaded file 2026-11-06); sha256 64926eebf90092dca21b14259a5301b7b98e7b1943e8a201c7d726084809b527 (computed, not in book).
# Book flags: --enable-compat-symlinks creates mkfs.vfat, mkfs.msdos, fsck.vfat, fsck.msdos, mkdosfs, dosfsck and dosfslabel. Calamares needs mkfs.vfat for the EFI System Partition.
# Installed: fatlabel, fsck.fat, mkfs.fat (and the symlinks above) under /usr/sbin.
# The book test target (make check) is not run.

# --- [BUILD] ---
./configure --prefix=/usr            \
            --enable-compat-symlinks \
            --mandir=/usr/share/man  \
            --docdir=/usr/share/doc/dosfstools-4.2 &&
make

# --- [INSTALL,ROOT] ---
make install

# --- [CONFIG] ---
# smoke test: mkfs.vfat --help prints the program banner "mkfs.fat 4.2" (dosfstools 4.2 has no --version; help exits 0)
out=$(mkfs.vfat --help 2>&1 || true); printf '%s\n' "$out" | grep -q 'mkfs.fat 4.2'
