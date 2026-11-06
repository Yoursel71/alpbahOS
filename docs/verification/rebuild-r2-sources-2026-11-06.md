# REBUILD-R2 source set (MLFS 13.1), 2026-11-06

Status: **Download PASSED (2026-11-06, run 16:02).** `scripts/rebuild/fetch-sources.sh` fetched all 96 sources
and `md5sum -c` reports 96 OK. Results below.

## Source set

| Item | Value |
|---|---|
| Book | Multilib LFS 13.1, systemd edition: https://linuxfromscratch.org/mlfs/view/13.1/ |
| Package list | https://linuxfromscratch.org/mlfs/view/13.1/wget-list-systemd |
| Checksums | https://linuxfromscratch.org/mlfs/view/13.1/md5sums |
| Patches page | https://linuxfromscratch.org/mlfs/view/13.1/chapter03/patches.html (9 patches, all also in the wget list) |
| Mirror used as fallback | https://ftp.osuosl.org/pub/lfs/lfs-packages/13.1/ (from https://www.linuxfromscratch.org/lfs/mirrors.html) |
| Entries in `wget-list-systemd` | 96 (87 packages and documentation archives + 9 patches) |
| Entries in `md5sums` | 96 |
| Basenames vs md5sums file names | identical (96 of 96) |
| sha256 of `wget-list-systemd` (fetched 2026-11-06) | b7ca1a5619c616b4007ae74e59ec2b483427053c4153a810df5e100d06c3c858 |
| sha256 of `md5sums` (fetched 2026-11-06) | ac9416b4aa8e6150abb374d473e1d103f55eeb10d0c363751e8ff4184c17d8b6 |

The fetch script stores the lists it used under
`/home/yrslf/alpbahOS/scratch-lfs-bench/lfs13-logs/fetch/` and prints their sha256.

## How verified (before download)

- Reachability of all 96 book URLs with a HEAD request (`curl -sIL`, User-Agent `alpbahOS-build`): 95 returned 200. One (`download.savannah.gnu.org/releases/attr/attr-2.6.0.tar.gz`) redirects to a mirror (`fosszone.csd.auth.gr`); a ranged GET on the redirect returned 206.
- Mirror comparison (`ftp.osuosl.org/pub/lfs/lfs-packages/13.1/md5sums` vs the book `md5sums`): 3 differences.
  - `isl-0.28.tar.xz` is in the book md5sums but not in the mirror md5sums.
  - `openrc-0.63.3-lock-1.patch` is in the book md5sums but not in the mirror md5sums.
  - `glibc-2.44-upstream_fixes-1.patch` (book, md5 990574184b25aa3029a2444e81865098) is named `glibc-2.44-upstream_fix-1.patch` on the mirror (md5 5d589fb5bf76f3efaa19dcd12d4484a4). A mirror copy is accepted only if it matches the book md5, so this file can only come from the book URL.
- Scripts checked with `bash -n`. `version-check.sh` was run on the build host (see the Host check section).

## Acceptance

| Check | Result |
|---|---|
| `fetch-sources.sh` run | Done 2026-11-06 16:02 to 16:19. Exit 0, `RESULT: PASS` |
| Files fetched or present with book md5 | 96 of 96 (0 failed). Sources from the book URLs or the mirror fallback; the mirror copy is accepted only when it matches the book md5 |
| `md5sum -c md5sums` in `/mnt/lfs13/sources` | 96 OK, rc 0 |
| Manifest written | `docs/verification/rebuild-r2-sources-manifest.tsv`: header plus 96 rows |
| Logs | `/home/yrslf/alpbahOS/scratch-lfs-bench/lfs13-logs/fetch/fetch-20261106-160207.log` (fetch and summary), `.../fetch/md5sum-check-20261106-160207.txt` (md5 check), `.../fetch/md5sums` and `.../fetch/wget-list-systemd` (lists used). Logs are outside the repo |
| Download size on disk | `/mnt/lfs13/sources` 630 MiB |

Fetch counts from the log: 95 files taken from a non-mirror URL and 1 from the osuosl mirror (fallback). The download also printed some retried timeouts; all were recovered.

## Host check (`version-check.sh`, run 2026-11-06)

Result: 30 PASS, 2 FAIL, 1 WARN.

- FAIL: `/usr/bin/yacc` is byacc (`yacc - 2.0 20241231`), not Bison. The book needs `yacc` to link to Bison.
- FAIL: `gcc -m32` fails because `glibc-devel.i686` is not installed on the host. Multilib needs 32-bit glibc and libgcc. Not installed in this step (no sudo).
- WARN: GCC 16.2.1 is newer than the book's tested 16.2.0.

## Manifest

`docs/verification/rebuild-r2-sources-manifest.tsv` holds only the header line (`file	md5	url`).
The fetch script writes the 96 rows to the path it is given.
