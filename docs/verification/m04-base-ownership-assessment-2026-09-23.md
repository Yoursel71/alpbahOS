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
