# D34 BLFS libpciaccess replay — 30 September 2026

## Result

BLFS libpciaccess 0.18.1 was built and installed as a single-package replay in an isolated NVMe D34 snapshot.

- Run: `libpciaccess-20260930T090902Z-940ecd31`
- Base: NetworkManager D34 after snapshot UUID `962acc41-0fe8-8144-aeba-feee0a1a7494`, subvolume ID 716
- Output: UUID `0a484cbd-7b18-074a-a580-18d47da9e513`, subvolume ID 719
- Btrfs send stream: 838 events, 970,483 bytes
- Result: `PASS`; builder exit code 0
- Owned system paths: 7, including `usr/include/pciaccess.h`, `usr/lib/libpciaccess.so*`, and `usr/lib/pkgconfig/pciaccess.pc`
- Reconciled ledger: 79/79 official Chapter 8 packages + 28 supplemental; 58,947 final system path owners; `pciaccess.pc` attributed to `libpciaccess`

The runner's private mount namespace exposed only the working snapshot at `/mnt/lfs`; the host's active `/mnt/lfs` and current ISO were not changed. Source checksum calculation and upstream package tests were skipped per the standing preference. Focused D34 tests passed: 32/32.

## Scope

This is one M06 graphics prerequisite. It does not complete libdrm, Wayland, Mesa, fonts, Plasma, M09 rootfs/ISO lineage, or the Ventoy handoff. The M09 clean desktop rootfs gate remains **OPEN**.
