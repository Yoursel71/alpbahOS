# D34 BLFS Wayland replay — 30 September 2026

## Result

BLFS Wayland 1.24.0 was built and installed as a single-package replay after libdrm 2.4.125 in an isolated NVMe D34 snapshot.

- Run: `wayland-20260930T091814Z-df43fe6d`
- Base: libdrm output UUID `cf6c926f-75f9-fb47-bb4c-cbf1e60df5dc`, subvolume ID 722
- Output: UUID `1a1102ea-4b7c-3146-b71d-98dd1412bbf2`, subvolume ID 725
- Btrfs send stream: 3,101 events, 7,615,742 bytes
- Result: `PASS`; builder exit code 0
- D34 ledger: `COMPLETE`, 79/79 official LFS + 30 supplemental, 59,051 final system path owners
- Wayland-owned paths: 38/38 found in output root; missing 0

In the target root, client/server pkg-config versions and `wayland-scanner --version` returned 1.24.0. `libwayland-client.so`, `libwayland-server.so`, and protocol scanner were present. The runner used its private mount namespace; active HDD `/mnt/lfs` and current ISO were not modified. Checksums and upstream package tests were skipped per standing preference. Focused D34 tests passed: 34/34; shell/Python syntax and `git diff --check` passed.

## Scope

This closes the Wayland library layer only. Wayland protocols, Mesa, fonts, Plasma, M09 rootfs/ISO lineage, and Ventoy handoff remain open.
