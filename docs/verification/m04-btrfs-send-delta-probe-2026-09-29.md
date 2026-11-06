# D34 Btrfs delta and candidate preflight — 29 September 2026

**Result: small Btrfs incremental send/receive fidelity fixture PASS; candidate preflight PASS; production replay remains unauthorized by the evidence gates.**

## Incremental send fixture

- Host: Fedora 44 x86_64, Btrfs filesystem UUID `663b4a21-0364-4ee2-91cd-67d5994e9fe4`, btrfs-progs 7.1.
- Command: `M04_RUN_BTRFS_DELTA_INTEGRATION=1 python3 tests/test_m04_btrfs_send_delta.py -v` — **1/1 passed**. The test created disposable Btrfs subvolumes below `/home`, then removed those exact fixtures.
- An incremental stream of **2,101 bytes** represented **11 changed paths**. After `btrfs receive`, a separate tree walk compared entries and matched file content, add/replace/delete, rename, symlink targets, hardlink groups, FIFO type, uid/gid, mode including setuid, mtime, and `user.*` xattrs.
- `btrfs receive --dump` listed the operations in the raw stream, including unlink, rename, write, chown, chmod, utimes, set_xattr, symlink, and mkfifo. The dump is human-readable ancillary evidence; the binary stream remains the replay artifact and the dump format is not treated as a stable ownership-ledger schema.
- Log: [incremental send probe](</mnt/alpbahOS-data/alpbahOS-build/m06-m10-progress-20260929/d34-btrfs-send-20260929T230900+0300/logs/m04-btrfs-send-probe.log>).
- Preserved synthetic artifacts: [raw incremental stream](</mnt/alpbahOS-data/alpbahOS-build/m06-m10-progress-20260929/d34-btrfs-send-20260929T230900+0300/artifacts/incremental-send.bin>), [receive dump](</mnt/alpbahOS-data/alpbahOS-build/m06-m10-progress-20260929/d34-btrfs-send-20260929T230900+0300/artifacts/receive-dump.txt>), and [summary](</mnt/alpbahOS-data/alpbahOS-build/m06-m10-progress-20260929/d34-btrfs-send-20260929T230900+0300/artifacts/summary.json>).

## Candidate identity preflight

- Added [read-only candidate preflight](../../scripts/preflight-d34-candidate-root.py). It requires expected filesystem and subvolume UUIDs, rejects `/`, `/mnt/lfs`, symlinked candidate path components, non-Btrfs roots, UUID mismatch, and nested mountpoints. It takes the common LFS writer lock for the inspection window and records the containing mount ID, subvolume ID/UUID, device and inode.
- On `/home/yrslf/alpbahOS-nvme/d34-candidates/clean-lfs-root-20260929T205800Z`, the preflight verified NVMe filesystem UUID `663b4a21-0364-4ee2-91cd-67d5994e9fe4`, subvolume UUID `c205dbcb-bd1d-4c46-9150-03272bbbf8d6`, subvolume ID 290, containing mount ID 64, and no nested mounts. Candidate inode was 256 on device 93. No install or capture was performed.
- Unit tests: `python3 tests/test_d34_candidate_preflight.py -v` — **5/5 passed**, including active-root refusal, UUID mismatch, nested-mount rejection, and writer-lock exclusion. The real candidate report is [candidate-preflight.json](</mnt/alpbahOS-data/alpbahOS-build/m06-m10-progress-20260929/d34-btrfs-send-20260929T230900+0300/logs/candidate-preflight.json>).

## Limits and next gate

- This proves a small fixture can replay Btrfs metadata and that the candidate identity matches the expected IDs at preflight time. It does **not** prove a full LFS install delta, a race-free walk, exclusive/quiescent-root enforcement after the preflight process exits, a stable parser mapping Btrfs send commands to package ownership, or tolerable time/space cost for all 79 packages.
- The preflight releases the writer lock when it exits. A future transaction runner must hold that same lock across snapshot, install, send, verification, and commit/rollback; it must repeat mount/identity checks and reject any drift.
- Candidate root and active `/mnt/lfs` were not mutated. The M09/D34 canonical event ledger remains **0/79**.
