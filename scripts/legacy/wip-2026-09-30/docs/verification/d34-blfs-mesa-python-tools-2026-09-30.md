# Mesa prerequisite chain and build on the D34 candidate

Date: 2026-09-30 (TRT)

The Mesa prerequisite chain has separate, event-recorded package deltas for Cython 3.1.3, Mako 1.3.10, PyYAML 6.0.2, and Mesa 25.1.8. These follow libyaml 0.2.5 and Wayland Protocols 1.45 in the NVMe D34 candidate. The existing HDD `/mnt/lfs` and ISO were not modified.

| Package | Run | Result | D34 output subvolume | Owned system paths |
|---|---|---|---:|---:|
| Cython 3.1.3 | `Cython-20260930T092942Z-156267e8` | PASS | 738 | 520 |
| Mako 1.3.10 | `Mako-20260930T093649Z-1f92d7ab` | PASS | 745 | 91 |
| PyYAML 6.0.2 | `PyYAML-20260930T093705Z-532e5540` | PASS | 748 | 106 |
| Mesa 25.1.8 softpipe/Wayland | `Mesa-20260930T094149Z-bd84ffcc` | PASS | 751 | 754 |

The latest candidate is `/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs/Mesa-20260930T094149Z-bd84ffcc/after-ro`. In its chroot, Python metadata reports all three requested versions, the PyYAML `_yaml` extension imports, and Cython/Mako modules import. Mesa build completed all 974 Ninja targets; final install verified EGL, GLES, GBM, Gallium, and Wayland GBM files. EGL/GLES `pkg-config` versions are 25.1.8 and `ldconfig` finds EGL. The full event-derived ownership ledger reconciles as COMPLETE: 79/79 official LFS Chapter 8 packages, 36 supplemental packages, and 60,590 final system-path owners. Mesa changed 108,210 Btrfs events (462,709,578 bytes). Ledger: `/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs/Mesa-20260930T094149Z-bd84ffcc/d34-ownership-ledger.json`.

The supplemental ordering tests and D34 builder wiring tests pass, 40/40. Two Mako attempts stopped immediately on shell `set -u` variable initialization mistakes; those failed runs are retained, excluded from the successful chain, and the corrected third run passed. No upstream package test suite or source checksum was run.

Mesa is now in the isolated graphics candidate. A complete clean desktop rootfs → live ISO → Ventoy lineage remains open.
