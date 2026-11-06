# D34 BLFS libyaml replay — 30 September 2026

## Result

BLFS libyaml 0.2.5 was built and installed as a single supplemental package for the Mesa build-tools chain.

- Successful run: `libyaml-20260930T092501Z-823cadd7`
- Failed run retained: `libyaml-20260930T092435Z-b1181b86` (a builder shell `[[ ... ]]` closing-token typo after staging; no after snapshot and no target install)
- Base: Wayland Protocols output UUID `2db4bac5-d861-844c-9f06-bad4b48c393a`, subvolume 728
- Output: UUID `a01f02d1-c18b-bf4e-ac68-eeb68930fd9f`, subvolume 733
- Btrfs stream: 1,919 events, 5,768,423 bytes; successful builder exit 0
- Reconciled ledger: `COMPLETE`, 79/79 Chapter 8 + 32 supplemental, 59,231 final system-path owners
- libyaml-owned paths: 8/8 present; pkg-config reports 0.2.5

Focused D34 tests passed: 36/36. Shell/Python syntax and `git diff --check` passed. Source checksum and upstream package tests were skipped per standing preference. Only the isolated NVMe candidate changed; active HDD `/mnt/lfs` and ISO remain untouched.

## Scope

This adds one Mesa prerequisite; Mesa itself and the complete desktop rootfs/ISO lineage remain open.
