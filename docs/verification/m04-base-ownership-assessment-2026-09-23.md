# M04 base package ownership assessment — 2026-09-23

## Result

M04 remains partial. The existing `/mnt/lfs` rootfs does not contain package-to-file ownership records for its LFS base installation, so no base package ownership claim is made from this audit.

## Builder evidence

Environment: Builder VM `yrsk`, accessed as `sa` over SSH; target `/mnt/lfs`.

Read-only commands:

```sh
sudo -n cat /mnt/lfs/var/lib/alp/db.json
sudo -n find /mnt/lfs/sources -maxdepth 3 -name install_manifest.txt -printf '%P\n'
sudo -n stat -c '%n %s bytes %y' /mnt/lfs/var/lib/alp/db.json
```

Results:

- `db.json` contains `"packages": {}` (83 bytes; updated 2026-09-23 03:35:56 UTC). It tracks no installed base package.
- The original `find -maxdepth 3` scan reported nine `install_manifest.txt` files: CMake, QtBase, QtPositioning, QtTools, QtSpeech, QtLocation, QtSvg, QtMultimedia, and QCoro. A later scan of deeper source trees found 88 under `/mnt/lfs/sources/kde`, 2 under `/mnt/lfs/sources/qt`, and 6 under `/mnt/lfs/sources/qt-build`, with additional manifests for Qt5Compat, QtSensors, Double Conversion, and QCoro. These are BLFS/desktop builds and do not establish ownership for the LFS base packages.
- The regular filesystem owner (`root:root`, etc.) is not package ownership. It cannot be used to reconstruct which package installed a path.
- Rechecked during the M05 continuation: live `/mnt/lfs/var/lib/alp/db.json` still has an empty `packages` object, `/mnt/lfs/usr/lib/alp/alp.py` has expected SHA-256 `7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132`, Builder `/` has 25 GiB free, and `/sys/block/nbd0` is absent. No image was attached or modified for this check.

## M04 status and next record method

Do not backfill the LFS base package database from current file owners or guess from package names. For future package installs, capture each package's staged install tree or a complete install manifest before merging into `/mnt/lfs`; record package/version/source checksum, relative path, file type, mode, uid/gid, symlink target, and SHA-256 for regular files. Existing base packages can be attributed only when a preserved install manifest/log proves the exact path set; otherwise rebuild/reinstall them through the capture path before claiming M04 ownership coverage.

M04's ownership-record exit condition remains open. Existing manifests are for BLFS/desktop packages; no preserved complete manifests for the installed LFS base were found, and the empty package database cannot safely be populated from filesystem owners. Closing M04 requires a controlled, package-by-package base reinstall/rebuild with staged install trees captured before merge into `/mnt/lfs`, or discovery of equivalent complete historical install manifests. This assessment is diagnostic evidence, not a package ownership manifest.

## Staged-install capture utility

Added `scripts/capture-package-manifest.py` to serialize a completed staging tree as a standalone JSON sidecar. It records package/version/source URL and checksum, every relative path, entry type, mode, uid/gid, symlink target, and SHA-256 plus size for regular files. It rejects an empty staging tree, an invalid source checksum, output paths inside the stage, and files that change while being hashed. The tool does not alter `/mnt/lfs` or the `alp` database.

Validation: ran the script on a temporary fixture containing `/usr/bin/fixture` plus its two parent directories. It emitted 3 entries (2 directories, 1 regular file); assertions verified package identity, path, mode/uid/gid types, size, and the fixture file's SHA-256. The temporary fixture and output were removed automatically. This validates the capture format only; it creates no LFS base package ownership records and does not close M04.

Next use: for each package that is rebuilt/reinstalled in Builder `/mnt/lfs` chroot, direct its install step to a package-specific staging tree, verify that tree is complete, then run the capture tool with the verified source archive checksum. Preserve the resulting sidecar and reconcile its path set with the package's `alp` record before claiming package ownership. Existing base packages still require proven historical manifests or a controlled reinstall through this path.

