# squashfs-tools 4.7.5 build commands (added 2026-11-06 as order row 340; NOT in the BLFS 12.4-systemd book; upstream release https://github.com/plougher/squashfs-tools/releases/tag/4.7.5).
# source: https://github.com/plougher/squashfs-tools/releases/download/4.7.5/squashfs-tools-4.7.5.tar.gz
# verification: upstream publishes no signature for this release. sha256 547b7b7f4d2e44bf91b6fc554664850c69563701deab9fd9cd7e21f694c88ea6 matches the GitHub API asset digest (checked 2026-11-06). Trust-on-first-use (TOFU); md5 183807a29b969d8e3a1cd27f09fe8179 recorded for the fetch helper.
# Makefile lives in squashfs-tools/ inside the tarball (the generator already cds into the top-level directory).
# Features: GZIP (zlib), XZ (liblzma), ZSTD and LZ4 are enabled because their libraries and headers are in /mnt/lfs.
# LZO_SUPPORT=0 is required: the Makefile default is 1 and liblzo2 is not in /mnt/lfs.
# USE_PREBUILT_MANPAGES=y: the prebuilt manpages are used; help2man is not in the chroot.
# Installed to /usr/bin (mksquashfs, unsquashfs, sqfscat, sqfstar); manpages to /usr/share/man/man1.

# --- [BUILD] ---
cd squashfs-tools &&
make XZ_SUPPORT=1 ZSTD_SUPPORT=1 LZ4_SUPPORT=1 GZIP_SUPPORT=1 \
     LZO_SUPPORT=0 LZMA_XZ_SUPPORT=0 XATTR_SUPPORT=1 \
     USE_PREBUILT_MANPAGES=y

# --- [INSTALL,ROOT] ---
# The feature overrides must be repeated here: 'make install' depends on mksquashfs/unsquashfs and
# would otherwise rebuild lzo_wrapper.o with the Makefile default LZO_SUPPORT=1 (failed on 2026-11-06).
# Makefile lines 36-118 are plain '=' assignments, so only command-line overrides win (environment is not enough).
make install INSTALL_PREFIX=/usr INSTALL_MANPAGES_DIR=/usr/share/man/man1 \
     XZ_SUPPORT=1 ZSTD_SUPPORT=1 LZ4_SUPPORT=1 GZIP_SUPPORT=1 \
     LZO_SUPPORT=0 LZMA_XZ_SUPPORT=0 XATTR_SUPPORT=1 \
     USE_PREBUILT_MANPAGES=y

# --- [CONFIG] ---
# smoke test: check the version text, not the exit status.
# Upstream 4.7.5 'unsquashfs -version' exits with status 1 even on success (verified in the chroot,
# 2026-11-06), so the exit code is captured with '|| true' and the printed text is matched instead.
out=$(mksquashfs -version 2>&1 || true); printf '%s\n' "$out" | grep -q 'mksquashfs version 4.7.5'
out=$(unsquashfs -version 2>&1 || true); printf '%s\n' "$out" | grep -q 'unsquashfs version 4.7.5'
