# LFS/BLFS build scripts (2026-11-05)

This folder is the **source text** of the BLFS 12.4 / KDE Plasma 6.4.4 build setup in the local work area `~/alpbahOS/scratch-lfs-bench`. Build sources (tarballs), ISO/VHDX/img files and build logs are not added to Git.

## Current decisions (2026-11-06)

- The scripts in this folder build the **LFS 12.4 / BLFS 12.4 test base**. That base stays the working test system until the rebuild boots.
- The planned rebuild uses **LFS 13.1-systemd + Multilib LFS 13.1 + BLFS 13.1** (D145, see [`../../docs/verification/rebuild-r1-lfs-version-2026-11-06.md`](../../docs/verification/rebuild-r1-lfs-version-2026-11-06.md)). Every base package is installed through `alp` (D141), so the file-ownership ledger is created automatically.
- Calamares module configs are in `calamares/modules/`: `grubcfg.conf` and `bootloader.conf`. The installed system boots with `root=PARTUUID` (D144, see [`../../docs/verification/m11-d144-partuuid-2026-11-06.md`](../../docs/verification/m11-d144-partuuid-2026-11-06.md)).
- `live-iso/check-live-tools.sh` **fails today**: `rsync`, `unsquashfs` and `mksquashfs` are missing from the chroot at `/mnt/lfs`.

## Contents

- `order.txt` — package order (340 lines; packages 017/018/020/191 are skipped because their source is missing). `wc -l` counted 343 lines on 2026-11-06; this count is not yet reconciled.
- `src-meta/packages.tsv` — package name, version, tarball, URL, md5/sha256 and notes.
- `build-cmds/packages/*.sh` — build commands taken from the book or, where the book has no entry, from the official upstream. Added packages: 279a lm-sensors, 279b PyCairo, 279c lcms2, 279d libva, 279e libei, 336 Konsole, 337 Zsh.
- `gen_blfs_chroot.py` — generates a chroot script for each package (blocks, `BLOK-FAIL` check, group loops, deviation patches).
- `run_blfs.sh` — sequential runner (root). Paths are fixed to `/home/yrslf/alpbahOS/scratch-lfs-bench/blfs-plan`.
- `post_blfs_test_config.sh` — root configuration of the test image (idempotent). No password is in the script; it is read only from the `ALPBAH_TEST_PASSWORD` environment variable.
- `build_image7.sh`, `mount_lfs.sh`, `umount_lfs.sh` — disk image creation and chroot mounts.

The book page cache (`build-cmds/raw/`) is not included here. It is derived from the book's own HTML and is not redistributed. The extractor `build-cmds/extract_blocks.py` is included.

The full list of deviations is in `../../docs/verification/evidence-2026-11-05/DEVIATIONS.md`.
