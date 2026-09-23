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
