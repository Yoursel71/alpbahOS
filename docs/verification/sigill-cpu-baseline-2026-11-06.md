# SIGILL on non-AVX CPU models: root cause and baseline fix (2026-11-06)

Test base: LFS 12.4 rootfs at `/mnt/lfs` (read only for this work), BLFS/KDE Plasma 6.4.4, built on a Ryzen 7 5700 (Zen 3) host.
Related: [m09-iso-v2-boot-2026-11-06.md](m09-iso-v2-boot-2026-11-06.md) (symptom boots).

## 1. Symptom

Live ISO booted in QEMU/SeaBIOS (M09):

| VM CPU model | Result |
|---|---|
| `qemu64` (default) | autologin Plasma session: `kwin_wayland` killed by SIGILL (audit `sig=4`), then drkonqi/plasmashell abort |
| `Nehalem` (x86-64-v2) | same, `kwin_wayland` SIGILL x7, `wireplumber` SIGILL x1 |

Logs: [m09-iso-v2-bios-serial-2026-11-06.log](m09-iso-v2-bios-serial-2026-11-06.log), [m09-iso-v2-bios-nehalem-serial-2026-11-06.log](m09-iso-v2-bios-nehalem-serial-2026-11-06.log).

## 2. Result in one paragraph

The SIGILL is caused by **libffi 3.5.2** (`/usr/lib/libffi.so.8.2.0`). Its `ffi_prep_cif` (offset `0x3420`) contains VEX (AVX) encoded instructions starting at `0x342c` (`vmovd %esi,%xmm0`). The libffi build used `-march=native`, which its configure chose by itself (autoconf `AX_GCC_ARCHFLAG`). On a Zen 3 build host that means AVX/AVX2/BMI-class code. Every process that calls `ffi_prep_cif` dies on a v1 or v2 CPU: `kwin_wayland` (through libwayland's `wl_closure_invoke`) and `wireplumber` (through GObject's `g_cclosure_marshal_generic`, via the Lua scripting module). The fault site is confirmed in five `kwin_wayland` cores and one `wireplumber` core, and the fault reproduces in a minimal user-mode test. Two more packages carry the same class of problem (GMP 6.3.0 and MPFR 4.2.2 built with `-march=znver3`), and OpenCV 4.12.0 needs an SSE3 baseline, which blocks a strict SSE2-only CPU. These are listed in section 5.

## 3. Method

1. **Reproduction under QEMU user mode.** `qemu-x86_64` 10.2.2 (host). The CPU models were checked with a cpuid probe compiled on the host (`cpuid.h`):

   | Label | `-cpu` value | Verified features |
   |---|---|---|
   | v1-strict | `qemu64,-sse3,-cx16` | no SSE3, SSSE3, SSE4, POPCNT, CX16, AVX (SSE2 only) |
   | v1-default | `qemu64` | SSE3 + CX16; no SSSE3, SSE4, POPCNT, AVX (the VM default) |
   | v2 | `Nehalem` | SSSE3, SSE4.1/4.2, POPCNT, CX16; no AVX |
   | v3 | `Haswell` | AVX, AVX2, FMA, F16C, BMI1/2 |

   Guest environment is passed with `qemu -E` only. Setting `LD_LIBRARY_PATH` on the qemu host process loads the rootfs glibc into qemu itself and produces fake "stack smashing" aborts (found and fixed during this work).
2. **Binary matrix**: `--version`/`--help`, plus a deeper run of `kwin_wayland --virtual --no-lockscreen` (v1-strict only, 60 s).
3. **Static scan**: all 4499 x86-64 ELF files under `/mnt/lfs/{bin,sbin,usr,opt,lib,lib64}` disassembled with `objdump -d`. VEX (AVX/AVX2/AVX-512), BMI/LZCNT/MOVBE, SSE3/SSSE3/SSE4/POPCNT and AES/PCLMUL/SHA mnemonics were counted per function. Functions with ISA-variant names (`avx`, `sse4`, `_skx`, ...) were counted separately, because they are runtime-dispatched.
4. **ISA notes**: `readelf -n` over all files (`x86 ISA needed` and `x86 ISA used`).
5. **Crash evidence**: kernel trap line in the M09 logs, and systemd-coredump cores copied to the scratch folder (decoded with `zstd -d`, read with host gdb and `set sysroot /mnt/lfs`).
6. **Build evidence**: `/home/yrslf/alpbahOS/scratch-lfs-bench/lfs-build-plan/logs/ch8.48.log` (libffi), `ch8.19.log` (GMP), `ch8.20.log` (MPFR), and the `/mnt/lfs/sources/libffi-3.5.2/Makefile` CFLAGS line.

