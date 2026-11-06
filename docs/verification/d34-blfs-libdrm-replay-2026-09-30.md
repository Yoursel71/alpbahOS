# D34 BLFS libdrm replay — 30 September 2026

## Result

BLFS libdrm 2.4.125 was built and installed as a single-package replay following libpciaccess 0.18.1 on an isolated NVMe D34 snapshot.

- Run: `libdrm-20260930T091458Z-3bf4137f`
- Base: libpciaccess output UUID `0a484cbd-7b18-074a-a580-18d47da9e513`, subvolume ID 719
- Output: UUID `cf6c926f-75f9-fb47-bb4c-cbf1e60df5dc`, subvolume ID 722
- Btrfs send stream: 4,690 events, 8,822,627 bytes
- Result: `PASS`; builder exit code 0
- D34 ledger: `COMPLETE`, 79/79 official LFS + 29 supplemental, 59,015 final system path owners
- libdrm-owned paths: 70/70 found in output root; missing 0

In the target root, `pkg-config --modversion pciaccess` returned 0.18.1 and `pkg-config --modversion libdrm` returned 2.4.125. `libdrm.so`, `libdrm_amdgpu.so`, `libdrm_intel.so`, `libdrm_nouveau.so`, and `libdrm_radeon.so` were present in the linker cache.

The runner mounted only its working Btrfs snapshot at `/mnt/lfs`. Active HDD `/mnt/lfs` and current ISO were not changed. Source checksums and upstream package tests were skipped per standing preference. Focused D34 tests passed: 33/33; shell/Python syntax and `git diff --check` passed.

## Scope

This advances the M06 graphics stack but does not complete Mesa, Wayland, fonts, Plasma, M09 rootfs/ISO lineage, or Ventoy handoff.
