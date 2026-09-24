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

## Gzip, Zstd, Xz, and Bzip2 staged comparison — 24 September 2026

Three more LFS base packages were built/tested in the Builder `/mnt/lfs`
chroot and installed into separate DESTDIR trees. Their target-rootfs files
were not changed. All three source archives matched the LFS 12.4-systemd MD5
checksums before extraction.

| Package | Build and tests | Staged manifest | Read-only `/mnt/lfs` preflight |
|---|---|---|---|
| Gzip 1.14 | `./configure --prefix=/usr`, `make -j2`, `make check`: 30/30 pass | 32 entries (6 directories, 26 files), SHA-256 `f4e1d9ea6deaa3ddfa4c9a8c9e8fe634b97e13c51426611efae9155355b8c150`; shared generated `/usr/share/info/dir` was omitted | 5 matched, 27 mismatched; installed command files are UID/GID 1001 Chapter 6 outputs with different hashes; final man pages are absent. Not installed to rootfs. |
| Zstd 1.5.7 | `make prefix=/usr -j2`, `make check`: completed successfully; `make prefix=/usr install`, then static archive removal | 26 entries (8 directories, 11 files, 7 symlinks), SHA-256 `c4365a81edc9e6cca2d053fdf653ee3b4b502b34b4c6618969c97f925285dc49` | 24 matched, 2 mismatched; `/usr/bin/zstd` hash differs (stage 10,473,928 bytes; rootfs 10,473,808), and `libzstd.so.1.5.7` differs despite equal size. Not installed to rootfs. |
| Xz 5.8.1 | `./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/xz-5.8.1`, `make -j2`, `make check`: 19/19 pass | 348 entries (79 directories, 126 files, 143 symlinks), SHA-256 `d107d06674565c111d5d8873d3694a8dbcf611a7e2eb86aa9d8755358d0a1134` | 290 matched, 58 mismatched. Not installed to rootfs. |
| Bzip2 1.0.8 | LFS patch applied; `make -f Makefile-libbz2_so -j2`, `make clean`, `make -j2`; all six source/reference round-trip comparisons passed | 36 entries (9 directories, 19 files, 8 symlinks), SHA-256 `c38c928beacb673344a083c8895707fab00842446cae6640c5130ec7b07e36a8` | 31 matched, 5 mismatched: bzip2 and bzip2recover binaries differ; libbz2 symlink target matches but file hash differs and stage/rootfs symlink ownership differs; shared `/usr/share/doc` mode/owner differs. Not installed to rootfs. |
| Lz4 1.10.0 | `make BUILD_STATIC=no PREFIX=/usr -j2`; `make -j1 check` passed | 23 entries (8 directories, 7 files, 8 symlinks), SHA-256 `3a7f8a461c25b970509ea6a2bf1194489454ece67eff58bfaaf0fc74d7862730` | 23 matched, 0 mismatched. This is an exact staged file-set match. No install was merged to rootfs and no DB record was added. |
| File 5.46 | `./configure --prefix=/usr`, `make -j2`, `make check` all completed | 23 entries (12 directories, 9 files, 2 symlinks), SHA-256 `3fe983255f365d90269add1232c6fc03d83ccdd5774db51f1221acb91444fb8f` | 20 matched, 3 mismatched: `/usr/bin/file` has the same size but a different SHA-256; `libmagic.so.1.0.0` has a different SHA-256 and is 8 bytes smaller in the rootfs; `/usr/share/misc` directory owner/mode differs. Not installed to rootfs. |
| Readline 8.3 | LFS configuration, `make -j2 SHLIB_LIBS="-lncursesw"`; LFS has no test suite. A staged API smoke read `readline-stage-smoke`; loader resolved both staged shared libraries, and no library RPATH/RUNPATH was present. | 39 entries (12 directories, 23 files, 4 symlinks), SHA-256 `89905b7dff6b4e65cba4855705db6944732583ca8a66d0a6a42e91c6cb7d49dc` | 34 matched, 5 mismatched: `libhistory.so.8.3` and `libreadline.so.8.3` differ by 8 bytes each; `readline.pc` differs by one byte; shared `/usr/share/doc` and `/usr/share/info` directory metadata differs. Not installed to rootfs. |