## Builder recheck — 2026-09-23 23:37 UTC

Read-only verification from Windows via `ssh alp-builder`:

- Builder `yrsk`; `/mnt/lfs` resolves to the Builder root filesystem (`/`), not a separate mount.
- `/mnt/lfs/usr/lib/alp/alp.py` remains SHA-256
  `7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132`.
- `/mnt/lfs/var/lib/alp/db.json` still has `packages: {}`.
- `/mnt/lfs/etc/systemd/system/getty.target.wants/getty@tty1.service` points
  to `/usr/lib/systemd/system/getty@.service`;
  `systemd-resolved.service` has both required symlinks; `/etc/resolv.conf`
  points to `../run/systemd/resolve/stub-resolv.conf`.
- `/mnt/lfs/usr/lib/systemd/user/plasma-kwin_wayland.service` points to the
  packaged unit under `/opt/kf6`.
- Builder `/` has 13 GiB free (87% used); `/sys/block/nbd0` is absent. No
  `make`, `ninja`, or `cmake` build process was present. A targeted source scan
  showed current manifests beginning with CMake and KDE/BLFS packages; this is
  consistent with, but does not expand, the earlier full scan that found no
  complete LFS-base install manifests.

No rootfs files, package database, VHDX, or mounts were changed by this check.
M04 remains open: no LFS-base path ownership is claimed.

## Builder storage and ownership recheck — 24 September 2026

The Builder VHDX and LVM capacity were checked to determine whether the
ownership-recovery work had usable staging space:

- Windows Hyper-V reports Builder disk `F:\alpbahOS-build\vhdx\alpbah-builder.vhdx`
  as dynamic VHDX, 210 GiB virtual size and 104,492,695,552 bytes on host at
  inspection. Builder guest sees `/dev/sda` 210 GiB; `/dev/sda3` is a 206.95
  GiB LVM PV. The root LV had been limited to 100 GiB despite 106.95 GiB free
  extents.
- `sudo -n lvextend --test -r -L +60G /dev/ubuntu-vg/ubuntu-lv` reported a
  100→160 GiB resize without updating metadata. Before applying, no `make`,
  `ninja`, or `cmake` process was active, `/sys/block/nbd0/pid` was absent
  (no NBD image attached), and a root-readable scan found no VHDX under Builder
  `/tmp`. `lsblk` lists configured `nbd0`–`nbd15` nodes at 0 B; they are idle.
- The online command `sudo -n lvextend -r -L +60G
  /dev/ubuntu-vg/ubuntu-lv` succeeded. `resize2fs` grew the mounted ext4
  filesystem without stopping Builder. Result: root LV 160 GiB, ext4 157 GiB,
  81 GiB used / 69 GiB free; VG now has 46.95 GiB free. `/mnt/lfs` remains on
  Builder `/`, not a separate mount.
- Read-only `du` measured `/mnt/lfs` 54 GiB total, `sources` 19 GiB, `tmp` 430
  MiB, and `/usr` 4.9 GiB. `/mnt/lfs/var/lib/alp/db.json` remains empty and
  `alp.py` retains the expected SHA-256. No LFS-base package manifest was
  created by this capacity change.
- Host F: volume had 136,840,237,056 bytes free at the same inspection. The
  dynamic VHDX can grow within its 210 GiB virtual cap; keep the project storage
  budget in view before staging a complete rebuild.

This capacity change reduces the Builder root-space constraint but does not
close M04. A package-by-package base capture/rebuild plan is still required;
do not backfill ownership from filesystem metadata.

## Coreutils staged-install pilot — 2026-09-24

This pilot used the Builder `yrsk` and kept all build/install work in the
`/mnt/lfs` chroot. The target rootfs package database and installed `/usr`
files were not changed. Only a separate source/build tree under
`/mnt/lfs/build/coreutils-9.7-m04`, logs under `/mnt/lfs/tmp/alp-logs`, and a
temporary DESTDIR tree under `/mnt/lfs/tmp/alp-m04-coreutils-stage` were
created.

