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
- Nine `install_manifest.txt` files exist under `/mnt/lfs/sources`: CMake, QtBase, QtPositioning, QtTools, QtSpeech, QtLocation, QtSvg, QtMultimedia, and QCoro. They belong to later BLFS/desktop builds and do not establish ownership for the LFS base packages.
- The regular filesystem owner (`root:root`, etc.) is not package ownership. It cannot be used to reconstruct which package installed a path.

## M04 status and next record method

Do not backfill the LFS base package database from current file owners or guess from package names. For future package installs, capture each package's staged install tree or a complete install manifest before merging into `/mnt/lfs`; record package/version/source checksum, relative path, file type, mode, uid/gid, symlink target, and SHA-256 for regular files. Existing base packages can be attributed only when a preserved install manifest/log proves the exact path set; otherwise rebuild/reinstall them through the capture path before claiming M04 ownership coverage.

M04's ownership-record exit condition remains open. This assessment is diagnostic evidence, not a package ownership manifest.

## Staged-install capture utility

Added `scripts/capture-package-manifest.py` to serialize a completed staging tree as a standalone JSON sidecar. It records package/version/source URL and checksum, every relative path, entry type, mode, uid/gid, symlink target, and SHA-256 plus size for regular files. It rejects an empty staging tree, an invalid source checksum, output paths inside the stage, and files that change while being hashed. The tool does not alter `/mnt/lfs` or the `alp` database.

Validation: ran the script on a temporary fixture containing `/usr/bin/fixture` plus its two parent directories. It emitted 3 entries (2 directories, 1 regular file); assertions verified package identity, path, mode/uid/gid types, size, and the fixture file's SHA-256. The temporary fixture and output were removed automatically. This validates the capture format only; it creates no LFS base package ownership records and does not close M04.

Next use: for each package that is rebuilt/reinstalled in Builder `/mnt/lfs` chroot, direct its install step to a package-specific staging tree, verify that tree is complete, then run the capture tool with the verified source archive checksum. Preserve the resulting sidecar and reconcile its path set with the package's `alp` record before claiming package ownership. Existing base packages still require proven historical manifests or a controlled reinstall through this path.
