# REBUILD-R3-TEMP-01: the stale perl files are base perl modules (reclassified, 2026-11-07)

Status: **Done (reclassified, not deleted).** The files are not stale. They are perl 5.44.0 core modules
that the chapter 8 install did not rewrite, because the content was already identical. The 1596 files
are now in the `perl` record and the `alpbahos-temptools-stale` record is dropped. Nothing on disk was
removed. This corrects the R3 note (section 3), which called them "stale chapter 7 temporary perl files".

## 1. Why the chapter 8 install did not rewrite them

`installperl` writes each library file only when it differs (`scripts/rebuild/ch8/45-perl.sh` runs
`make install`, which runs `installperl` without `--force`). Source: perl-5.44.0 (`r3-root/sources/perl-5.44.0.tar.xz`),
read in `scratch-lfs-bench/temp01-perl/perl-5.44.0/`:

- `installperl:708`: `if ($opts{force} || compare($from, $to) || $opts{notify}) { ... copy ... }`.
  `File::Compare::compare` returns 0 for identical files, so an identical file is not copied.
- `cpan/ExtUtils-Install/lib/ExtUtils/Install.pm:755`: `my $diff = $always_copy || _compare(...)`,
  and `:809-810`: `$result->{install_unchanged}{$targetfile} = $sourcefile;` /
  `print "Skipping $targetfile (unchanged)\n" if $verbose;`. `_compare` is at `:135-142`.

So an identical chapter 7 file stays on disk with its chapter 7 change time. The R3 ledger assigned it
to chapter 7 (`ch05-07-temptools-stale`) because it was the last writer by ctime. The ch8 install log
(`lfs13-logs/ch8/45-perl.log`) contains no "unchanged" lines because the build ran without verbose output.

## 2. Check against a fresh install

`scratch-lfs-bench/temp01-perl/build.sh` built perl 5.44.0 from the same tarball with the flags of
`scripts/rebuild/ch8/45-perl.sh` (on the host, not in the chroot; `Configure` log `configure.log`, build
`make.log`, `make install DESTDIR=.../inst`, rc 0). Each of the 1596 listed files was compared with the
same path in that DESTDIR install (`cmp`):

- **same: 1596, different: 0, missing in the fresh install: 0.**

The comparison covers only the listed files. Files that differ between a host build and the chroot
build (Config_heavy.pl and similar) are not in the list, so they are not affected.

## 3. Action (`scripts/rebuild/r3/temp01-reclassify.py`)

Run as root against `r3-root`, under alp's own database lock and `save_db`:

- check: the stale record's file list equals `temptools-stale.txt`; each file byte-matches the fresh install;
- moved: 1596 files into the `perl` record (`perl` 1285 -> 2881 files); a `reclassified` entry records
  the method and the date;
- dropped: the `alpbahos-temptools-stale` record. Unmatched files: 0 (they would have gone to a kept record
  `alpbahos-temptools-unmatched`);
- report: `scratch-lfs-bench/r3-ledger/temp01/reclassify.json`.

Snapshot before the change: `scratch-lfs-bench/lfs13-snapshots/pre-temp01-reclass-2026-11-07` (read-only).

## 4. Checks after the change (r3-root)

- `alp check` (repo `alp.py`, `--index demo/index.json`): rc 0, "sorun yok (97 kurulu paket)".
- Ownership check (`scripts/rebuild/r3/ownership-check.sh`, owned list from the database): files scanned
  62927, owned 62927, **unowned 0, conflicts 0**. (Same totals as before: the list only moved owner.)
- Perl proof (`temp01-proof.sh`, post phase): `smoke: ok`, `pm_modules=762 resolved_to_stale=756 failed=6`
  (the same counts as before the change; "stale" in that output is the name of the check, the paths are
  the perl-owned files now), `perl rc=0`. `autoreconf (GNU Autoconf) 2.73` rc 0; `help2man` absent;
  `OpenSSL 4.0.1` rc 0.

## 5. The alp upgrade in r3-root (same change set)

The installed `/usr/lib/alp/alp.py` was older than the repo copy (it refused backslashes in manifest paths).
alp's own `upgrade` refuses `lfs-base` records ("LFS taban paketi; alp ile yükseltilmesi kapalı"), and the
`alp` package is one. So the file was copied (as the R3 zz-alp step did) and the change was recorded with
`scripts/rebuild/r3/alp-upgrade-record.py`: the record's `upgrades` list gets the previous and new sha256
and the repo source. The file list is unchanged.

- previous sha256 `e24671e238a6043cbce13ec10f09ab50754b709a02abfbde1de3abc6619d24e8`;
- new sha256 `f2a8f31dcf3fd55b1512c400c4ba06c8ba541be6411e61695d73475d69caecac` (equal to the repo file);
- alp test suite (`docs/handoffs/claude/alp-prototype/tests`): 264 passed;
- `alp check` after the upgrade: rc 0, 97 packages.

## 6. Open

- The `perl` record's `ownership.manifest_sha256` still names the chapter 8 manifest; the file list now
  holds 2881 entries. The record says so in `reclassified`. A new manifest for perl is not generated.
- The r3-root alp upgrade used copy plus record, not alp's own path (refused for lfs-base). Recorded here.