The manifests and complete machine-readable mismatch reports are preserved as
[`gzip manifest`](manifests/lfs-base/gzip-1.14-2026-09-24.json),
[`gzip preflight`](manifests/lfs-base/gzip-1.14-2026-09-24-preflight.log),
[`Zstd manifest`](manifests/lfs-base/zstd-1.5.7-2026-09-24.json),
[`Zstd preflight`](manifests/lfs-base/zstd-1.5.7-2026-09-24-preflight.log),
[`Xz manifest`](manifests/lfs-base/xz-5.8.1-2026-09-24.json), and
[`Xz preflight`](manifests/lfs-base/xz-5.8.1-2026-09-24-preflight.log).
The Bzip2 evidence is preserved as [`Bzip2 manifest`](manifests/lfs-base/bzip2-1.0.8-2026-09-24.json)
and [`Bzip2 preflight`](manifests/lfs-base/bzip2-1.0.8-2026-09-24-preflight.log).
Lz4 evidence is preserved as [`Lz4 manifest`](manifests/lfs-base/lz4-1.10.0-2026-09-24.json)
and [`Lz4 preflight`](manifests/lfs-base/lz4-1.10.0-2026-09-24-preflight.log).
File evidence is preserved as [`File manifest`](manifests/lfs-base/file-5.46-2026-09-24.json)
and [`File preflight`](manifests/lfs-base/file-5.46-2026-09-24-preflight.log).
Readline evidence is preserved as [`Readline manifest`](manifests/lfs-base/readline-8.3-2026-09-24.json)
and [`Readline preflight`](manifests/lfs-base/readline-8.3-2026-09-24-preflight.log).
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

Bzip2's successful retry used the extra `/mnt/lfs/tmp/alp-logs/` files
`m04-bzip2-1.0.8-build-20260924-r2.log` (SHA-256
`7746876e05b5d90acd4692f4b3dec183fe207723737258bb7603c40f243ca861`),
`m04-bzip2-1.0.8-manifest-20260924-r2.json` (SHA-256
`c38c928beacb673344a083c8895707fab00842446cae6640c5130ec7b07e36a8`), and
`m04-bzip2-1.0.8-preflight-20260924-r2.log` (SHA-256
`e072f18a5743fda452ff8b085fe18c384e40adea1f41863439efa96125cabe0e`). An
earlier stage attempt logged a shell-expansion error and absolute symlinks in
its isolated tree; that tree was not used. A fresh retry verified relative
program symlinks before capturing the manifest. No rootfs or DB changes were
made by either attempt.

The Bzip2 source archive was verified against LFS MD5
`67e051268d0c475ea773822f7500d0e5` (SHA-256
`ab5a03176ee106d3f0fa90e381da478ddae405918153cca248e682cd0c4a2269`); the
documentation patch matched MD5 `6a5ac7e89b791aae556de0f745916f7f`.

Lz4 was built in `/mnt/lfs/build/lz4-1.10.0-m04` from the verified source
archive (MD5 `dead9f5f1966d9ae56e1e32761e4e675`, SHA-256
`537512904744b35e232912055ccf8ec66d768639ff3abe5788d90d792ec5f48b`). The
LFS commands `make BUILD_STATIC=no PREFIX=/usr`, `make -j1 check`, and
`make BUILD_STATIC=no PREFIX=/usr DESTDIR=/tmp/alp-m04-lz4-stage install`
completed successfully. Its build log SHA-256 is
`d0a8d40c699c17c24f5d4ac42d12cd74b235a45f02763163ec80cb5563c2b8d9`; the 23
entry manifest hash is `3a7f8a461c25b970509ea6a2bf1194489454ece67eff58bfaaf0fc74d7862730`.
Read-only comparison reported `entries=23 matched=23 mismatched=0`; the full
preflight output SHA-256 is
`1741fe0a9ce8b38b81fd5c1d319a8fefdb11fdfe5ffa023a2d70a5219fe573b8`. This
recovers a verified current Lz4 path set, but the rootfs and `alp` DB were not
modified. LFS reference:
[Lz4-1.10.0](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/lz4.html).

File 5.46 was built in `/mnt/lfs/build/file-5.46-m04` from source verified
against LFS MD5 `459da2d4b534801e2e2861611d823864` and SHA-256
`c9cc77c7c560c543135edc555af609d5619dbef011997e988ce40a3d75d86088`. The
build used `./configure --prefix=/usr`, `make -j2`, `make check`, and root
`make DESTDIR=/tmp/alp-m04-file-stage install`. Log SHA-256 is
`9916bd6750991de0aca196b7b804d0af4c1e7529e94285ca8006504dbba9d00a`;
manifest SHA-256 is `3fe983255f365d90269add1232c6fc03d83ccdd5774db51f1221acb91444fb8f`;
preflight SHA-256 is
`6fb2a395f794dff8b75bb180e8c5454b37afa86ca10ef83b637221c9e3709b30`.
The preflight result was `entries=23 matched=20 mismatched=3`. This stage was
not merged into `/mnt/lfs/usr` and no ownership record was added. LFS reference:
[File-5.46](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/file.html).