### Source and build evidence

- LFS 12.4-systemd identifies Coreutils 9.7 source archive
  `https://ftp.gnu.org/gnu/coreutils/coreutils-9.7.tar.xz`, MD5
  `6b7285faf7d5eb91592bdd689270d3f1`; the Builder archive matched. Its local
  SHA-256 is `e8bb26ad0293f9b5a1fc43fb42ba970e312c66ce92c1b0b16713d7500db251bf`.
- The two official LFS patches matched their published MD5 values:
  upstream fix `96382a5aa85d6651a74f94ffb61785d9`, i18n fix
  `33ebfad32b2dfb8417c3335c08671206`.
- The native Chapter 8 build used `autoreconf -fv`, `automake -af`,
  `FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr
  --enable-no-install-program=kill,uptime`, then `make -j2`. Build log:
  `/mnt/lfs/tmp/alp-logs/m04-coreutils-9.7-staging-build.log`, SHA-256
  `254368ccd1561d9f18cad0ac3b05376141a22d4a9ce914f55989e1a241a47339`.
- `make -j1 install DESTDIR=/tmp/alp-m04-coreutils-stage` completed in the
  chroot. The LFS FHS moves for `chroot` and its manual page were applied only
  inside the stage. Install log SHA-256:
  `07d97fb8278202cd96860bbeab28eed71606730acf0f3c70ed9e2e3b2e4f8ee9`.
- After excluding `/usr/bin/hostname` (owned by Inetutils) and the shared
  generated `/usr/share/info/dir`, the captured manifest has 445 entries:
  146 directories, 254 regular files, and 45 symlinks. The JSON is preserved at
  [`coreutils-9.7-2026-09-24.json`](manifests/lfs-base/coreutils-9.7-2026-09-24.json),
  SHA-256 `942e0007d51e07b1857982576842105b1ca434973e458eaa3e24a7e260ca6260`.

### What the comparison proves

The preflight matched every current path to either the staged final package or
the retained Chapter 6 bootstrap build; it found no unclassified file/type
conflict:

- 146 package directories already exist and are shared.
- 105 current files that the final package would replace match the old
  `coreutils-9.7` Chapter 6 build output byte-for-byte. This includes
  `/usr/bin/ls`: installed SHA-256 `82e6f443cd7ca53ea05d2546872a034b2d873a387f02a0129e493339bdf485bf`,
  owner `1001:1001`, size 776,856 bytes, equal to
  `/mnt/lfs/build/coreutils-9.7/src/ls`.
- 104 final documentation paths are absent from the rootfs and would be new.
- 45 regular files and 45 symlinks already match the final stage exactly.
- The preflight reported zero unresolved conflicts. Its summary is preserved in
  [`coreutils-9.7-2026-09-24-preflight.json`](manifests/lfs-base/coreutils-9.7-2026-09-24-preflight.json).

The final Chapter 8 Coreutils stage is therefore not a manifest for the current
rootfs: the current executable set is still the temporary Chapter 6 build.
Stage functional smoke checks passed for `ls`, `install`, `chroot`, and
`printf` (each reported GNU Coreutils 9.7 or produced the expected output).

### M04 decision

The staged manifest and preflight are useful evidence, but they do not yet
authorize a database ownership claim. `alp` currently treats every non-Flatpak
record as removable; it has no protected/essential base-package behavior.
Registering Coreutils in `db.json` would let `alp remove coreutils` unlink
essential system commands. No package files or database entries were changed
in this pilot. M04 remains open until the base-package lifecycle has an
explicit protection mechanism and the complete installed LFS base has
verified package-to-path records. The `alp` source is Claude-owned in the
environment guide; this pilot did not modify it.

Primary LFS references: [Coreutils 9.7 Chapter 8 instructions](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/coreutils.html),
[LFS 12.4 required patch checksums](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter03/patches.html),
[Chapter 6 temporary Coreutils instructions](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter06/coreutils.html).

