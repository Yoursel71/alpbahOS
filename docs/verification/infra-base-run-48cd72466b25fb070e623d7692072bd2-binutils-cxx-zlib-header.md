# Base run 48cd72466b25fb070e623d7692072bd2: Binutils C++ zlib header

## Result

The run restored the accepted `checkpoint-toolchain` and used canonical input SHA-256 `abbd6785375cc5570ca89d0b5ba2d7227b9e61cdd6136a79b00baaed12b24a5b`. Glibc 2.42 completed its pinned test policy: 7,092 results, 6,984 PASS, 16 XFAIL, 91 UNSUPPORTED, and the one explicitly allowed root-only `stdlib/tst-system` failure; `unexpected_failures` and `fatal_results` were empty. Its 1,881-entry manifest and m32 ownership handoff passed. Eighteen package result directories had `BUILT` receipts before Binutils.

The isolated zlib linker path fixed the previous Builder-libc collision: Binutils configure and most of the build proceeded with `LDFLAGS=-L/srv/lfs/stage/base-zlib/usr/lib`. The build then failed in `gprofng/src/DbeJarFile.cc:27` because `zlib.h` was not found. The C compiler had `CC=gcc -idirafter /srv/lfs/usr/include`, but gprofng compiled this source through `g++`; no matching `CXX` fallback had been added. The command exited 2 and the Base run produced no acceptance or checkpoint.

Guest evidence is preserved at `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/48cd72466b25fb070e623d7692072bd2/guest-base-partial/`. The Binutils log SHA-256 is `7a5868277271254a0f4c26801a3e36c2352937279a7e5365f172f793041ec16f`. The controller log is `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/alpbahos-infra-base-20261007T005913Z-1290006.log`. The controller powered off the guest and closed both qcow2 writers; `qemu-img check` passed for `builder-active.qcow2` and `lfs-active.qcow2`. The failed overlays and run evidence remain preserved.

## Correction and validation

The Binutils-only adapter now passes `CXX=g++ -idirafter /srv/lfs/usr/include` alongside the existing C fallback. This keeps Builder headers first and makes the installed LFS zlib header available as a fallback to gprofng. The adapter also fails closed when the recipe already supplies a `CXX` override. The linker search remains limited to the isolated zlib staging directory, which contains no libc or loader files.

- Focused `BinutilsLfsZlibEnvironmentTests`: 5/5 PASS.
- Full suite: `PYTHONPATH=scripts/infra python3 -m unittest discover -s tests` — 350 tests, 2 skipped, 90.693 seconds, PASS.
- Full suite log: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-full-tests-binutils-cxx-zlib-fallback-20261007.log`, SHA-256 `7c0d44d0c0d496b98bc5c51ba87c9149de551b40e833351d7ace7f547d052ade`.
- `python3 -m py_compile scripts/infra-base-guest-run.py tests/test_infra_base_guest_runner.py`: PASS.
- `git diff --check`: PASS.

The canonical input digest and accepted toolchain checkpoint are unchanged. This report records a failed Base attempt and its correction, not Base acceptance.
