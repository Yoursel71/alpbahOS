# efivar 39 build commands (added 2026-11-06 as order row 342; BLFS 12.4-systemd book page postlfs/efivar.html).
# source: https://github.com/rhboot/efivar/archive/39/efivar-39.tar.gz
# verification: book MD5 a8fc3e79336cd6e738ab44f9bc96a5aa (book-verified, matches the downloaded file 2026-11-06); sha256 c9edd15f2eeeea63232f3e669a48e992c7be9aff57ee22672ac31f5eca1609a6 (computed, not in book).
# Book flags: ENABLE_DOCS=0 (no mandoc dependency; the man pages are copied by hand from docs/, as the book says) and LIBDIR=/usr/lib (LFS does not use /usr/lib64).
# Build note: the efivar-39 source does not compile on a glibc 2.43 host (discarded-qualifiers error in guid.c). The chroot glibc is 2.42 and its stdlib.h has no type-generic bsearch, so this row is expected to build there; the chroot build is the real test.
# Installed: efisecdb, efivar, libefivar, libefiboot, libefisec and the efivar headers.

# --- [BUILD] ---
make ENABLE_DOCS=0

# --- [INSTALL,ROOT] ---
make install ENABLE_DOCS=0 LIBDIR=/usr/lib &&
install -vm644 docs/efivar.1 /usr/share/man/man1 &&
install -vm644 docs/*.3      /usr/share/man/man3

# --- [CONFIG] ---
# smoke test: pkg-config reports the installed efivar version
pkg-config --modversion efivar | grep -qx '39'
