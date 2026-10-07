# Base run Binutils zlib linker-path failure — 7 October 2026

> Follow-up: the broad `-L/srv/lfs/usr/lib` adjustment recorded below did not survive the next clean Base run. Binutils then selected the LFS Glibc linker script and could not resolve Builder libc paths. The corrective isolated-zlib search path and its tests are documented in [the follow-up run report](infra-base-run-01a829601216c58d25099545aaf78d71-binutils-isolated-zlib.md).

Base run `e76c31b05068498fe728867061ad8c08` started at 00:57 (+03) from the accepted toolchain checkpoint with input SHA-256 `abbd6785375cc5570ca89d0b5ba2d7227b9e61cdd6136a79b00baaed12b24a5b`. It ran for 1 h 16 min before the Binutils build failed. This run has no Base acceptance or checkpoint.

## Verified progress and failure

Glibc 2.42 completed its test/build, m32 build, and install steps. The staged install receipt reports PASS, and all 1,881 entries in the package manifest matched. Binutils configured with system zlib and compiled through BFD, then failed while linking `libbfd.la`:

```
/usr/bin/ld: cannot find -lz
collect2: error: ld returned 1 exit status
```

The staged shared library was present at `/srv/lfs/usr/lib/libz.so` and resolved to `libz.so.1.3.1`. The Builder linker did not search the LFS library directory. The previous `-idirafter /srv/lfs/usr/include` change fixed header ordering; it did not make staged library paths visible to configure or libtool.

## Correction and validation

The exact Binutils build-directory adapter in `scripts/infra-base-guest-run.py` now sets both:

- `CC=gcc -idirafter /srv/lfs/usr/include`, retaining staged headers as fallback;
- `LDFLAGS=-L/srv/lfs/usr/lib`, so configure and later libtool links find the staged m64 zlib.

The adapter verifies the installed header and shared library, checks that `libz.so` resolves inside `/srv/lfs/usr/lib`, and rejects pre-existing compiler or linker overrides. No other package command receives these settings.

Validation:

- Focused `BinutilsLfsZlibEnvironmentTests`: **4/4 PASS**.
- `PYTHONPATH=scripts/infra python3 -m unittest discover -s tests -v`: **349 tests, 2 skipped, 89.370 s, PASS**. Log `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-full-tests-binutils-zlib-link-path-20261007-rerun.log`, SHA-256 `88c495b6527559dc80126922f2733832a75263d4f6d70004d300d8e236dd6cf4`.
- `python3 -m py_compile scripts/infra-base-guest-run.py`: PASS.
- `git diff --check`: PASS.
- The failed guest runner exited through the controller, which powered off the Builder and preserved both overlays. `qemu-img check` found no errors on either qcow2 image.
- The guest result tree (112 MB) was copied to `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/e76c31b05068498fe728867061ad8c08/guest-base-partial/results/base/e76c31b05068498fe728867061ad8c08/`. Its SHA-256 manifest is `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/e76c31b05068498fe728867061ad8c08-guest-results.sha256`, manifest SHA-256 `74c7ac489b01a73eac3c8225c8fa3870482f17bfa4366bf1b481bafadffe4879`.
- Guest Binutils log SHA-256 `9293432661b06c8f844c06e60e29825306bb40534b8b6f37cf06747c6fed60f3`; glibc log SHA-256 `89e818bb30768b2a9dc1f2dabef13a04407221c2e109eb60e9c05bf82fa66869`.
- Outcome SHA-256 `300dfa2d6155e6fe0c01d1079d797b4f8e5ae4f13079c66b4422c37398047178`.

The canonical build input digest is unchanged. A fresh Base run must verify the actual Binutils configure and link behavior before this stage can be accepted.
