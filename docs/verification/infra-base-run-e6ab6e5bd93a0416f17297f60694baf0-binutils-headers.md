# Base run Binutils header-order failure — 7 October 2026

Base run `e6ab6e5bd93a0416f17297f60694baf0` started at 23:30:16 and stopped at 00:50:10 (+03), after about 80 minutes. It used accepted toolchain run `ff1b264e6bc5b55d60bafa4c8ef46481`, input SHA-256 `abbd6785375cc5570ca89d0b5ba2d7227b9e61cdd6136a79b00baaed12b24a5b`, source SHA-256 `aa8cc629f81a0dbae69cfa0454724e3521a7b16a8c9e75e0ab12b135069e6abb`, and guest-runner SHA-256 `c3c2f6d51c304edb52b6c8b971aec826b331ea954b17242ddd226d775c44e0a9`.

## Verified progress

Glibc 2.42 completed its configured test policy: 6,984 PASS, 16 XFAIL, 91 UNSUPPORTED, with the single `stdlib/tst-system` failure allowed by the pinned policy. The m32 build and glibc staged ownership/install markers completed. Seventeen package install receipts were captured before the Binutils failure. This run is not a Base-stage acceptance and created no Base checkpoint.

## Failure and correction

The guest adapter added `CC=gcc -I/srv/lfs/usr/include` to the unchrooted Builder Binutils build to expose the installed LFS `zlib.h`. The include path was too broad: Binutils also selected LFS target `stdlib.h` and `obstack.h` ahead of Builder/Binutils headers. `libiberty/obstack.c` failed with mismatched obstack members and unknown `_OBSTACK_SIZE_T`, and `make -j4 tooldir=/usr` returned 2.

The adapter now uses `CC=gcc -idirafter /srv/lfs/usr/include`. That retains the verified LFS header tree only as a final fallback, so a missing Builder `zlib.h` can be found without overriding Builder libc or Binutils headers. The change only affects the exact Binutils build working directory and remains bound by the per-run guest-runner SHA; the accepted canonical input digest stays unchanged.

Validation before retry:

- `PYTHONPATH=scripts/infra python3 -m unittest discover -s tests -p 'test_infra_base_guest_runner.py'`: **28/28 PASS**.
- `python3 -m py_compile scripts/infra-base-guest-run.py tests/test_infra_base_guest_runner.py`: PASS.
- `git diff --check`: PASS.
- Full suite `PYTHONPATH=scripts/infra python3 -m unittest discover -s tests`: **348 tests, 2 skipped, 95.657 s, PASS**; log `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-full-tests-binutils-header-fallback-20261007.log`, SHA-256 `c636e8718ff561f51d1c327bae03be46ebd9f2b7791d9a9f05de8d4859a0d3fb`.
- `buildctl.inputs_digest()`: unchanged at `abbd6785375cc5570ca89d0b5ba2d7227b9e61cdd6136a79b00baaed12b24a5b`; inventory verifier reports 79/79 recipe coverage.
- Actual Binutils build with the fallback ordering remains to be verified in a fresh full Base run.

## Preserved evidence

- Outcome: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/state/stage-runs/e6ab6e5bd93a0416f17297f60694baf0/outcome.json`; SHA-256 `c0782ab7d85becf2e2be39761f029bf0fcfc00a1a51cc3e03e434afff6cb7f95`.
- Run record SHA-256: `da489cc7d1495ff42db1ebb1441e8b9d7748371edff62b2652cde9a85bf27e84`.
- Guest Binutils log: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/e6ab6e5bd93a0416f17297f60694baf0/guest-base-partial/binutils/base-binutils.log`; SHA-256 `f94331ecc34209feb86f418bfde3ed8f960be732647b83ae1741ac418bfec563`.
- Guest glibc log SHA-256: `60648ccd40004213bb927102aa7bee53a06f39b5cf14686ac71655e16131ad8e`.
- Host controller log: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/alpbahos-infra-base-20261006T202728Z-918546.log`.
- All failure artifacts and overlays remain preserved. No failed run was replayed.

Next: commit/push the runner correction and report, then launch a fresh monitored Base run from the accepted toolchain checkpoint.