Readline 8.3 was built in `/mnt/lfs/build/readline-8.3-m04-r1` from the
verified `/mnt/lfs/sources/readline-8.3.tar.gz` archive (LFS MD5
`25a73bfb2a3ad7146c5e9d4408d9f6cd`, SHA-256
`fe5383204467828cd495ee8d1d3c037a7eba1389c22bc6a041f627976f9061cc`). The
Builder `/mnt/lfs` chroot used the LFS `--disable-static --with-curses
--docdir=/usr/share/doc/readline-8.3` configuration, `SHLIB_LIBS=-lncursesw`,
and a root `DESTDIR=/tmp/alp-m04-readline-stage-r1` install. The staged
interactive API smoke returned `readline-stage-smoke`; the target dynamic
loader resolved `libreadline.so.8` and `libhistory.so.8` from the stage, and
`readelf -d` found no library RPATH/RUNPATH. The LFS book states this package
has no upstream test suite. The shared generated `/usr/share/info/dir` was
excluded from this package manifest.

The 39-entry manifest SHA-256 is
`89905b7dff6b4e65cba4855705db6944732583ca8a66d0a6a42e91c6cb7d49dc`; the
read-only preflight reported 34 matches and 5 mismatches. The two staged
shared libraries are each 8 bytes larger than their rootfs counterparts;
`readline.pc` differs by one byte; `/usr/share/doc` and `/usr/share/info`
metadata differs. None of the staged files were merged into `/mnt/lfs/usr` and
no `alp` record was added. The first smoke attempt was corrected after the
test source omitted `<stdio.h>` before `readline.h`; a second run used the
target `ldd` diagnostic and stopped at its `not a dynamic executable` output.
The successful retry used the target dynamic loader's `--list` output to prove
the staged libraries. Logs are preserved on Builder: r1 SHA-256
`2f63e68b3199709e09a0632d4fa488ad53b20333ee22d1cfbafa33d69dfd841e`, r2
`c3790d2bd84d0cc03e52081cc47179564a06a13492d1134fdf3d00a035de56fb`, and
successful r3 `a7e9779dfd189f7d7601f1c971265324b5b9f610ab514741c32eb58d666d67c4`.
All were under `/mnt/lfs/tmp/alp-logs/`. The final run unmounted `/dev`,
`/dev/pts`, `/proc`, `/sys`, and `/run`; Builder had no active build process,
NBD PID, or VHDX under `/tmp`, with 69 GiB free. Rootfs `alp.py` retained the
required SHA-256 and `db.json` remained empty. LFS references:
[Readline 8.3 build instructions](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/readline.html),
[official archive checksum](https://www.linuxfromscratch.org/lfs/view/stable/chapter03/packages.html).

## M4 1.4.20 staged comparison — 24 September 2026

M4 1.4.20 was built in the Builder `/mnt/lfs` chroot from the verified source
archive (SHA-256
`e236ea3a1ccf5f6c270b1c4bb60726f371fa49459a8eaaebc90b216b328daf2b`), using
`./configure --prefix=/usr`, `make -j2`, and `make check`. The test log records
306 PASS, 60 SKIP, 0 FAIL, and 0 ERROR. A stage-only smoke test expanded a
definition to `42`. The install went to
`/mnt/lfs/tmp/alp-m04-m4-stage-r1`, not the rootfs.

The manifest contains 93 entries (61 directories, 32 files), SHA-256
`CBD3B8B1444DA81BF841E75005D63151415324A5B02C7A5D0F54D75896181F89`;
[manifest](manifests/lfs-base/m4-1.4.20-2026-09-24.json). Read-only preflight
reported 36 matches and 57 mismatches; [full report](manifests/lfs-base/m4-1.4.20-2026-09-24-preflight.log),
SHA-256 `47D0823D095508A88F763CEF0F72DC096131C61BAF5EA6ED8A2E481E463B261C`.
The staged `/usr/bin/m4` differs from the current rootfs binary by 8 bytes;
56 directory metadata records differ because stage directories were created
as UID/GID 1001 with mode 0775. No stage files were merged and no `alp`
ownership record was added. Rootfs `alp.py` retained its required hash and
`db.json` remained empty.

The build log is preserved on Builder at
`/mnt/lfs/tmp/alp-logs/m04-m4-1.4.20-stage-20260924-r2.log`, SHA-256
`64be1b32854535c4093c87f5f7e686b4289ba8b3377b9ce3bac3739864e7e489`. The
EXIT trap confirmed no mounts remained below `/mnt/lfs`; `/sys/block/nbd0/pid`
was empty and 69 GiB remained free on Builder `/`. LFS reference:
[M4 1.4.20 build instructions](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/m4.html).

## Diffutils 3.12 staged comparison — 24 September 2026

Diffutils 3.12 was built in the Builder `/mnt/lfs` chroot from the archive
whose LFS MD5 is `d1b18b20868fb561f77861cd90b05de4` and SHA-256 is
`7c8b7f9fc8609141fdea9cece85249d308624391ff61dedaf528fcb337727dfd`. The
build used `./configure --prefix=/usr`, `make -j2`, and `make check`; root
installed only into `/mnt/lfs/tmp/alp-m04-diffutils-stage-r1`. Diffutils tests
reported 30 PASS, 2 SKIP, 1 XFAIL, 0 FAIL; gnulib tests reported 276 PASS,
68 SKIP, 0 FAIL. A stage smoke displayed version 3.12 and `cmp` accepted
identical inputs.

The manifest contains 124 entries (79 directories, 45 files), SHA-256
`180D9F0D60AD87C6C99147B69DC31983EE5FE19DEE0E74B5B7D2D1B9598E048C`;
[manifest](manifests/lfs-base/diffutils-3.12-2026-09-24.json). Read-only
preflight reported 5 matches and 119 mismatches; [full report](manifests/lfs-base/diffutils-3.12-2026-09-24-preflight.log),
SHA-256 `7CF0EC37D2A6CD16D7DD105B1277EE0B5954992E443D615AF7149AF59D3678D3`.
No stage files were merged and no package ownership record was added. The
initial wrapper attempt ran without sufficient privileges and stopped before
build/mount; the root rerun completed and its EXIT trap detached all mounts.
The final Builder check showed empty NBD PID, 69 GiB free, unchanged pinned
`alp.py`, and an empty `db.json`. LFS reference:
[Diffutils 3.12 build instructions](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/diffutils.html).

## Findutils 4.10.0 staged comparison — 24 September 2026

Findutils 4.10.0 was built in the Builder `/mnt/lfs` chroot from the archive
whose LFS MD5 is `870cfd71c07d37ebe56f9f4aaf4ad872` and SHA-256 is
`1387e0b67ff247d2abde998f90dfbf70c1491391a59ddfecb8ae698789f0a4f5`. It
used `./configure --prefix=/usr --localstatedir=/var/lib/locate` and `make
-j2`; `make check` ran as the LFS `tester` UID 101. The root install was
isolated to `/mnt/lfs/tmp/alp-m04-findutils-stage-r1`. Library tests reported
2 PASS, gnulib 290 PASS/72 SKIP, and Findutils tests 21 PASS/2 SKIP, with no
FAIL or ERROR. The smoke found a nested file and the staged `xargs` confirmed
it was a file.

The manifest has 144 entries (92 directories, 52 files), SHA-256
`23B55C6F711EF9309ACFAA5D1CEF40BE6DD7CEC5F3CFC845B6E206CE678075B7`;
[manifest](manifests/lfs-base/findutils-4.10.0-2026-09-24.json). Read-only
preflight reported 6 matches and 138 mismatches; [full report](manifests/lfs-base/findutils-4.10.0-2026-09-24-preflight.log),
SHA-256 `3300D70C5DC72C6EA3AFEB211BBC9C280F916ADB50B68060382F59099B8C6EB1`.
No staged paths were merged and no ownership record was added. The EXIT trap
detached all mounts; Builder retained 69 GiB free and an empty NBD PID. The
pinned `alp.py` hash and empty package database were unchanged. LFS reference:
[Findutils 4.10.0 build instructions](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/findutils.html).

## Gawk 5.3.2 staged comparison — 24 September 2026

Gawk 5.3.2 was built in the Builder `/mnt/lfs` chroot from the archive whose
LFS MD5 is `b7014650c5f45e5d4837c31209dc0037` and SHA-256 is
`f8c3486509de705192138b00ef2c00bbbdd0e84c30d5c07d23fc73a9dc4cc9cc`. The
build followed LFS: remove `extras` from `Makefile.in`, configure
`--prefix=/usr`, build with `make -j2`, and run `make check` as tester UID
101. Output reported `ALL TESTS PASSED`. Installation and the `awk.1`
symlink were created only in `/mnt/lfs/tmp/alp-m04-gawk-stage-r1`; the staged
program printed GNU Awk 5.3.2 and the arithmetic smoke printed `42`.

The manifest contains 160 entries (62 directories, 96 files, 2 symlinks),
SHA-256 `BD2910B111EE94B758C6ECDF0AF515B78B823125555F4257F5CD35D9F54EEEAA`;
[manifest](manifests/lfs-base/gawk-5.3.2-2026-09-24.json). Read-only
preflight reported 8 matches and 152 mismatches; [full report](manifests/lfs-base/gawk-5.3.2-2026-09-24-preflight.log),
SHA-256 `E8ADB73CD44F31728FF3BC9DDE82B1448803F41BA8F8A8455E7C38DC8197CFE8`.
No stage files were merged and no package ownership record was created.
Cleanup detached all mounts; NBD PID was empty, 69 GiB remained free, and
the pinned `alp.py` hash and empty database were unchanged. LFS reference:
[Gawk 5.3.2 build instructions](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/gawk.html).

## Grep 3.12 staged comparison — 24 September 2026

Grep 3.12 was built in the Builder `/mnt/lfs` chroot from the archive whose
LFS MD5 is `5d9301ed9d209c4a88c8d3a6fd08b9ac` and SHA-256 is
`2649b27c0e90e632eadcd757be06c6e9a4f48d941de51e7c0f83ff76408a07b9`. The
build followed LFS: silence the obsolete `egrep.sh` warning, configure
`--prefix=/usr`, build with `make -j2`, and run `make check`. Package tests
reported 111 PASS, 15 SKIP, 2 XFAIL; gnulib tests reported 257 PASS, 58 SKIP;
there were no FAIL or ERROR results. Locale-dependent tests were skipped for
missing locales; `glibc-infloop` was XFAIL. A staged grep smoke reported
version 3.12 and matched its sample input.

The manifest contains 147 entries (97 directories, 50 files), SHA-256
`C21657D5C08585F8828E8DA027BCDF6CE2073AEF8B00F304EE27B521EEC79591`;
[manifest](manifests/lfs-base/grep-3.12-2026-09-24.json). Read-only
preflight reported 52 matches and 95 mismatches; [full report](manifests/lfs-base/grep-3.12-2026-09-24-preflight.log),
SHA-256 `BBB540DF6FB11882A57F88169E3EFFB22E7E43AE392F1A8756CE3296560507D7`.
The report includes stage locale directories with UID/GID 1001 and mode
0775. No stage files were merged and no ownership record was created. The
EXIT trap detached all mounts; NBD PID was empty, 69 GiB remained free, and
the pinned `alp.py` hash and empty `db.json` were unchanged. LFS reference:
[Grep 3.12 build instructions](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/grep.html).

## Bash 5.3 staged comparison — 24 September 2026

Bash 5.3 was built in the Builder `/mnt/lfs` chroot from the LFS archive with
MD5 `977c8c0c5ae6309191e7768e28ebc951` and SHA-256
`0d5cd86965f869a26cf64f4b71be7b96f90a3ba8b3d74e27e8e9d9d5550f31ba`. It used
`./configure --prefix=/usr --without-bash-malloc --with-installed-readline
--docdir=/usr/share/doc/bash-5.3`, `make -j2`, and the book's Expect-based
`make tests` invocation as target `tester` UID 101. The test command exited
0. The log contains output differences for `run-builtins` ulimit behavior,
missing `zh_TW.big5`, `de_DE.UTF-8`, `fr_FR.ISO8859-1`, and `ja_JP.SJIS`
locales, locale-sensitive formatting, and system-dependent diagnostics; these
are retained as test limitations rather than reported as a clean output diff.

Installation went only to `/mnt/lfs/tmp/alp-m04-bash-stage-r1`. A stage
smoke reported GNU Bash 5.3 and arithmetic result `42`. The manifest has 261
entries (98 directories, 162 files, 1 symlink), SHA-256
`FF465D63817C1BAB9C275FA5E3F878AE102533EA955434711154F3792B9D0A6D`;
[manifest](manifests/lfs-base/bash-5.3-2026-09-24.json). Read-only comparison
reported 119 exact matches and 142 mismatches; [full report](manifests/lfs-base/bash-5.3-2026-09-24-preflight.log),
SHA-256 `565C3B44F70FAB59449E70E6426BCC5944E36A9FC49C40142DD3F81235FA9BC3`.
Mismatches include the Bash executable and loadable builtin contents, plus
rootfs directories whose owner/mode differs. No stage file was merged and no
base ownership record was added.

Builder build log `/mnt/lfs/tmp/alp-logs/m04-bash-5.3-stage-20260924-r1.log`
has SHA-256 `2b4d412475a93ad2062d701e7f52021dc2d5ee74282da307c274b89f40fe7b97`.
The EXIT trap confirmed no mounts below `/mnt/lfs`; NBD PID remained empty,
the rootfs `alp.py` hash remained pinned, and `db.json` remained empty. LFS
reference: [Bash 5.3 build instructions](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/bash.html).

## Libtool 2.5.4 staged comparison — 24 September 2026

Libtool 2.5.4 was built in the Builder `/mnt/lfs` chroot from the LFS archive
with MD5 `22e0a29df8af5fdde276ea3a7d351d30` and SHA-256
`f81f5860666b0bc7d84baddefa60d1cb9fa6fceb2398cc3baca6afaa60266675`. It
used `./configure --prefix=/usr`, `make -j2`, and `make check` as target UID
101. The main suite reported 144 tests behaving as expected and 32 skipped;
gnulib reported 4 PASS, 2 SKIP, 0 FAIL/ERROR. Installation was isolated to
`/mnt/lfs/tmp/alp-m04-libtool-stage-r1`; the LFS test-only `libltdl.a` was
removed from the stage. `libtool` and `libtoolize` both reported version
2.5.4.

The manifest has 79 entries (14 directories, 63 files, 2 symlinks), SHA-256
`073459DB30133F880F5268AA2C244DDD1CDE7DB31009AAE98B2C57C9EC021FAB`;
[manifest](manifests/lfs-base/libtool-2.5.4-2026-09-24.json). Read-only
preflight reported 75 exact matches and 4 mismatches; [full report](manifests/lfs-base/libtool-2.5.4-2026-09-24-preflight.log),
SHA-256 `F7F8EBD8FAB670D124ED802AC9F89F6352EB963DC912FF553F062853F793F066`.
The mismatches are `/usr/bin/libtool` (generated script differs by 26 bytes),
`/usr/lib/libltdl.so.7.3.3` (binary differs by 8 bytes), and shared
`/usr/share/info` metadata/index differences. No staged file was merged and
no ownership record was added.

Builder log `/mnt/lfs/tmp/alp-logs/m04-libtool-2.5.4-stage-20260924-r1.log`
SHA-256 `94c688bfbb39c52470eb30c81f6b3e5f640fcc42fc2af533cbb13bae8664ad61`.
The EXIT trap found no mounts below `/mnt/lfs`; NBD PID remained empty, the
pinned rootfs `alp.py` hash was unchanged, and `db.json` remained empty. LFS
reference: [Libtool 2.5.4 instructions](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/libtool.html).

## GDBM 1.26 staged comparison — 24 September 2026

GDBM 1.26 was built in the Builder `/mnt/lfs` chroot from the LFS source
archive with MD5 `aaa600665bc89e2febb3c7bd90679115` and SHA-256
`6a24504a14de4a744103dcb936be976df6fbe88ccff26065e54c1c47946f4a5e`. The
build used `./configure --prefix=/usr --disable-static
--enable-libgdbm-compat`, `make -j2`, and `make check` as target UID 101. All
38 GDBM package tests were successful; the stage-only smoke reported GDBM
1.26 from `gdbm_dump` and `gdbm_load`.

Installation went to `/mnt/lfs/tmp/alp-m04-gdbm-stage-r1`. The manifest has
78 entries (42 directories, 32 files, 4 symlinks), SHA-256
`9AAAEFDEE2C8E12D169B7574762F50168039DAC877D53A1208C13415B4AFEE88`;
[manifest](manifests/lfs-base/gdbm-1.26-2026-09-24.json). Read-only preflight
reported 38 exact matches and 40 mismatches; [full report](manifests/lfs-base/gdbm-1.26-2026-09-24-preflight.log),
SHA-256 `E06E4AD03A1C3ADED2763D1B0F2687A703F3AB23095D30024978DBF2271577FB`.
The mismatches include the three program binaries, both shared library
binaries, and rootfs shared-info/directory metadata. No staged file was
merged and no package ownership record was added.

Builder log `/mnt/lfs/tmp/alp-logs/m04-gdbm-1.26-stage-20260924-r1.log`
SHA-256 `805ca65ad4a2c112a1880f6d30cfc5925fe65d34397d2baf5132c681b41fd84f`.
EXIT cleanup found no mounts below `/mnt/lfs`; NBD PID remained empty, 68 GiB
was free, the pinned rootfs `alp.py` hash was unchanged, and `db.json` stayed
empty. LFS reference: [GDBM 1.26 instructions](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/gdbm.html).

## Gperf 3.3 staged comparison — 24 September 2026

Gperf 3.3 was built in the Builder `/mnt/lfs` chroot from the LFS source
archive with MD5 `31753b021ea78a21f154bf9eecb8b079` and SHA-256
`fd87e0aba7e43ae054837afd6cd4db03a3f2693deb3619085e6ed9d8d9604ad8`. It
used `./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.3`, `make
-j2`, and `make check`; the test command exited 0. The stage-only smoke
reported GNU gperf 3.3. Installation went to
`/mnt/lfs/tmp/alp-m04-gperf-stage-r1`; generated shared `info/dir` was
removed from the stage.

The manifest has 12 entries (8 directories, 4 files), SHA-256
`4390C72BD9A1D7FBA284C01C6B3BA1E72D3FC3BA0BF9722A0B3D3649726BA5A7`;
[manifest](manifests/lfs-base/gperf-3.3-2026-09-24.json). Read-only preflight
reported 7 exact matches and 5 mismatches; [full report](manifests/lfs-base/gperf-3.3-2026-09-24-preflight.log),
SHA-256 `4B56FB0D563F2B2F0AA3FC5DDE0D1BB63BF25B659D3C61E4F7F626E245EE1497`.
The mismatches are `/usr/bin/gperf`, shared `/usr/share/doc` and
`/usr/share/info` metadata, and `/usr/share/doc/gperf-3.3` files absent from
the current rootfs. No staged file was merged.

Builder log `/mnt/lfs/tmp/alp-logs/m04-gperf-3.3-stage-20260924-r1.log`
SHA-256 `02fd820eecb3aefd024412ba16de4f0feceda300c5081237bc4ba53f32edb117`.
EXIT cleanup found no mounts below `/mnt/lfs`; NBD PID remained empty, 68 GiB
was free, rootfs `alp.py` retained the pinned hash, and `db.json` remained
empty. LFS reference: [Gperf 3.3 instructions](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/gperf.html).

## Expat 2.7.1 staged comparison — 24 September 2026

Expat 2.7.1 follows the pinned LFS 12.4-systemd package definition. The
Builder source archive `/mnt/lfs/sources/expat-2.7.1.tar.xz` matched LFS MD5
`9f0c266ff4b9720beae0c6bd53ae4469` and SHA-256
`354552544b8f99012e5062f7d570ec77f14b412a3ff5c7d8d0dae62c0d217c30`.
Configuration was `--prefix=/usr --disable-static
--docdir=/usr/share/doc/expat-2.7.1`; `make -j2` and `make check` ran in the
`/mnt/lfs` chroot. The suite reported 2 PASS, 0 SKIP, 0 XFAIL, 0 FAIL, and
0 ERROR. Installation, including the optional HTML/CSS documentation, went
only to `/mnt/lfs/tmp/alp-m04-expat-stage-r1`. The stage-only `xmlwf` accepted
a valid XML fixture with the staged shared library on `LD_LIBRARY_PATH`.

The manifest has 31 entries (12 directories, 17 files, 2 symlinks), SHA-256
`65aa6086b0176796af35b47ee6431a275be78aa9f6c376b41852918af6833fa0`;
[manifest](manifests/lfs-base/expat-2.7.1-2026-09-24.json). Read-only
preflight reported 25 exact matches and 6 mismatches; [full report](manifests/lfs-base/expat-2.7.1-2026-09-24-preflight.log),
SHA-256 `f61101dc360e9d63e0112948c2cb0ca34b2814801072af1d0be797217008a543`.
The mismatches are `/usr/bin/xmlwf`, `/usr/lib/libexpat.so.1.10.2`, shared
`/usr/share/doc` metadata, and three HTML/CSS files absent from the current
rootfs. No staged file was merged and no ownership record was added.

Builder log `/mnt/lfs/tmp/alp-logs/m04-expat-2.7.1-stage-20260924-r1.log`
SHA-256 `0a3a501c0c70695f9929e4d4effc3f8e4e472a3d706049722a3fe740bba23f70`.
The EXIT trap found no mounts below `/mnt/lfs`; NBD PID remained empty, 68 GiB
was free, the pinned rootfs `alp.py` hash was unchanged, and `db.json` stayed
empty. LFS reference: [Expat 2.7.1 instructions](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/expat.html).

**Release security scope:** this stage deliberately matches LFS 12.4's pinned
2.7.1 source; it is not a security update. The current LFS advisory identifies
Expat 2.7.5 or later as the remediation version. A release candidate must
resolve that update before it can be treated as current:
[LFS/BLFS consolidated advisories](https://linuxfromscratch.org/blfs/advisories/consolidated.html).

## Inetutils 2.6 staged comparison — 24 September 2026

Inetutils 2.6 was built in the Builder `/mnt/lfs` chroot from the LFS source
archive with MD5 `401d7d07682a193960bcdecafd03de94` and SHA-256
`68bedbfeaf73f7d86be2a7d99bcfbd4093d829f52770893919ae174c0b2357ca`. The
LFS GCC compatibility `sed` fix was applied in the isolated build tree, then
configured with `--prefix=/usr --bindir=/usr/bin --localstatedir=/var
--disable-logger --disable-whois --disable-rcp --disable-rexec
--disable-rlogin --disable-rsh --disable-servers`. `make -j2` completed;
`make check` reported 9 PASS, 3 SKIP, 0 XFAIL, 0 FAIL, 0 ERROR. The skips
were `test-snprintf`, `ping-localhost.sh`, and `traceroute-localhost.sh`.
Stage-only `ftp --version` reported GNU inetutils 2.6.

Installation went only to `/mnt/lfs/tmp/alp-m04-inetutils-stage-r1`. The
manifest has 30 entries (8 directories, 22 files), SHA-256
`5c816b024e46c38129f0f53e03ede89f153e281cce1e8260ca4d466e244dfcdb`;
[manifest](manifests/lfs-base/inetutils-2.6-2026-09-24.json). Read-only
preflight reported 16 exact matches and 14 mismatches; [full report](manifests/lfs-base/inetutils-2.6-2026-09-24-preflight.log),
SHA-256 `f5813f405e7b1f14d37a9b6291350d703d13099f73ba3762f4959e4d250b9970`.
The mismatches include changed existing networking binaries, `/usr/bin/telnet`
and its man page missing from rootfs, plus `/usr/libexec`, `/usr/share/info`,
and generated info index differences. No staged file was merged and no
ownership record was added.

Builder log `/mnt/lfs/tmp/alp-logs/m04-inetutils-2.6-stage-20260924-r1.log`
SHA-256 `935176fa1c910df0e0cf8780cd3dd7683080ee978bb08ef9e423dfd50e85da12`.
EXIT cleanup found no mounts below `/mnt/lfs`; NBD PID remained empty, 68 GiB
was free, the pinned rootfs `alp.py` hash was unchanged, and `db.json` stayed
empty. LFS reference: [Inetutils 2.6 instructions](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/inetutils.html).

## Less 679 staged comparison — 24 September 2026

Less 679 followed LFS 12.4-systemd instructions in the Builder `/mnt/lfs`
chroot. Source `/mnt/lfs/sources/less-679.tar.gz` matched LFS MD5
`0386dc14f6a081a94dfb4c2413864eed` and SHA-256
`9b68820c34fa8a0af6b0e01b74f0298bcdd40a0489c61649b47058908a153d78`.
Configuration was `./configure --prefix=/usr --sysconfdir=/etc`; `make -j2`
and `make check` completed. The upstream suite ran 17 tests with 0 errors.
Installation went only to `/mnt/lfs/tmp/alp-m04-less-stage-r1`; staged
`less --version` reported `less 679 (POSIX regular expressions)`, and `less`,
`lesskey`, and `lessecho` were present in the stage.

The manifest has 11 entries (5 directories, 6 files), SHA-256
`5adb1eee6e78ee164dc770f2d29f38d518575d69eb03146c2f26cda29dedaded`;
[manifest](manifests/lfs-base/less-679-2026-09-24.json). Read-only preflight
reported 8 exact matches and 3 mismatches, all three executable binaries;
[full report](manifests/lfs-base/less-679-2026-09-24-preflight.log), SHA-256
`46661c55c488dd37ceb3983ee75fa3cae3df1d4dd6d5ce156e80e5aba2a41029`.
No staged file was merged and no ownership record was added.

Builder log `/mnt/lfs/tmp/alp-logs/m04-less-679-stage-20260924-r1.log`
SHA-256 `a36e0860dfb917e1523be3e67e7ea36778f9906fa5a6964e0db9ce9990e0bfd3`.
EXIT cleanup found no mounts below `/mnt/lfs`; NBD PID remained empty, 68 GiB
was free, the pinned rootfs `alp.py` hash was unchanged, and `db.json` stayed
empty. LFS reference: [Less 679 instructions](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/less.html).

Official LFS 12.4-systemd procedures:
[Gzip-1.14](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/gzip.html),
[Zstd-1.5.7](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/zstd.html),
[Xz-5.8.1](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/xz.html).
The patched shared-library Bzip2 procedure follows
[Bzip2-1.0.8](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/bzip2.html)
and the [LFS patch checksum list](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter03/patches.html).
