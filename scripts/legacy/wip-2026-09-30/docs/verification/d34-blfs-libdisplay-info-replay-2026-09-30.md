# D34 BLFS libdisplay-info replay — 30 September 2026

## Result

BLFS `libdisplay-info 0.3.0` built and installed in a new D34 NVMe snapshot chained from the successful `hwdata 0.398` supplemental replay.

- Input: `hwdata-20260930T065147Z-0595f346/after-ro`, filesystem UUID `663b4a21-0364-4ee2-91cd-67d5994e9fe4`, subvolume UUID `a56bb38e-38bb-4444-89ab-0ade266d9045`, ID 591.
- Replay: `libdisplay-info-20260930T065609Z-4b4b07e5`, PASS, 2,091 Btrfs events, 3,500,751-byte incremental send.
- Output: `/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs/libdisplay-info-20260930T065609Z-4b4b07e5/after-ro`, subvolume UUID `96e46878-e26e-0743-9d67-ad7ae1f833b6`, ID 594.
- Durable ownership ledger: `/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs/libdisplay-info-20260930T065609Z-4b4b07e5/d34-ownership-ledger.json`; COMPLETE at 79/79 official packages, with Linux-PAM, hwdata, and libdisplay-info as three separate supplemental rows and 51,600 final owners.
- All 16 final paths attributed to libdisplay-info, including `di-edid-decode`, headers, shared-library links, pkg-config metadata, and ldconfig state, exist in the output snapshot.
- Package tests and checksum calculations were skipped as defined by the builder and user instruction. The build/install/postconditions passed, including `pkg-config --modversion`, executable/library presence, and `ldd` resolution.

The D34 runner now explicitly accepts the `libdisplay-info`/`build-blfs-libdisplay-info.sh` host pair; reconciliation requires hwdata earlier in the supplemental chain. Targeted D34 validation passed before replay (13 tests, Python compilation, shell syntax, and diff checks). The active `/mnt/lfs` and existing ISO were not the target. This extends candidate provenance by two desktop prerequisites; it does not establish a complete Plasma rootfs or close M06/M07/M09 acceptance.