Nothing was rebuilt. No sudo, chroot or mount was used. No file under `/mnt` was written.

## 4. Per-binary results (QEMU user mode)

Exit code and signal from `qemu-x86_64`. "0" means the command ran and exited normally.

| Binary, command | v1-strict | v1-default (`qemu64`) | v2 (`Nehalem`) | v3 (`Haswell`) | Notes |
|---|---|---|---|---|---|
| `kwin_wayland --version` | 0 | 0 | 0 | 0 | deep run v1-strict (`--virtual`, 60 s): no SIGILL, ran until timeout |
| `wireplumber --version` | 0 | 0 | 0 | 0 | session path needs a running pipewire, see note 4.3 |
| `pipewire --version` | 0 | 0 | 0 | 0 | daemon start fails on a missing module (not CPU, note 4.3) |
| `pipewire-pulse --version` | 0 | 0 | 0 | 0 | |
| `plasmashell --version` | SIGSEGV (KCrash) | SIGSEGV | SIGSEGV | SIGSEGV | no session/D-Bus, same on all models: not CPU |
| `kwin_x11 --version` | SIGABRT | SIGABRT | SIGABRT | SIGABRT | no X server, not CPU |
| `sddm --version` | SIGABRT | SIGABRT | SIGABRT | SIGABRT | not CPU |
| `spectacle --version` | **SIGABRT** (OpenCV baseline) | 0 | 0 | 0 | section 5.4 |
| `konsole`, `dolphin`, `kded6`, `Xwayland -version`, `kscreenlocker_greet`, `kglobalacceld`, `kate`, `okular`, `gwenview`, `ark`, `systemsettings`, `ffmpeg -version` | 0 | 0 | 0 | 0 | |
| `kinfocenter --version` | 127 | 127 | 127 | 127 | missing `libPlasmaActivities.so.7` in rootfs, not CPU |
| `kscreen-console --version` | 1 | 1 | 1 | 1 | no such option, not CPU |
| `xdg-desktop-portal-kde --version` | 1 | 1 | 1 | 1 | no such option, not CPU |
| `polkit-kde-authentication-agent-1 --version` | 1 | 1 | 1 | 1 | no output, not CPU |

Key point: `--version` runs do not execute the failing code path, so the matrix alone does not show the SIGILL. The SIGILL needs a `ffi_prep_cif` call (any GObject signal, any Wayland protocol dispatch).

### 4.1 Minimal reproduction (decisive)

Host program `dlopen`s the rootfs `libffi.so.8` and calls `ffi_prep_cif` once (source: `scratchpad/sigill/ffitest.c`):

| CPU model | Result |
|---|---|
| v1-strict | `qemu: uncaught target signal 4 (Illegal instruction)` |
| v1-default (`qemu64`) | same SIGILL |
| v2 (`Nehalem`) | same SIGILL |
| v3 (`Haswell`) | `ffi_prep_cif returned 0` |

### 4.2 Core dumps (VM)

Cores from the VM session (systemd-coredump, default `qemu64`):

| Core | Top frames |
|---|---|
| `kwin_wayland` (5 cores checked, cores 1, 2, 3, 4 and 6 of the copied set) | SIGILL at `ffi_prep_cif+0xc` (libffi offset `0x342c`), called from `wl_closure_invoke` (libwayland-server) via `wl_client_connection_data`; then KCrash handler (SIGILL is re-raised in the crash handler) |
| `wireplumber` (2 cores checked) | `x/i $pc` = `ffi_prep_cif+12` (`0x342c`), called from `g_cclosure_marshal_generic` (libgobject) <- `g_closure_invoke` <- `g_signal_emitv` <- `_wplua_gobject_call` (libwireplumber-module-lua-scripting) <- `liblua.so.5.4` |
| `plasmashell`, `kded6` | SIGABRT in `__GI_abort` after KCrash, not a SIGILL site |

### 4.3 Session-level limits of this test

