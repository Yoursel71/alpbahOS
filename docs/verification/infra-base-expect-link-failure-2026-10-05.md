# Expect link failure and correction — 5 October 2026

## Outcome

The persistent base run `454bc498a94c5f499e37668b5565ce11` stopped while linking Expect after Tcl and 13 earlier base packages had installed receipts. The VM powered off cleanly. The failed run did not produce an accepted base stage or checkpoint; its partial output is preserved at `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/454bc498a94c5f499e37668b5565ce11/guest-base-partial/`.

## Cause and correction

Tcl's accepted `/srv/lfs/usr/lib/tclConfig.sh` sets `TCL_STUB_LIB_SPEC='-L/usr/lib -ltclstub8.6'`. The Expect recipe configures outside the LFS chroot, where `/usr/lib` is the Builder's host library directory, so the linker could not find the target's `/srv/lfs/usr/lib/libtclstub8.6.a`.

The guest adapter now verifies that the stub archive is a regular file contained by the dedicated LFS root, removes inherited `LD_LIBRARY_PATH` from Builder tools, and passes the verified LFS library directory through `LDFLAGS` to Expect configure and its make process. Regression coverage checks both the translated linker path and fail-closed behavior when the archive is missing.

## Verification

- Isolated integration build used the exact Tcl package archive from the failed run, plus the pinned Expect 5.45.4 source archive and GCC 15 compatibility patch. Configure and `make -j4` succeeded, producing `libexpect5.45.4.so` with SHA-256 `5b0539144e3f70c5d0b322e91bf8f4b2b80b6e42a47c5a660cf5f1b919705e87`. Log: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/expect-link-smoke-20261005-retry.log`; SHA-256 `26678bad90d07a98771fea46ebc2bcbb41baca445a6f132161fcd91c283cbcef`.
- Full test suite: **338 passed, 2 skipped** in 89.311 seconds. Log: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-full-tests-expect-stub-link-fix-20261005.log`; SHA-256 `a06ab7ee343dc6a3264d4b838d7156188015d8aa060bbe95a0bcc964330c11a3`.
- `git diff --check` passed.
- Accepted toolchain input digest remains `d120f4db2e8f69e107069f8c13e3800d76f3f5e2fcae8ee1d547097f209c13cf`.

Next action is a fresh monitored base run from the accepted toolchain checkpoint. No 79-package base acceptance has yet been achieved.
