# 8 October 2026 — MPFR dependency paths and faster Glibc tests

Base run `f6c8fcb01988262f6a7c55d33ac24001` stopped cleanly at MPFR configure:

```text
checking for gmp.h... no
configure: error: gmp.h can't be found, or is unusable.
```

The Builder compiles outside the target chroot. GMP was installed in the LFS target and staged separately, but MPFR's compiler searched only Builder headers. This is a dependency-path error, not evidence of OC instability. Nineteen installed package receipts, including Glibc, Binutils and GMP, are preserved. There is no complete Base acceptance or checkpoint; the failed run will not be replayed. Both closed active qcow2 images passed `qemu-img check`.

Raw evidence is under `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/f6c8fcb01988262f6a7c55d33ac24001/`:

- `base.log`: SHA-256 `a185f8890718798b7e7927a0392bc7168b02c2654fba7a020c924fd4f97cb91b`.
- `guest-base-partial/mpfr/base-mpfr.log`: SHA-256 `ac89d96c5d176011e8440bebfb0d57b84e2602de8ab5ee4f751f5ff76417ebea`.
- `guest-base-partial/glibc/glibc.installed.json`: PASS, SHA-256 `14146eed07e5289b7d3ac8c1293628d6ef5947f52676b2d8cb3024f44ec60da2`.
- `base.host.jsonl`: 506 samples, no sample errors or kernel faults, 33.25–59.375°C; SHA-256 `db7f23c1aa9a846dbddc080b3acdcb9a77a186f0bc2e6085cce71b1e42b6737d`. Minimum free bytes: root 50,343,276,544; SSD 22,207,787,008; HDD/data 75,700,699,136. Each remained above 15%.

The guest-only adapter now supplies isolated staging include, link and runtime paths to MPFR (GMP), MPC (GMP/MPFR), and GCC (GMP/MPFR/MPC/zlib). It rejects missing/aliased dependency paths, escaping shared-library links, system-header/libc shadowing and explicit conflicting overrides. It does not add the merged target libc directory to the Builder loader or install packages on the host.

The pinned Glibc test command is adapted to `make -j4 -k check with-lld=`. Four jobs match the recipe's compile budget, and Glibc's pinned source `INSTALL` documents numeric `-j` support. The complete suite, captured make status and unchanged critical test policy remain mandatory. This removes the serial-test bottleneck for the next run; no measured speedup or new guest acceptance is claimed yet. Glibc took 3,784.325 seconds in the failed run, including build, tests and both ABI staging steps.

Validation: focused guest-adapter tests 44/44 PASS; full `PYTHONPATH=scripts/infra python3 -m unittest discover -s tests -v` passed 365 tests with 2 skipped in 91.805 seconds. Full log `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-full-tests-native-math-dependencies-20261008.log`, SHA-256 `78844c153ae1c65fcac2a561b78aa899c6dd0fb8940549a6eb863ab01e5ba8e4`. Runner SHA-256 `e8a188237b269de9fd15f82620338f68d38bc74c15b2c85dff260ebaa7900822`. Build input digest is unchanged: `c76a1c737693aab8a4380a395a9515da8d86a7f641099c6f9e5ba4166e4f7306`.

During this run, the unused pair `preserved-overlays-1791354589394428975` was moved from SSD to `/home/yrslf/alpbahOS-infra-archive/preserved-overlays-1791354589394428975/`. Source/archive hashes matched: builder `2064277526cbd329a62d271f6b443f13aececa1fcd3be3eee53535afd0210192`, LFS `724ec1cbe8ed4f40ee1c31c8a5b8ac1167e2d3dfaf34df74e409ff85e6cdc069`; archived images passed qcow2 checks.

Before restarting, two obsolete noncheckpoint pairs `preserved-overlays-1791360557509307638` and `preserved-overlays-1791385129004256524` were removed under the user's unused-artifact cleanup authorization. All 75 qcow2 files in managed SSD/data/archive roots were inspected; no image referenced those four leaf overlays. Their parents were the accepted toolchain, both directories contained only the expected pair, each image passed qcow2 checks, and SHA-256/device/inode/mtime/size evidence was recorded before deletion. The current failed run and accepted checkpoints remain intact. Receipt `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/cleanup-unused-failed-overlays-20261008.json`, SHA-256 `3f6921c5a309ffb616dc8ad6862f3e2cebc477f1097e393b20fdf58ddc3bfc04`; 16,341,811,200 allocated bytes removed. SSD free space rose to about 41 GiB. Root remained about 47 GiB and HDD/data about 71 GiB free.

The documentation checker reports 31 findings in historical references/terms; its log is `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-doc-check-native-math-20261008.log`. The new verification report is not flagged. This is not a clean documentation-check acceptance.

Next: commit/push the change and start a new persistent Base run from the accepted toolchain. User applications and CPU settings were not changed.