- Full session (`pipewire` + `wireplumber` + `kwin` on a real GPU) was not reproduced in user mode. The pipewire daemon refuses to start because the rootfs `pipewire.conf` lists `libpipewire-module-raop-discover` as mandatory and the module is missing. This is a packaging issue, not CPU-related, and is not fixed here.
- Socket paths are limited to 107 bytes, so the runtime dir had to be the scratch folder itself.
- kwin's `--virtual` run in user mode does not initialise the GPU path, so the kwin SIGILL is only reproduced through the cores, not the matrix.

## 5. Culprits

### 5.1 libffi 3.5.2 (confirmed, SIGILL source)

| Item | Value |
|---|---|
| Library | `/usr/lib/libffi.so.8.2.0` (rootfs `/mnt/lfs/usr/lib/libffi.so.8.2.0`) |
| Function | `ffi_prep_cif` (symbol at `0x3420`) |
| Faulting instruction | `0x342c`: `vmovd %esi,%xmm0` (VEX-encoded, AVX). The same function also contains `vmovq`, `vpinsrd` and other VEX instructions |
| Package | libffi 3.5.2 (LFS chapter 8 build, log `scratch-lfs-bench/lfs-build-plan/logs/ch8.48.log`) |
| Cause | libffi's `configure` ran `checking for gcc architecture flag... -march=native` (autoconf `AX_GCC_ARCHFLAG`, used when `--with-gcc-arch` is not given). The Makefile then has `CFLAGS = -Wall -O3 -fomit-frame-pointer -fstrict-aliasing -ffast-math -march=native -fexceptions`. `-ffast-math` is also added by the same configure. |
| ISA marker | `readelf -n`: `x86 ISA used: x86-64-baseline, x86-64-v3` |

Consequence: any libffi user (GObject closures, libwayland, Lua bindings, etc.) crashes on a CPU without AVX. The trap in the VM log, `traps: wireplumber[...] trap invalid opcode ip:... in libffi.so.8.2.0[342c, ...]`, is the same offset.

### 5.2 GMP 6.3.0 and MPFR 4.2.2 (build-flag leak, not runtime-tested)

| Item | Value |
|---|---|
| Evidence | `ch8.19.log` (GMP): `checking build system type... zen3-pc-linux-gnu` and `CFLAGS="-O2 -pedantic -fomit-frame-pointer -m64 -mtune=znver3 -march=znver3"` |
| Scan | `libgmp.so.10.5.0`: 538 non-variant AVX and 803 BMI/ADX instructions (e.g. `__gmpn_sqr_basecase`); `libmpfr.so.6.2.2`: 997 AVX and 446 BMI (e.g. `mpfr_sub1sp`) |
| ISA marker | `x86 ISA used: x86-64-v3` on both |
| Cause | GMP's configure derives the CPU name from `config.guess` and selects `-march=znver3` on this Zen 3 host. MPFR's test compiles in `mpfr-4.2.2-2026-09-24-dependency-config.log` also carry `-mtune=znver3 -march=znver3`. |
| Runtime impact | not reproduced. These libraries are not called in the libffi/wireplumber path. They must be fixed before any v2 test that uses them (gnutls and nettle use GMP). |

### 5.3 libgallium / pipe_swrast, libLLVM, libgcrypt, libcrypto (ISA-used markers, not classified)

The scan found non-variant AVX/BMI instructions in these libraries, and their `ISA used` markers say v3 or v4: `libgallium-25.1.8.so` (`evaluate_fdot16`, `convert_half_float`), `pipe_swrast.so`, `libLLVM.so.20.1`, `libgcrypt.so.20.6.0` (`__serpent_enc_blk16`, AVX2 code), `libcrypto.so.3` (`ChaCha20_8x`, `poly1305_blocks_vpmadd52_4x`). Most are runtime-dispatched (OpenSSL, libgcrypt and Mesa select code paths at run time), so they are not confirmed culprits. Mesa's `evaluate_fdot16` is not in a dispatch-named function and has not been traced to a build flag. The Mesa build script (`scripts/lfs-blfs/build-cmds/packages/128-mesa-25.1.8.sh`) sets no `-march`, and the build logs contain no `-march=native` for mesa. **Open item**: find the Mesa source of AVX in `libgallium` (`meson` option or file-level `-mavx2`) before the 13.1 rebuild.

