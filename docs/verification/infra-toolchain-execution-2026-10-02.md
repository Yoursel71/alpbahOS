# Toolchain run attempt and runner fix — 2 October 2026

The first isolated Chapter 4/5 guest attempt used single-use run `7039975a55baf2ce5588d59832c12bee`. The Builder and stability handoff passed; the sequence installed its owned filesystem layout and stopped before the first Binutils compile because `/usr/sbin/runuser` was absent from the recipe's restricted `PATH` (`/tools/bin:/usr/bin:/bin`). Read-only guest inspection of the prepared image confirmed `/usr/sbin/runuser` exists. No host build, host mount, chroot, or root filesystem mutation occurred.

The failure was preserved and not replayed. `toolchain.log` SHA-256 `262ba198dc2c1c17cb9523b17bb6099c9593282a541f7593579b1460a4e59d95`; `toolchain-command-failure.json` SHA-256 `1264582c4c30e3980a3d4214c295ff1bdc468ea96615bd8cdb7b1992773f3020`. Controller powered off the guest and collected partial guest evidence.

Fix: `package_stage.py` now invokes the host utility by its absolute `/usr/sbin/runuser` path, independent of an individual build recipe's PATH. Regression coverage was adjusted. `py_compile`, `test_base_plan` (15 tests), `ToolchainPreparationTests` (4 tests), and `git diff --check` pass.

This changes a canonical build input, so the previous Phase 1/stability receipts and checkpoint cannot authorize a new toolchain run. Recreate smoke and stability acceptance from the immutable `prepared` checkpoint before retrying under a new single-use run identity. No toolchain package build or product acceptance is claimed by this record.
