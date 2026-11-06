# D34 BLFS libsndfile replay — 30 September 2026

## Result

BLFS `libsndfile 1.2.2` built and installed from the ALSA-enabled D34 snapshot.

- Input: `alsa-lib-20260930T070244Z-af1bc471/after-ro`, filesystem UUID `663b4a21-0364-4ee2-91cd-67d5994e9fe4`, subvolume UUID `e48d3a53-92c8-7846-b18e-8926c6ab22ab`, ID 600.
- Replay `libsndfile-20260930T070508Z-3df86952`: PASS; 6,571 Btrfs events, 11,399,521-byte incremental send.
- Output subvolume UUID `cd94cb0e-3e87-a743-8e75-0f434d8c5cd1`, ID 603.
- Durable ledger: `/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs/libsndfile-20260930T070508Z-3df86952/d34-ownership-ledger.json`; COMPLETE, 79/79 official LFS packages, six supplemental entries, 53,057 final owners.
- All 46 final paths attributed to libsndfile exist. `libsndfile.so.1`, `sndfile.h`, and `sndfile-info` are present; the builder's ABI/link checks passed.
- The BLFS GCC-15 source adjustment was applied. Package tests and checksum calculations were skipped per the builder and user instruction.

The runner approves the `libsndfile`/`build-blfs-libsndfile.sh` pair, and the reconciler requires ALSA-lib earlier in the supplemental sequence. Seventeen targeted D34 tests passed before replay, along with Python compilation, shell syntax and diff checks. This records audio-library provenance, not working sound I/O or M06 completion.