### 5.4 OpenCV 4.12.0 (baseline above SSE2, not SIGILL)

`OPENCV_DUMP_CONFIG=1` reports `Baseline: SSE SSE2 SSE3` and dispatched SSE4_1, SSE4_2, AVX, FP16, AVX2, AVX512_SKX. Spectacle (linked to OpenCV) exits with "Missing support for required CPU baseline features" on the strict SSE2 model. It runs on the other three models. This blocks a true v1 target. Fix proposal in section 6.

### 5.5 Packages that are fine for this issue

- wireplumber, pipewire, libwayland, libkwin, libwireplumber, libpipewire, libglib, libgobject: no non-variant AVX in the scan. They fail only by calling libffi.
- glibc (`libc.so.6`, `libm.so.6`, `libmvec.so.1`): AVX/AVX-512 variants are chosen by ifunc, expected.

### 5.6 Full list of ELF files with v2+ ISA markers

94 lines from `readelf -n` over the rootfs, saved in `scratchpad/sigill/isa-v2plus.tsv` (outside the repo). Notable entries not discussed above: `libavcodec.so.61.19.101` (v2), `libgnutls.so.30.40.4` (v3), `libnettle.so.8.11` (v2), `libEGL.so.1.0.0` (v3), `libzstd.so.1.5.7` (v3), `libpcre2-*` (v3), `libQt6Core.so.6.9.2` (v2-v4), `libQt6Gui.so.6.9.2` (v2-v3), `spa-0.2/audioconvert` (v2-v3).

Note: `x86 ISA needed` never shows v2+ in this rootfs, even for libffi. Only `ISA used` is informative. Do not use `ISA needed` as a pass/fail check.

## 6. Fix proposals

### 6.1 Test base 12.4 (no rebuild performed here)

