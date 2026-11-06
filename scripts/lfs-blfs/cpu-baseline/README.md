# CPU baseline rebuild: libffi, GMP, MPFR

Status (2026-11-06): **the three rebuilds ran and passed in the chroot**, and the audit is clean
for all four libraries. Results are in the section "Run results (2026-11-06)" below and in
[docs/verification/sigill-cpu-baseline-2026-11-06.md](../../../docs/verification/sigill-cpu-baseline-2026-11-06.md)
(section "Result (2026-11-06)").

## Why

The SIGILL on CPU models without AVX (`kwin_wayland`, `wireplumber`) comes from libffi 3.5.2,
built with `--with-gcc-arch=native` on a Zen 3 host. GMP 6.3.0 and MPFR 4.2.2 were built with
`-march=znver3` from the host CPU name. Details and evidence:
[docs/verification/sigill-cpu-baseline-2026-11-06.md](../../../docs/verification/sigill-cpu-baseline-2026-11-06.md)
(sections 5.1, 5.2 and 6.1).

These scripts rebuild the three packages with the LFS 12.4-systemd book options, changing only the
CPU flags to generic x86-64. They run inside the LFS chroot (`/mnt/lfs`) as root.

## Files

| File | Runs where | What it does |
|---|---|---|
| `rebuild-libffi.sh` | chroot | libffi 3.5.2, `--with-gcc-arch=x86-64`, `make check` must have 0 unexpected failures |
| `rebuild-gmp.sh` | chroot | GMP 6.3.0, `--build=x86_64-pc-linux-gnu --enable-fat`, generic CFLAGS/CXXFLAGS, `make check` needs >= 199 PASS and 0 FAIL/XPASS/ERROR |
| `rebuild-mpfr.sh` | chroot | MPFR 4.2.2, generic CFLAGS, `make check` needs >= 198 PASS and 0 FAIL/XPASS/ERROR; refuses to run unless the newest GMP rebuild was installed |
| `audit-isa.sh` | host (or chroot) | ISA audit (section 6.3 method): VEX, BMI/MOVBE and AVX-512 mask ops in non-variant functions |

Each rebuild script:

- checks it runs as root in an LFS system (`/etc/lfs-release`, or the LFS marker in `/etc/os-release`);
- checks the MD5 of its tarball in `/sources` (values from the LFS 12.4 md5sums list);
- extracts into a new directory `/sources/cpu-baseline-build/<pkg>-<ver>-<timestamp>` (never reuses a tree);
- saves the currently installed files to `/sources/cpu-baseline-build/<pkg>-installed-before-<timestamp>/`
  before `make install`, so the old library can be restored by copying the files back;
- writes the test log to `/sources/cpu-baseline-build/<pkg>-check.log`.

## Book options and deviations

| Package | Book options (LFS 12.4-systemd) | This rebuild |
|---|---|---|
| libffi 3.5.2 | `--prefix=/usr --disable-static --with-gcc-arch=native` | same, `--with-gcc-arch=x86-64`. libffi's configure still adds `-ffast-math` (book behaviour, unchanged here) |
| GMP 6.3.0 | `--prefix=/usr --enable-cxx --disable-static --docdir=/usr/share/doc/gmp-6.3.0`, gcc-15 `sed` on `configure` | same, plus `--build=x86_64-pc-linux-gnu --enable-fat`, `CFLAGS` and `CXXFLAGS` = `-O2 -march=x86-64 -mtune=generic`. `make html` and `make install-html` skipped |
| MPFR 4.2.2 | `--prefix=/usr --disable-static --enable-thread-safe --docdir=/usr/share/doc/mpfr-4.2.2` | same, `CFLAGS` = `-O2 -march=x86-64 -mtune=generic`. `make html` and `make install-html` skipped |

Why the extra GMP options:

- `--build` stops `config.guess` from reporting the host CPU name (`zen3`). Without it, GMP picks
  `-march=znver3` by itself, as the original `ch8.19.log` shows.
- `CXXFLAGS` is set too, because GMP derives the C++ flags the same way.
- `--enable-fat` keeps runtime CPU selection for the assembly routines, so GMP stays fast on
  CPUs with newer instruction sets. The routines that use them are "variant" functions in the audit.
- The book's own caution applies: `--host=none-linux-gnu` is the other generic option. This
  rebuild uses `--build` plus `--enable-fat`, as decided for this task.

