# D34 BLFS ALSA-lib replay — 30 September 2026

## Result

BLFS ALSA-lib 1.2.14 and its UCM profiles completed in a private D34 replay from the libnl supplemental candidate.

- Input: `libnl-20260930T065833Z-8cdbaa35/after-ro`, filesystem UUID `663b4a21-0364-4ee2-91cd-67d5994e9fe4`, subvolume UUID `f654f282-283a-bd42-9850-2f1842cdfa99`, ID 597.
- Replay `alsa-lib-20260930T070244Z-af1bc471`: PASS; 28,793 Btrfs events and 34,914,023-byte incremental send.
- Output subvolume UUID `e48d3a53-92c8-7846-b18e-8926c6ab22ab`, ID 600.
- Durable ledger: `/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs/alsa-lib-20260930T070244Z-af1bc471/d34-ownership-ledger.json`; COMPLETE, 79/79 official LFS packages, five supplemental entries (Linux-PAM, hwdata, libdisplay-info, libnl, ALSA-lib), and 53,013 final path owners.
- The 1,150 final paths attributed to ALSA-lib all exist in the output snapshot. `libasound.so.2`, `alsa.conf`, and the UCM2 profile tree are present.
- Builder staging and final install postconditions passed, including `ldd` checks. Package tests and checksum calculations were skipped per the existing builder scope and user instruction.

The runner approves only the `alsa-lib`/`build-blfs-alsa-lib.sh` pair and reconciliation accepts the package only after the declared hwdata prerequisite. Fifteen targeted D34 tests passed before replay, along with Python compilation, shell syntax, and diff checks. The active `/mnt/lfs` and ISO were not replay targets. This establishes ALSA candidate provenance, not working live audio or completion of M06.
