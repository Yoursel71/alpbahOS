# 031: REBUILD-R4 start and REBUILD-R3-TEMP-01 (2026-11-07)

Read first: `docs/verification/rebuild-r3-2026-11-07.md` (section 3 claims the perl files are stale; this
is now disputed), `docs/verification/rebuild-r3-temp01-2026-11-07.md`, `docs/verification/rebuild-r4-2026-11-07.md`.

## State

- **REBUILD-R3-TEMP-01: Blocked.** The proof failed: perl loads 756 of the 762 listed `.pm` modules from
  the listed paths (the smoke test loads `Data/Dumper.pm` from there). Nothing removed. Snapshot of
  `r3-root` taken first: `scratch-lfs-bench/lfs13-snapshots/pre-temp01-2026-11-07`.
- **REBUILD-R4: Partial.** `scripts/rebuild/r4/packages.tsv` (344 rows). `r4-root` (writable snapshot of
  `r3-root`). Packages 001-005 built and recorded through alp (`alp check` rc 0, 103 packages, ownership
  check 63789 owned, 0 unowned). 006 curl-8.15.0 fails: the base has OpenSSL 4.0.1, the test image used
  OpenSSL 3.5.2. The driver is stopped (`r4-ledger/FAILED`), not running.

## Decisions needed (in this order)

1. TEMP-01: reclassify the 1596 files as base perl modules, or rebuild ch8 perl and re-check the install.
2. R4 OpenSSL: rebuild OpenSSL 3.5.2 in `r4-root`, or move curl to a version that builds on OpenSSL 4.

## Method notes that matter

- R4 uses the R3 snapshot-diff method with `alp adopt-base` for every package. Records are `lfs-base` and
  protected. The BLFS scripts have no DESTDIR.
- Builds run with `LANG=C LC_ALL=C`: the base locale is tr_TR.UTF-8, and sed ranges break under it.
- The chroot needs `/run/systemd/resolve` bind-mounted for network steps (make-ca -g).
- `usr/share/info/dir` and `etc/ld.so.cache` are excluded from manifests (base-owned hook files).
- 063 libndp has an http URL; alp requires https. Open.

## To resume

`sudo R4_FIRST=001 R4_LAST=030 nohup setsid bash /home/yrslf/alpbahOS/wt-t2-kisayol/scripts/rebuild/r4/run-r4.sh`
(after the OpenSSL decision). The driver skips packages with an OK line in `scratch-lfs-bench/r4-status.txt`.
Delete `r4-ledger/FAILED` before the next run if it still exists (the driver removes it at start).
