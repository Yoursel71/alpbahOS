# Base run 72821817e429772543623ef287542341 — Binutils test environment

## Result

The fresh Base run started from the accepted `checkpoint-toolchain` with input SHA-256 `abbd6785375cc5570ca89d0b5ba2d7227b9e61cdd6136a79b00baaed12b24a5b`. Glibc completed its pinned policy; its 1,881-entry ownership manifest and m32 handoff passed. Earlier base packages produced `BUILT` receipts. Binutils compiled and completed all six DejaGNU summary files, but the strict policy rejected 13 unexpected failures (5 in binutils tests and 8 in ld tests; 5,649 passes). The run has no Base acceptance or checkpoint.

The guest shut down cleanly after the test-policy rejection. No QEMU crash, host MCE, OOM, thermal, or storage fault was recorded. The controller closed both qcow2 writers and preserved the failed overlays at `/mnt/alpbahOS-ssd/alpbahos-infra-rebuild/preserved-overlays-1791354589394428975/`. The outcome is `/mnt/alpbahOS-data/alpbahos-infra-rebuild/state/stage-runs/72821817e429772543623ef287542341/outcome.json`, SHA-256 `569984f601cf774de9c2724d1a00adb3afe661ababb5c605ae14410c322c58ec`. The Binutils log is `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/72821817e429772543623ef287542341/guest-base-partial/binutils/base-binutils.log`, SHA-256 `99c37ab16f5d1ccafb40bc23d2a9c2c0bb1d9f09e2e8f39bedbf8bcdfc976f74`.

## Cause and correction

The test subprocess inherited the same reproducibility flags as the package build. `-ffile-prefix-map` rewrote the compiled source path to `/usr/src/binutils`, while the upstream `addr2line` tests expect the live `$srcdir/$subdir/testprog.c` path. The log shows that mismatch directly. The related `objdump -S`, `objdump --source-comment`, and `Dump pr21978.so` tests also inspect source paths. Separately, Binutils 2.45's `replacing non-deterministic member` test explicitly requires `SOURCE_DATE_EPOCH` to be unset; the recipe had set it for every step. The seven `ld` bootstrap failures were reported without their detailed DejaGNU `.log` files, so their individual cause is not proven by this run.

The Binutils recipe now keeps deterministic flags and epoch for compile/install, but invokes its tests serially with `SOURCE_DATE_EPOCH` unset and the path-remapping flags omitted. The zero-unexpected-failure policy remains unchanged; the next clean Base run must show whether this fixes the bootstrap failures as well.

## Validation and next run

- `python3 -m json.tool recipes/base/binutils.json` and `git diff --check`: PASS.
- `PYTHONPATH=scripts/infra python3 -m unittest discover -s tests`: 350 tests, 2 skipped, 91.157 seconds, PASS.
- Updated build input SHA-256: `c76a1c737693aab8a4380a395a9515da8d86a7f641099c6f9e5ba4166e4f7306`.
- Failed overlays remain preserved; they are not reused for a new build. A fresh Base run from the accepted checkpoint is required.