| Package | Change |
|---|---|
| libffi 3.5.2 | `./configure --prefix=/usr --disable-static --with-gcc-arch=x86-64` (libffi's own option: "use architecture <arch> for gcc -march/-mtune"). Then confirm `grep -- '-march' Makefile` shows `-march=x86-64`, not `native`. Note that libffi's configure still appends `-ffast-math` when the compiler accepts it. Confirm with `make -n` before accepting. Rebuild and reinstall `libffi.so.8`, then re-run section 4.1 for v1-strict and Nehalem. |
| GMP 6.3.0 | `./configure --prefix=/usr --build=x86_64-pc-linux-gnu --enable-cxx --enable-fat --disable-static CFLAGS="-O2 -march=x86-64 -mtune=generic"`. `--build` stops `config.guess` from reporting `zen3`. `--enable-fat` builds the x86_64 assembly with runtime CPU selection. Verify that `config.log` has no `znver3`. |
| MPFR 4.2.2 | `./configure --prefix=/usr --disable-static --enable-thread-safe CFLAGS="-O2 -march=x86-64 -mtune=generic"`. Verify `grep -c znver3 config.log` = 0. |
| OpenCV 4.12.0 | `-DCPU_BASELINE=SSE2` (keeps SSE4/AVX as dispatched code). Then check `OPENCV_DUMP_CONFIG=1 spectacle --version` under v1-strict. Not yet verified that OpenCV builds and passes its own checks with an SSE2 baseline. |
| Mesa 25.1.8 | Identify the source of AVX in `libgallium` (section 5.3) before choosing a flag. Likely fix: meson `-Dc_args=-march=x86-64` plus the disabling option for the offending file, or accept runtime dispatch for llvmpipe. Not verified. |

After each change, rebuild only the affected package, then run the section 6.3 audit on the new files.

### 6.2 Rule for the 13.1 rebuild

1. Global build environment for every package (set in the build driver, not per package):
   `CFLAGS="-O2 -march=x86-64 -mtune=generic"`, `CXXFLAGS="$CFLAGS"`, `FFLAGS="$CFLAGS"`, `FCFLAGS="$CFLAGS"`. The LFS GCC default is already generic x86-64, so the leaks come from packages that detect the host CPU on their own (autoconf `AX_GCC_ARCHFLAG`, `config.guess` CPU names, `meson -Dcpu`, cmake `-march=native` options). The global variable alone does not override those, so each package still needs its explicit option.
2. Packages that add their own `-march` (use the explicit option): libffi (`--with-gcc-arch=x86-64`), GMP and any GMP-family build (`--build=x86_64-pc-linux-gnu`), FFTW/OpenBLAS/x264 style packages (not in the current list, check on add).
3. Keep SIMD in runtime dispatch (OpenSSL, libgcrypt, OpenCV, glibc ifunc) instead of building the whole library with AVX.
4. Gate: no package passes into the 13.1 base until the audit (6.3) passes, and a v1-strict run of section 4 has no SIGILL.

### 6.3 Audit after every build

Static (fails on any VEX or non-baseline mnemonic in non-variant code):

```
# list shared libraries/executables in a DESTDIR that contain AVX/AVX2/BMI/FMA/AVX-512 code
find "$DESTDIR/usr" -type f \( -name '*.so*' -o -perm -u+x \) -print0 | while IFS= read -r -d '' f; do
  objdump -d --no-show-raw-insn "$f" 2>/dev/null | grep -qP '\t(v(mov|pxor|add|sub|mul|and|or|xor|fmadd|broadcast|perm|insert|extract|pcmp|pmin|pmax|pshuf|p(add|sub|mul|sll|srl|sra|and|or|xor)[a-z]*)\w*|andn|bextr|blsi|blsmsk|blsr|bzhi|mulx|pdep|pext|rorx|sarx|shlx|shrx|movbe)\s' && echo "$f"
done
```

Heuristic: runtime-dispatched code (OpenSSL, libgcrypt, OpenCV, glibc, Mesa llvmpipe) will show up. Review each hit: keep it only when it sits in a variant function that is selected at run time. `readelf -n "$f" | grep 'x86 ISA used'` lists the declared level of each object as a second check. `tzcnt` and `lzcnt` assemble as `rep bsf` and `rep bsr`, which run on any CPU, so they are not included.

Dynamic (the gate): run the binary or the library's init path under `qemu-x86_64 -cpu qemu64,-sse3,-cx16` and check for `uncaught target signal 4`. Minimal test pattern: `dlopen` the library and call one function (section 4.1).

### 6.4 Test matrix for future runs

Run section 4 with v1-strict, v2 (`Nehalem`) and v3 (`Haswell`). Report the SIGILL count per binary, not just rc. Keep the `--version` results and the session-path results apart.

## 7. Evidence paths

- Symptom logs: `docs/verification/m09-iso-v2-bios-serial-2026-11-06.log` (line 471, trap line), `docs/verification/m09-iso-v2-bios-nehalem-serial-2026-11-06.log` (line 473, trap line).
- Build logs: `scratch-lfs-bench/lfs-build-plan/logs/ch8.48.log` (libffi), `ch8.19.log` (GMP), `ch8.20.log` (MPFR).
- Scratch (not in the repo, reproducible): `scratchpad/sigill/` holds `cpuprobe.c`, `ffitest.c`, `matrix.sh`, `run_one.sh`, `deep.sh`, `scan.py`, `scan-results.jsonl`, `isa-v2plus.tsv`, `matrix-results.tsv`, and the decoded cores were removed after the check; the original .zst copies are in the same folder.

## 8. Limits

- User-mode QEMU does not run the full session. The culprit is proven through `ffi_prep_cif` and the cores, not through a full v1 session boot.
- Static scan counts are heuristics: runtime-dispatched code is counted unless its function name matches the variant pattern.
- GMP, MPFR, OpenCV and Mesa fixes are proposals. None was rebuilt or tested in this task.
- The v1 target claim needs a full v1 session boot after the libffi fix and the other fixes.

## Result (2026-11-06)

The section 6.1 rebuilds were run inside the LFS 12.4 chroot (`/mnt/lfs`) with the scripts in `scripts/lfs-blfs/cpu-baseline/`. Each package was rebuilt with the book options, except the CPU flags. Evidence: `docs/verification/cpu-baseline-rebuild-logs/` (log tails). Full logs are in the rootfs at `/mnt/lfs/sources/cpu-baseline-build/` (not in the repo).

### Rebuilds

| Package | Flags | Test result | Installed file (SHA-256) |
|---|---|---|---|
| libffi 3.5.2 | `--with-gcc-arch=x86-64` (book: `native`) | `make check`: 2460 expected passes, 0 unexpected failures | `/usr/lib/libffi.so.8.2.0` `28b70739fe951ae35957ec47d01c321eda02a9281ca99dda942ceb66f6c40947` |
| GMP 6.3.0 | `--build=x86_64-pc-linux-gnu --enable-fat`, CFLAGS and CXXFLAGS `-O2 -march=x86-64 -mtune=generic` | book test total: 199 PASS (book minimum 199), 0 FAIL/XPASS/ERROR. One sub-suite reports 1 SKIP, as in the original build | `/usr/lib/libgmp.so.10.5.0` (rc 0, 15:47) |
| MPFR 4.2.2 | CFLAGS `-O2 -march=x86-64 -mtune=generic` | `make check`: TOTAL 198, PASS 198, 0 FAIL/XPASS/ERROR | `/usr/lib/libmpfr.so.6.2.2` `04a282fba381a1ccf75a0b940c1738ebe0391424bcce8b44eed7b65d545b8f4e` |

The config.log check (no `znver3` before install) passed for all three. The three scripts exited 0.

### ISA audit (`scripts/lfs-blfs/cpu-baseline/audit-isa.sh`)

Non-variant hits, before and after the GMP fat-variant rule was added to the audit:

| File | Before | After | Notes |
|---|---|---|---|
| `libffi.so.8.2.0` | 0 | 0 | ISA used: x86-64-baseline |
| `libgmp.so.10.5.0` | 474 (232 variant) | 0 (706 variant) | All 706 hits are in 19 GMP fat-variant functions: `__gmpn_*` symbols ending in `_coreibwl`, `_coreihwl` or `_zen`. ISA used: x86-64-baseline |
| `libmpfr.so.6.2.2` | 0 | 0 | ISA used: x86-64-baseline |
| `libgmpxx.so.4.7.0` | 0 | 0 | ISA used: x86-64-baseline |

Rule change: `__gmpn_*` symbols are counted as variant only when they end in a CPU directory name of GMP 6.3.0 (`mpn/x86_64/`). Other symbols are not affected. The BMI check matches whole mnemonics, so SSE2 `andnpd`/`andnps` are not counted as BMI `andn`.

Audit self-test (host, scratchpad): a `-mavx2` test library with generic AVX code fails (exit 1). An SSE2-only library with `andnpd` passes (exit 0).

### Boot (ISO v3, default CPU model)

- Model: `qemu64` (the VM default). Evidence: `docs/verification/m09-iso-v3-bios-qemu64-serial-2026-11-06.log` (448 lines) and `docs/verification/m09-iso-v3-bios-qemu64-screen-2026-11-06.png`.
- Serial log: no kernel trap, SIGILL, `invalid opcode` or `FAILED` line. The log stops at the login prompt, so it shows boot only.
- Screenshot: Plasma desktop running, with the Welcome Center open.
- Reported by the supervisor: 0 SIGILL, 0 abnormal ends, 0 FAILED units in the session. The session journal is not in the repo, so this is not checked here.
- Not run in this result: the v1-strict (`qemu64,-sse3,-cx16`) user-mode test (section 4.1), and the Nehalem and Haswell boots. The v2/v3 models were not re-tested after the fix.

### Open items

These stay open. A qemu64 Plasma session ran without SIGILL. That shows the failing paths were not hit in that test, not that they are fixed.

1. **OpenCV 4.12.0**: baseline is SSE SSE2 SSE3 (section 5.4). The strict SSE2-only model still cannot run spectacle. Fix proposal (`-DCPU_BASELINE=SSE2`) not built or tested.
2. **Mesa 25.1.8**: AVX markers in `libgallium` (`evaluate_fdot16`, `convert_half_float`) and `pipe_swrast.so` (section 5.3). Source of the AVX not traced yet.
3. **Runtime-dispatched libraries**: `libcrypto.so.3`, `libgcrypt.so.20.6.0`, `libLLVM.so.20.1` contain non-variant AVX/BMI code (section 5.3). Not re-audited in this step. Not classified as culprits.
4. **v3 ISA markers**: `libgnutls.so.30.40.4` (v3) and `libnettle.so.8.11` (v2) (section 5.6). Not audited in this step.
5. **Full v1-strict run** (section 4 matrix with `qemu64,-sse3,-cx16` and the section 4.1 minimal test on the rebuilt libffi): not run.