Why MPFR uses the same `CFLAGS` string as GMP: MPFR's configure reads the GMP compile flags from
`gmp.h` and compares them. Identical flags avoid a mismatch.

Docs (`make html`) are skipped in GMP and MPFR. The ISA fix does not depend on them. Docs can be
added later with `make html` and `make install-html` if needed.

## Order

1. `rebuild-libffi.sh` (independent)
2. `rebuild-gmp.sh`
3. `rebuild-mpfr.sh` (after GMP: the script refuses to run otherwise)

libffi does not depend on GMP or MPFR. GMP must be installed before MPFR.

## Supervisor commands

Run on the host, from the repo root. Needs root (`sudo`). The LFS bind mounts must already be up
(`scripts/lfs-blfs/mount_lfs.sh`). The log directory must exist before the redirect, because the
redirect is opened by the host shell, not by the chroot.

```bash
# 1. Copy the scripts into the chroot and create the log folder (host side)
sudo mkdir -p /mnt/lfs/sources/cpu-baseline /mnt/lfs/sources/cpu-baseline-build
sudo cp scripts/lfs-blfs/cpu-baseline/rebuild-*.sh /mnt/lfs/sources/cpu-baseline/

# 2. Run in order (each one in the foreground; the logs are the redirect targets)
sudo chroot /mnt/lfs /usr/bin/env -i HOME=/root TERM=xterm PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j16 /bin/bash /sources/cpu-baseline/rebuild-libffi.sh > /mnt/lfs/sources/cpu-baseline-build/libffi.log 2>&1
sudo chroot /mnt/lfs /usr/bin/env -i HOME=/root TERM=xterm PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j16 /bin/bash /sources/cpu-baseline/rebuild-gmp.sh > /mnt/lfs/sources/cpu-baseline-build/gmp.log 2>&1
sudo chroot /mnt/lfs /usr/bin/env -i HOME=/root TERM=xterm PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j16 /bin/bash /sources/cpu-baseline/rebuild-mpfr.sh > /mnt/lfs/sources/cpu-baseline-build/mpfr.log 2>&1
```

Check the exit status of each command. A script that stops (exit 1) must not be followed by the
next one. Read the log tail first.

Long runs: GMP and MPFR `make check` can take a long time. Run them in the background if needed
(D105). Summaries are read from the log files afterwards.

## Post-check (host, read-only)

After all three installs, run the audit on the installed libraries under the rootfs. The audit only
reads files.

```bash
scripts/lfs-blfs/cpu-baseline/audit-isa.sh /mnt/lfs/usr/lib/libffi.so.8* /mnt/lfs/usr/lib/libgmp.so.10* /mnt/lfs/usr/lib/libmpfr.so.6*
```

Add `/mnt/lfs/usr/lib/libgmpxx.so.4*` to the list if it exists (GMP C++ library, built with
`--enable-cxx`).

- Exit 0: no non-variant AVX/BMI/AVX-512 code in these libraries.
- Exit 1: the output lists `NONVARIANT <function> <address> <mnemonic>`. Do not accept the build.
  Fix the flags and rebuild that package.
- For a review without failing: add `--report-only`.

Audit result on the old rootfs (before the rebuild), 2026-11-06, for reference: libffi 245
nonvariant hits, GMP 1339, MPFR 1439 (`shlx`, `andn`, `vmovd` and others in non-variant functions).
This confirms the audit catches the problem. The rebuilt libraries are in the run results below.

The audit's "variant" rule: a hit inside a function whose name has an ISA marker (`avx`,
`sse4`, `fat`, `zen`, `haswell`, `skx`, ...) is counted as variant and does not fail. Such code is
selected at run time. GMP's fat routines are `__gmpn_*` symbols ending in a CPU directory name of
GMP 6.3.0 (`mpn/x86_64/`: `coreibwl`, `coreihwl`, `zen`, `bt2`, `k10`, ...). Only those `__gmpn_`
names with those suffixes are whitelisted. A new GMP version needs its directory list checked
again. If fat-variant code shows up as nonvariant, add a name to the audit pattern on purpose, not
by hand in the log.

Dynamic test (section 6.3 gate, not part of these scripts): run the library's init path under
`qemu-x86_64 -cpu qemu64,-sse3,-cx16` and check for `uncaught target signal 4`. Not yet run.

