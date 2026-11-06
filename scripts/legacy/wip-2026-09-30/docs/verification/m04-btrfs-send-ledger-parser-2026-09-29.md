# D34 Btrfs send-stream event parser — 29 September 2026

## Result

An initial strict, read-only event parser is implemented in
[`scripts/btrfs_send_ledger.py`](../../scripts/btrfs_send_ledger.py). It checks
the Btrfs stream header/version, command framing and CRC32C, TLV bounds and
duplicates, command-required fields, path traversal, and terminal END record.
It emits JSONL operation metadata and write lengths; it does not apply a stream
or emit file payloads/xattr values.

The framing and CRC behavior follows the upstream
[Btrfs send stream format](https://btrfs.readthedocs.io/en/latest/dev/dev-send-stream.html)
and [btrfs-progs stream reader](https://github.com/kdave/btrfs-progs/blob/devel/common/send-stream.c).

## Evidence

- Fedora 44 unit tests: `python3 -m unittest tests/test_d34_btrfs_send_ledger.py -v` — **9/9 PASS**. Coverage includes v1/v2 data TLVs, valid event extraction, CRC mismatch, truncation, parent-path escape, repeated root records, snapshot-root path restrictions, and timestamp validation.
- Candidate preflight regression tests: `python3 -m unittest tests/test_d34_candidate_preflight.py -v` — **5/5 PASS**.
- Existing 2,101-byte incremental fixture: parser emitted **36 records including END**. The preceding 35 operation counts exactly matched `btrfs receive --dump` from btrfs-progs 7.1: snapshot 1, chown 5, chmod 3, write 2, utimes 10, unlink 3, link 1, rename 3, set_xattr 4, mkfile 1, symlink 1, mkfifo 1.
- Reproduction: `python3 scripts/btrfs_send_ledger.py /mnt/alpbahOS-data/alpbahOS-build/m06-m10-progress-20260929/d34-btrfs-send-20260929T230900+0300/artifacts/incremental-send.bin`.

## Limits / next gate

This verifies only a small synthetic delta and parser behavior. It is not an
installer/process provenance record, a package ownership resolver, a race-safe
transaction runner, or a scale test over a full LFS install. The NVMe candidate
and active `/mnt/lfs` were not modified; Chapter 8 ownership remains **0/79**.
Before any package replay, the runner still needs to hold the common writer lock
through snapshot/install/send/reconciliation, revalidate root identity and mount
boundaries throughout, bind stream snapshot UUIDs to expected base/final roots,
and prove rollback/recovery and full-delta runtime/space costs.
