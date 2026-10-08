# 8 October 2026 — MPC Libtool dependency view and Glibc archive indexes

Base run `0b2b1a2bd079706ba6bb99971c84d907` installed twenty packages, including MPFR. The earlier GMP header-path fix therefore passed the real guest MPFR build, tests and installation. MPC configure passed, but `make -j4` failed while linking:

```text
libtool: warning: library '/srv/lfs/stage/base-mpfr/usr/lib/libmpfr.la' was moved.
libtool: error: '/usr/lib/libgmp.la' is not a valid libtool archive
```

MPFR's staged Libtool sidecar records `dependency_libs=' -L/srv/lfs/stage/base-gmp/usr/lib /usr/lib/libgmp.la'` and `libdir='/usr/lib'`. Outside the target chroot, Libtool follows the target archive path on the Builder. This is a dependency metadata/search-path failure, not evidence of CPU instability. The controller closed the guest; both closed active qcow2 images passed `qemu-img check`. The failed run and accepted checkpoints are preserved. There is no full Base acceptance/checkpoint.

The guest adapter creates a separate shared-library view at `/srv/lfs/build/.native-dependency-libs/<dependency>`, copying the verified real shared library and recreating its aliases. It excludes `.la` files, leaves the original stage bytes untouched, rejects unexpected files, altered payloads, aliased directories and changed aliases, and supplies `LIBRARY_PATH`/`LD_LIBRARY_PATH` plus staged `CPPFLAGS`. It no longer exports `LDFLAGS=-L<stage>` into installed Libtool metadata. The pinned MPC 1.3.1 `configure` obtains search directories from GCC `-print-search-dirs`; its `build-aux/ltmain.sh` searches `.la` before `.so` in those directories. Using a shared-only view avoids the rejected target sidecar. Actual MPC/GCC success remains to be verified in the next guest run.

Glibc built, tested and installed in 1,867.168 seconds versus 3,784.325 seconds in the previous run: 50.7% less elapsed time. This measures the whole package stage and is not a controlled isolated test-time benchmark. The complete four-job tests and unchanged acceptance policy passed. The current archive hash is `6be06a0e5c136ba030dc2850732fbd0abd55692554efc1614e6b2c1e009b81fd`; manifest hash `d7d46f06974d2ca367257b96edae6b3bd408903410d561f7b7774d7bc53458d6`.

A binary comparison of the two actual package archives found exactly six differing files under `usr/lib32`: `libBrokenLocale.a`, `libc.a`, `libc_nonshared.a`, `libg.a`, `libm.a`, `libresolv.a`. Only their GNU ar symbol-index timestamp fields differ; all other archive bytes/member payloads match. `ranlib -D` on temporary copies of these actual files made all six pairs byte-identical and changed no bytes outside those timestamp fields. Receipt: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/glibc-real-archive-index-normalization-0b2b1a2bd079706ba6bb99971c84d907.json`, SHA-256 `7c08b3b44e1f62f8d12ba924adced46d7a178f7bc18d3def1067371f4f32414f`. Original artifacts remain unchanged. Raw package reproducibility has not passed.

The adapter now runs `/usr/bin/ranlib -D` on precisely those six guest stage archives before Glibc manifest capture. It validates the capture command, canonical stage directories, ownership and GNU ar magic. It does not process linker scripts or raw ELF files with `.a` suffixes. A real GNU as/ar/ranlib test verifies equal normalized indexes with unchanged object payloads; adversarial path/metadata tests cover both adapters. A fresh repeat build and complete Base/ISO byte comparison are still required.

Validation: focused adapter tests 50/50 PASS. Full `PYTHONPATH=scripts/infra python3 -m unittest discover -s tests -v` passed 371 tests with 2 skipped in 90.316 seconds. Log `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-full-tests-libtool-archive-index-20261008.log`, SHA-256 `796fdf5051e16af7b0acdeafd9a6f7c32b93d95f7052dae0666b8c48b5f24088`. Runner SHA-256 `de2bab2211043dc963a8bae19fde899c9040b1effd14b474524c1ea570c2e1df`. Input digest unchanged: `c76a1c737693aab8a4380a395a9515da8d86a7f641099c6f9e5ba4166e4f7306`. `git diff --check` and runtime space guard passed. No independent agent review was performed.

Raw run evidence is under `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/0b2b1a2bd079706ba6bb99971c84d907/`:

- `guest-base-partial/mpc/base-mpc.log`: SHA-256 `0fcd935bcc142278fce59f686466fb7147ffd92a5c92d8989ff280bf97b3bfb7`.
- `guest-base-partial/mpfr/base-mpfr.json`: SHA-256 `ee19de2967cb41494273084a8f0babad29c1814028d843536d3e3325f55604ad`.
- `base.host.jsonl`: SHA-256 `2be03693566726e41f231f8038932103c56acc894f333bb8effa26a2cdbbd148`; 330 samples, zero sample errors/kernel faults, temperature 34.375–62.75°C. Minimum free bytes: root 50,340,270,080; SSD 35,516,035,072; HDD/data 75,567,435,776. All exceeded 15%.

The documentation checker still reports 31 historical findings (missing commit objects, decision references and stale terminology). The new report was not flagged; this is not clean documentation acceptance. Log: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-doc-check-libtool-index-20261008.log`.

Next: commit/push this fix and launch a fresh persistent Base run from the accepted toolchain. Preserve the new run while healthy, then continue the authorized kernel/BLFS/Plasma/GL/ISO pipeline after its actual acceptance. User applications and CPU settings were not changed.