## Rule for the 13.1 rebuild

Taken from section 6.2 of the SIGILL report:

1. `CFLAGS="-O2 -march=x86-64 -mtune=generic"`, `CXXFLAGS` and `FFLAGS`/`FCFLAGS` the same, set by
   the build driver for every package. The global variable alone does not stop packages that
   detect the host CPU, so these three packages keep their explicit options above.
2. libffi (`--with-gcc-arch=x86-64`), GMP and any GMP-family package (`--build=x86_64-pc-linux-gnu`)
   use their explicit options. Any other package that adds its own `-march` (for example FFTW,
   OpenBLAS, x264) must be checked when added.
3. Run `audit-isa.sh` on every package's installed files after every build. No package goes into
   the 13.1 base until the audit passes (exit 0) and the v1-strict run of section 4 has no SIGILL.
4. SIMD stays in runtime dispatch (OpenSSL, libgcrypt, OpenCV, glibc ifunc) instead of building a
   whole library with AVX.

Open items from the report that these scripts do not cover: OpenCV SSE2 baseline (section 6.1),
Mesa `libgallium` AVX source (section 5.3).

## Run results (2026-11-06)

Run by the supervisor in the chroot, with the commands above. Evidence (log tails):
`docs/verification/cpu-baseline-rebuild-logs/`. Full logs are in the rootfs at
`/mnt/lfs/sources/cpu-baseline-build/`.

| Script | Exit | Test result | Installed |
|---|---|---|---|
| `rebuild-libffi.sh` | 0 | `make check`: 2460 expected passes, 0 unexpected failures | `libffi.so.8.2.0`, SHA-256 `28b70739fe951ae35957ec47d01c321eda02a9281ca99dda942ceb66f6c40947` |
| `rebuild-gmp.sh` | 0 | 199 PASS (book minimum 199), 0 FAIL/XPASS/ERROR | `libgmp.so.10.5.0`, `libgmpxx.so.4.7.0` |
| `rebuild-mpfr.sh` | 0 | TOTAL 198, PASS 198, 0 FAIL/XPASS/ERROR | `libmpfr.so.6.2.2`, SHA-256 `04a282fba381a1ccf75a0b940c1738ebe0391424bcce8b44eed7b65d545b8f4e` |

Post-check, `audit-isa.sh` (nonvariant hits, before the GMP fat-variant rule / after):

| Library | Before | After | ISA used |
|---|---|---|---|
| `libffi.so.8.2.0` | 0 | 0 | x86-64-baseline |
| `libgmp.so.10.5.0` | 474 | 0 (706 variant hits, all `__gmpn_*` fat variants) | x86-64-baseline |
| `libmpfr.so.6.2.2` | 0 | 0 | x86-64-baseline |
| `libgmpxx.so.4.7.0` | 0 | 0 | x86-64-baseline |

Boot check: ISO v3 with the default `qemu64` model. Serial log
`docs/verification/m09-iso-v3-bios-qemu64-serial-2026-11-06.log` has no trap, SIGILL or FAILED
lines (it covers boot to the login prompt only). Screenshot
`docs/verification/m09-iso-v3-bios-qemu64-screen-2026-11-06.png` shows the Plasma desktop. The
supervisor reports 0 SIGILL and 0 abnormal ends in the session; the session journal is not in the
repo.

## Open items (not done by these scripts)

- OpenCV 4.12.0: SSE3 baseline (`-DCPU_BASELINE=SSE2` proposed, not built).
- Mesa 25.1.8: AVX markers in `libgallium` and `pipe_swrast.so`; source not traced.
- `libcrypto.so.3`, `libgcrypt.so.20.6.0`, `libLLVM.so.20.1`: non-variant AVX/BMI, not re-audited
  here, not classified as culprits.
- `libgnutls.so.30.40.4` (v3 ISA marker) and `libnettle.so.8.11` (v2): not audited here.
- Full v1-strict run (`qemu64,-sse3,-cx16`, section 4.1 test) and Nehalem/Haswell boots: not run.
  A qemu64 Plasma session without SIGILL does not prove these paths are fixed.

## Not verified yet

- The GMP `--enable-fat` build may put variant flags for the fat routines into `config.log`. The
  `znver3` gate passed in the run above (it looks for `znver3` only).
- The ISO boot evidence is a screenshot plus a boot-only serial log. The session journal was not
  captured.