## Package-removal guard recheck — 24 September 2026

Read-only inspection of `C:\alpbahOS-claude`, branch
`claude/desktop-bootstrap`, HEAD `8df1ac410d1401b51e11b0220fbfa8173331cbb6`
(one commit ahead of its remote), found a newer `alp.py` than the exact
`e8b0376` source pinned for the installed rootfs. Its file SHA-256 is
`a34b796d64d14ea20d8228708f1add135e37e2328eac96efbca448b2b95f510e`; it was
not installed.

That version defines `_is_protected()` for a fixed set of system directories
and alp's state directory. `_remove_owned_paths()` skips those exact paths,
but it does not protect files merely because they belong to an essential base
package. `remove_package()` still passes all other recorded files to deletion
and removes the package record from the database. Therefore the newer Claude
branch does not yet make an `lfs-base`/Coreutils DB record safe to remove. The
rootfs's required `e8b0376` hash remains the pin; no `alp.py`, `/usr`, or DB
changes were made during this inspection.

Builder inventory at this recheck: no active `make`/`ninja`/`cmake`, no NBD
device, 69 GiB free on `/`, 128 regular source files at the top level of
`/mnt/lfs/sources`, and `/mnt/lfs/var/lib/alp/db.json` still reports zero
packages. Sources make controlled per-package staging possible, but they do
not supply historical installed-path ownership. M04 remains open pending
complete base-package manifests and a package-level removal guard from the
`alp` owner.

## Zlib 1.3.1 staged recovery — 24 September 2026

Zlib was rebuilt in the Builder's `/mnt/lfs` chroot and installed only into a
separate DESTDIR tree. The installed `/mnt/lfs/usr` and `alp` database were not
written. The source archive was `/mnt/lfs/sources/zlib-1.3.1.tar.gz`; its MD5
was `9855b6d802d7fe5b7bd5b196a2271655` and SHA-256 was
`9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23`.

The successful clean retry used build directory
`/mnt/lfs/build/zlib-1.3.1-m04-r3`, owned by UID/GID 1001. It extracted the
archive as `lfs`, configured `--prefix=/usr`, ran `make -j2` and `make check`,
then installed as root with `DESTDIR=/tmp/alp-m04-zlib-stage-r3` and removed
the static `libz.a`, matching the LFS 12.4-systemd package instructions.
`make check` reported `zlib test OK`, `zlib shared test OK`, and
`zlib 64-bit test OK`. The build log is
`/mnt/lfs/tmp/alp-logs/m04-zlib-1.3.1-build-20260924-r3.log`, SHA-256
`0ea63af226586d372e3a20f481b825a0096a376d6794c96346f70e490eaddf98`.

The captured manifest contains 14 entries (7 directories, 5 regular files,
2 symlinks), SHA-256
`14b0eeda9829731a1e3d1a93b970dd4e8775f38696b5d7d662a1c7a5bcce3496`, and is
preserved at
[`zlib-1.3.1-2026-09-24.json`](manifests/lfs-base/zlib-1.3.1-2026-09-24.json).
The new read-only `scripts/compare-package-manifest.py` compared every entry
against `/mnt/lfs`: `entries=14 matched=14 mismatched=0`. It checks object
type, mode, uid/gid, regular-file size and SHA-256, and symlink target. The
stage and rootfs shared-file hashes matched, including `libz.so.1.3.1`, both
headers, pkg-config metadata, and the man page.

This recovers a verified Zlib install path set, but does not close M04. The
comparison proves current files match the tested Zlib staged tree; it does
not supply the missing removal protection. `/mnt/lfs/var/lib/alp/db.json`
remains empty, the rootfs `alp.py` pin was not changed, and no package record
was added. Standard `/dev`, `/proc`, `/sys`, and `/run` bind mounts were
detached on exit; the ERR trap recorded two earlier pre-install failures in
separate retry logs, and the successful run ended with
`CLEANUP_OK no mounts remain below /mnt/lfs`.

