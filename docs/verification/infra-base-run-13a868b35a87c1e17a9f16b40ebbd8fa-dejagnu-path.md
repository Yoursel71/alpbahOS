# Base run DejaGNU path failure — 6 October 2026

Base run `13a868b35a87c1e17a9f16b40ebbd8fa` stopped at DejaGNU configure. The guest log records `env: '../configure': No such file or directory`; the cached source archive contains `dejagnu-1.6.3/configure`. The recipe requested a separate build, but left compile/test/stage working directories at the source-root default. The guest runner therefore resolved `../configure` from the source root instead of its `build/` child.

The recipe now sets compile, test, and stage working directories to `build`, preserving the pinned out-of-tree layout and the intended `../configure` and `../doc/...` paths. A regression assertion checks this recipe contract.

Evidence:

- Failed package log: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/13a868b35a87c1e17a9f16b40ebbd8fa/guest-base-partial/dejagnu/base-dejagnu.log`
- Failed package log SHA-256: `c0c94617ad92a1a2d1c15b57ce5706683aac2c30500dcdd31ab8fbdb84150c78`
- The `lfs-active.qcow2` and `builder-active.qcow2` each passed `qemu-img check` with “No errors were found on the image.” These failed-run disks remain retained at their active paths and are not accepted checkpoints.
- Focused tests: `test_base_plan.py` 15/15 and `test_infra_base_stage_host.py` 17/17 passed.
- Full suite: `PYTHONPATH=scripts/infra python3 -m unittest discover -s tests`; 341 tests, 2 skipped, 89.637 seconds, PASS.
- Updated canonical input digest: `80fba6d03881a09cfc2774dd778abc27d8fca27e2e320035550b8d27756a6678`.

The prior toolchain acceptance is bound to the previous input digest, so the stability gate and toolchain acceptance must be recreated before another base run. The failed run has no base-stage acceptance or checkpoint and will not be resumed.
