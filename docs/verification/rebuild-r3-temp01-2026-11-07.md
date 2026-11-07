# REBUILD-R3-TEMP-01: removal of the stale chapter 7 perl files (2026-11-07)

Status: **Blocked. Nothing was removed.** The proof required by the task failed: perl in the R3 base
loads 756 of the 762 `.pm` modules in the list from the listed paths, so removing the list would remove
modules the base uses. The R3 note (section 3) called these files "stale"; this check contradicts that.

## 1. Snapshot

Read-only btrfs snapshot taken before any change to `r3-root`:
`scratch-lfs-bench/lfs13-snapshots/pre-temp01-2026-11-07` (parent UUID of `r3-root`:
`392e5b4b-1a38-764f-a734-ee9707e3060c`). `r3-root` is a btrfs subvolume; the snapshot is a separate
subvolume and costs no copy.

## 2. The record and the list

- `alpbahos-temptools-stale` in `r3-root/var/lib/alp/db.json`: 1596 files, `protected: true`,
  `method: lfs-base`. Its file list equals `scripts/rebuild/r3/temptools-stale.txt` exactly
  (1596 in both, 0 only in the record, 0 only in the list).
- `alp remove` refuses `lfs-base` records (`remove_package`: "LFS taban paketi; doğrudan kaldırılması
  kapalı"), so the alp route would need a database edit. It was not reached because the proof failed.

## 3. Proof that nothing uses the files (failed)

Method: `scripts/rebuild/r3/temp01-proof.sh` mounts `/dev`, `/proc`, `/sys` under `r3-root` for the run
and unmounts them. It runs `scripts/rebuild/r3/temp01-check.pl` in the chroot. The script requires every
stale `.pm` module by name and prints the file perl resolves it to (`%INC`). Output:
`scratch-lfs-bench/r3-ledger/temp01/perl-pre.txt`; tool checks: `tools-pre.txt`.

Results before removal:

- perl 5.44.0, `@INC`: `/usr/lib/perl5/5.44/site_perl`, `.../vendor_perl`, `.../core_perl`.
- Smoke test `use strict; use warnings; use Config; use File::Spec; use Data::Dumper; print "ok"`:
  `smoke: ok`. `Data/Dumper.pm` is one of the listed files and perl loaded it from there.
- `pm_modules=762 resolved_to_stale=756 failed=6`. The six that do not load standalone are
  `File::Spec::VMS`, `Pod::Perldoc::ToTk`, `Test2::AsyncSubtest::Formatter`, `if`, `open`, `sort`
  (their load errors were not examined).
- Examples of resolution to a listed path: `Archive::Tar` ->
  `/usr/lib/perl5/5.44/core_perl/Archive/Tar.pm`, `AnyDBM_File` -> `.../core_perl/AnyDBM_File.pm`.
- Non-`.pm` files in the list: 834.
- Other perl users: `autoreconf --version` -> `autoconf 2.73`, rc 0; `help2man` is absent from the base;
  `openssl version` -> `OpenSSL 4.0.1 9 Jun 2026`, rc 0.

Why this matters for the R3 note: the list was recorded as "not in ch8 perl's set". The files have ch7
change times (6 Nov 17:55) and are byte-identical to `/mnt/lfs13` copies, but perl still loads them. The
ch8 perl install log (`lfs13-logs/ch8/45-perl.log`) does not show these modules being installed. The cause
(an install that skips unchanged files, or a module set that differs) was **not established**. Removing
the files without that answer would break `use Data::Dumper`, `Archive::Tar` and about 750 more modules.

## 4. What was not done

- No file was removed, no directory was removed, and the alp record was not touched.
- The post-removal perl check, `alp check` after removal, and the ownership check after removal were not
  run, since there was no removal.
- The alp in the R3 root (`/usr/lib/alp/alp.py`) is older than the repo copy
  (`docs/handoffs/claude/alp-prototype/alp.py`): the repo copy accepts backslashes in manifest paths and
  the installed copy does not. The R4 driver uses the repo copy. The image's `alp` is not changed here.

## 5. Decision needed

One of:

1. Reclassify the 1596 files as base perl modules (a new base record or an adoption of the perl core
   set), and close REBUILD-R3-TEMP-01 as "no stale files": the list is then wrong and must be corrected.
2. Rebuild ch8 perl so that its install writes every core module (check the install log for skipped
   files first), then repeat this proof and remove the files that are no longer loaded.

The coordinator chooses. Until then TEMP-01 stays Blocked.