The LFS 12.4-systemd Zlib instructions were followed:
[Zlib-1.3.1](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/zlib.html).

## Gzip, Zstd, and Xz staged comparison — 24 September 2026

Three more LFS base packages were built/tested in the Builder `/mnt/lfs`
chroot and installed into separate DESTDIR trees. Their target-rootfs files
were not changed. All three source archives matched the LFS 12.4-systemd MD5
checksums before extraction.

| Package | Build and tests | Staged manifest | Read-only `/mnt/lfs` preflight |
|---|---|---|---|
| Gzip 1.14 | `./configure --prefix=/usr`, `make -j2`, `make check`: 30/30 pass | 32 entries (6 directories, 26 files), SHA-256 `f4e1d9ea6deaa3ddfa4c9a8c9e8fe634b97e13c51426611efae9155355b8c150`; shared generated `/usr/share/info/dir` was omitted | 5 matched, 27 mismatched; installed command files are UID/GID 1001 Chapter 6 outputs with different hashes; final man pages are absent. Not installed to rootfs. |
| Zstd 1.5.7 | `make prefix=/usr -j2`, `make check`: completed successfully; `make prefix=/usr install`, then static archive removal | 26 entries (8 directories, 11 files, 7 symlinks), SHA-256 `c4365a81edc9e6cca2d053fdf653ee3b4b502b34b4c6618969c97f925285dc49` | 24 matched, 2 mismatched; `/usr/bin/zstd` hash differs (stage 10,473,928 bytes; rootfs 10,473,808), and `libzstd.so.1.5.7` differs despite equal size. Not installed to rootfs. |
| Xz 5.8.1 | `./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/xz-5.8.1`, `make -j2`, `make check`: 19/19 pass | 348 entries (79 directories, 126 files, 143 symlinks), SHA-256 `d107d06674565c111d5d8873d3694a8dbcf611a7e2eb86aa9d8755358d0a1134` | 290 matched, 58 mismatched. Not installed to rootfs. |

The manifests and complete machine-readable mismatch reports are preserved as
[`gzip manifest`](manifests/lfs-base/gzip-1.14-2026-09-24.json),
[`gzip preflight`](manifests/lfs-base/gzip-1.14-2026-09-24-preflight.log),
[`Zstd manifest`](manifests/lfs-base/zstd-1.5.7-2026-09-24.json),
[`Zstd preflight`](manifests/lfs-base/zstd-1.5.7-2026-09-24-preflight.log),
[`Xz manifest`](manifests/lfs-base/xz-5.8.1-2026-09-24.json), and
[`Xz preflight`](manifests/lfs-base/xz-5.8.1-2026-09-24-preflight.log).
Build logs remain on Builder under `/mnt/lfs/tmp/alp-logs/`:
`m04-gzip-1.14-build-20260924.log` (SHA-256
`b62a9b3b58934b1b19ce7e726762abc58680625ca04713ed16cef6c6beb76f95`),
`m04-zstd-1.5.7-build-20260924.log` (SHA-256
`dbf7437b9afeee07f2788d58d1985f689e341501531baeaefa539735afc7c7b7`), and
`m04-xz-5.8.1-build-20260924.log` (SHA-256
`e44e358e090bf1da0477753ec98ebeb65ce55f5269a91b52beb8129843df8ddc`). Each
run used a clean UID/GID 1001 build tree, root-only stage install, ERR/EXIT
traps, and `/dev`, `/proc`, `/sys`, `/run` bind mounts detached before exit.
The checks show that passing upstream tests does not prove the current rootfs
contains those final Chapter 8 install outputs. Stage-to-rootfs mismatches
must be resolved before claiming those path sets for M04.

Official LFS 12.4-systemd procedures:
[Gzip-1.14](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/gzip.html),
[Zstd-1.5.7](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/zstd.html),
[Xz-5.8.1](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/xz.html).
