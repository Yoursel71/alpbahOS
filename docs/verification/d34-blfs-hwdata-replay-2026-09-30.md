# D34 BLFS hwdata replay — 30 September 2026

## Result

BLFS `hwdata 0.398` completed as a supplemental replay after the official LFS Chapter 8 chain. It ran through the D34 private mount namespace on a new NVMe working snapshot; the host `/mnt/lfs` and existing Ventoy-ready ISO were not the target.

- Input candidate: `/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs/e2fsprogs-20260930T025853Z-11f33b5a/after-ro`, Btrfs filesystem UUID `663b4a21-0364-4ee2-91cd-67d5994e9fe4`, subvolume UUID `e6e17e94-5c8d-a349-a8bb-b500c70efc9a`, ID 588.
- Replay: `hwdata-20260930T065147Z-0595f346`, PASS, 838 Btrfs events, 10,248,421-byte incremental stream.
- Output candidate: `/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs/hwdata-20260930T065147Z-0595f346/after-ro`, subvolume UUID `a56bb38e-38bb-4444-89ab-0ade266d9045`, ID 591.
- Builder log/status are on the HDD: `/mnt/alpbahOS-data/alpbahOS-build/logs/blfs-12.4-systemd/hwdata-0.398-20260930T065147272844878Z.log` and `.status`. The package's tests and checksum calculations were skipped as defined by the builder and user instruction.
- Durable reconciliation output: `/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs/hwdata-20260930T065147Z-0595f346/d34-ownership-ledger.json`. It remains COMPLETE at 79/79 official packages, with two distinct supplemental rows (Linux-PAM 1.7.1 and hwdata 0.398) and 51,586 final system-path owners. Root read-only verification found all seven final paths attributed to hwdata in the output snapshot: `usr/share/hwdata` and its five device-data files, plus `usr/share/pkgconfig/hwdata.pc`.

## Changes and validation

The existing hwdata host builder now uses the shared LFS guard, retaining its ordinary ext4/HDD behavior while accepting only the D34 runner's inherited lock and exact Btrfs identity. The D34 runner allows only the explicit `hwdata`/`build-blfs-hwdata.sh` host-script pair. The reconciler accepts hwdata only after all 79 official entries and keeps it outside the official count. Supplemental regression tests reject early and duplicate hwdata entries.

Targeted validation passed: 11 D34 candidate-preflight, builder-wiring, and supplemental-reconciliation tests; Python compilation; shell syntax; and `git diff --check`.

This pilot improves provenance for the clean LFS candidate. It does not establish that the existing desktop rootfs or ISO was built from this candidate and does not close M06/M07 integration or M09 release acceptance.
