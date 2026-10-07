# Base run 01a829 — Binutils zlib search path shadowed Builder libc

## Result

The Base run `01a829601216c58d25099545aaf78d71` started from the accepted `checkpoint-toolchain` with input SHA-256 `abbd6785375cc5570ca89d0b5ba2d7227b9e61cdd6136a79b00baaed12b24a5b`. The controller powered off the VM after the Binutils configure compiler probe failed. The stage produced no acceptance or checkpoint.

Seventeen packages have PASS install receipts: `bc`, `bzip2`, `dejagnu`, `expect`, `file`, `flex`, `glibc`, `iana-etc`, `lz4`, `m4`, `man-pages`, `pkgconf`, `readline`, `tcl`, `xz`, `zlib`, and `zstd`. Glibc 2.42's 1,881 manifest entries matched. Its test policy accepted the previously documented exact root-only `stdlib/tst-system` failure; the package install receipt is PASS.

## Failure evidence

The Binutils configure log is preserved at `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/01a829601216c58d25099545aaf78d71/guest-base-partial/binutils/base-binutils.log`, SHA-256 `79673af0307c6fd750fe45b5409bd5f8776309e44bb0811e7a8359ab65b9f050`. Its compiler command included `LDFLAGS=-L/srv/lfs/usr/lib`. Read-only `guestfish` inspection of `/build/base-binutils/build/config.log` found:

```
/usr/bin/ld: cannot find /usr/lib/libc.so.6: No such file or directory
/usr/bin/ld: cannot find /usr/lib/libc_nonshared.a: No such file or directory
/usr/bin/ld: cannot find /usr/lib/ld-linux-x86-64.so.2: No such file or directory
collect2: error: ld returned 1 exit status
```

This showed the broad LFS library path selected LFS Glibc's linker script while Binutils was being linked against the Builder libc. The run stopped at configure, before testing the earlier `-lz` failure mode.

The LFS image was inspected read-only after QEMU stopped. `/stage/base-zlib/usr/lib` contains only `libz.so`, its versioned symlinks and library, and `pkgconfig`; it contains no libc or dynamic loader. Guest partial results are preserved at `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/01a829601216c58d25099545aaf78d71/guest-base-partial/` (111 MB). The host controller log is `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/alpbahos-infra-base-20261006T232219Z-1157216.log`.

## Fix and validation

`scripts/infra-base-guest-run.py` now points Binutils' linker search path only at `/srv/lfs/stage/base-zlib/usr/lib`. It validates that the staging path is not aliased and rejects a staging directory containing `libc.so`, `libc.so.6`, `libc_nonshared.a`, or the dynamic loader. The `-idirafter /srv/lfs/usr/include` header fallback remains limited to the Binutils build command.

Validation passed:

- Focused `BinutilsLfsZlibEnvironmentTests`: 5/5.
- Full suite: `PYTHONPATH=scripts/infra python3 -m unittest discover -s tests -v` — 350 tests, 2 skipped, 89.637 seconds.
- Full suite log: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-full-tests-binutils-zlib-isolated-dir-20261007.log`, SHA-256 `a9329d8aed79d0b80087df4aabf193c766ed8034c5ab2c106df60e3bbfb448c8`.
- `python3 -m py_compile scripts/infra-base-guest-run.py tests/test_infra_base_guest_runner.py`: PASS.
- `git diff --check`: PASS.

A new Base run from the accepted checkpoint must verify both the staged zlib link and Builder libc resolution. This report records a failed run and a code-level correction, not Base acceptance.
