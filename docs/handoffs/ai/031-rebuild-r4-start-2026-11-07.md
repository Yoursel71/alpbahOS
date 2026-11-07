# 031: REBUILD-R4 start (BLFS 13.1), REBUILD-R3-TEMP-01 reclassified (2026-11-07)

Read first: `docs/verification/rebuild-r3-temp01-2026-11-07.md`, `docs/verification/rebuild-r4-2026-11-07.md`.

## State

- **REBUILD-R3-TEMP-01: Done (reclassified).** The 1596 "stale" perl files are perl 5.44.0 core modules
  that the ch8 install did not rewrite (installperl skips identical files, `installperl:708`). A fresh
  perl build with the ch8 flags matches all 1596 byte for byte. They are now in the `perl` record; the
  stale record is dropped. Nothing on disk was removed. The R3 note carries a correction.
- **alp in r3-root and r4-root:** the repo `alp.py` is in place (sha256 `f2a8f31d...`). alp's own upgrade
  refuses lfs-base records, so the file was copied and the change recorded (`alp-upgrade-record.py`).
  The alp tests pass (264).
- **REBUILD-R4: Partial.** BLFS 13.1 list (`packages.tsv`, 344 rows). Built and recorded: 78 packages
  (001-122 in order, except the skips and 064). **Stopped at 123 llvm-project-22.1.8** (FAIL). Driver not
  running; `r4-ledger/FAILED` is present. Status: `scratch-lfs-bench/r4-status.txt`.

## To resume

1. LLVM 22.1.8: write its 13.1 build block (the LLVM page's commands) as a delta, then run 123-127 and Mesa 128.
2. Xorg 7.x (074-110 and later): the book's Xorg MD5 lists are needed.
3. After 047 glib: rebuild 040 libical with glib on.
4. After 183 gnutls: remove `scripts/rebuild/r4/deltas/064.defer` and run 064 alone.

Run: `sudo R4_FIRST=123 R4_LAST=344 setsid nohup bash scripts/rebuild/r4/run-r4.sh` (the driver resumes past
OK lines; delete `scratch-lfs-bench/r4-ledger/FAILED` only if it blocks the start, the driver removes it).

## Method notes that matter

- Deltas per package live in `scripts/rebuild/r4/deltas/` (`.pre.sh`, `.files`, `.subst`, `.name`, `.defer`).
- Records are `lfs-base` and protected (no DESTDIR yet). Ownership moves are logged in `r4-ledger/transfers/moves.tsv`.
- Build locale C; resolver dir bound in the chroot; hook files (`usr/share/info/dir`, `etc/ld.so.cache`,
  `etc/xml/catalog`) are excluded from manifests.
