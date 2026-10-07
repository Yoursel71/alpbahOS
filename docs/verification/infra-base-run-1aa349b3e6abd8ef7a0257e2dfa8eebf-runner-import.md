# Base run 1aa349b3e6abd8ef7a0257e2dfa8eebf — guest runner import fix

The run started from the accepted `checkpoint-toolchain` with build input digest `c76a1c737693aab8a4380a395a9515da8d86a7f641099c6f9e5ba4166e4f7306`. It completed Glibc and Binutils and installed earlier Base packages inside the isolated QEMU/KVM guest. It then stopped before GMP configure because `run_with_root_owned_test_tree()` called `subprocess.run()` without importing `subprocess`:

```text
File "/opt/alp-infra/infra-base-guest-run.py", line 894, in run_with_root_owned_test_tree
NameError: name 'subprocess' is not defined
```

This is a host-side runner programming error. No GMP or Base acceptance receipt/checkpoint was produced; this failed run will not be replayed. Its package and partial-run evidence remains under `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/1aa349b3e6abd8ef7a0257e2dfa8eebf/`. `base.log` SHA-256 is `2291a88628b8ed93bded2fec21370fc41e680886702591d2e8409a558604e4bf`; host telemetry SHA-256 is `c9105217178137ccdfb41de245aded7d3e539c288f049c44f6fb3f84cc7d26c5`.

The guest runner imports `subprocess` now. A regression test exercises the GMP adapter with guest GCC 12 and confirms it skips the GCC-15-only configure edit. Guest runner SHA-256 is `05becdfd9d074065a49a1bf183286d1caafe034fc5072dffddb4fc53e8a7c966`; focused host test file SHA-256 is `c06a0e8ef34f9797d37c0e5f70a8eda777b47e634b70b0d0e102878f7734540d`. The focused file passed 18/18 tests. The full suite passed 358 tests with 2 skipped in 93.366 seconds; log `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-full-tests-subprocess-import-20261007.log`, SHA-256 `062acc452c081c9aba4ab8e032f7b1393d0974539d31b54fe9782804ae5e5e2e`.

`buildctl.inputs_digest()` remains unchanged at `c76a1c737693aab8a4380a395a9515da8d86a7f641099c6f9e5ba4166e4f7306`. Across 506 host telemetry samples, `errors=[]` and `kernel_faults=[]`; CPU temperature ranged from 39.375°C to 59.5°C. Minimum free space was 50,993,135,616 bytes on `/`, 23,666,413,568 bytes on the SSD, and 75,836,452,864 bytes on the HDD/data volume, all above the configured 15% stop floor. The service exited with failure and the guest shut down; no desktop or user application was closed and no CPU settings were changed.

Next, commit and push the fix, then use the persistent launcher for a new uniquely identified Base run from `checkpoint-toolchain`. The restore path preserves the failed run's closed overlays before creating fresh active overlays.
