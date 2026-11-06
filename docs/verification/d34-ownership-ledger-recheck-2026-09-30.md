# D34 ownership ledger independent recheck — 30 September 2026

## Result

The official LFS 12.4-systemd Chapter 8 ownership replay is complete at **79/79 packages**. I regenerated its event-derived ledger from the preserved successful replay records using:

```sh
python3 scripts/d34_reconcile_package_deltas.py --output /tmp/alpbahos-d34-ledger-recheck.json
```

The regenerated output was byte-identical to the preserved ledger at:

`/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs/e2fsprogs-20260930T025853Z-11f33b5a/d34-ownership-ledger.json`

The canonical recheck result is `COMPLETE`: 79 expected/reconciled packages, zero remaining, 4,520,842 path events, 4,184,340 excluded non-system path events, 51,579 final system-path owners, and one supplemental Linux-PAM 1.7.1 replay with 300 owned paths. Linux-PAM remains supplemental; it is not counted among the official 79.

## Candidate path-presence check

As root, a read-only `os.path.lexists` walk compared every final owner path against the final replay subvolume `.../e2fsprogs-20260930T025853Z-11f33b5a/after-ro`. All **51,579/51,579 paths were present**; 7,147 were symlinks. Root access was required because some candidate directories are mode `0700`; the unprivileged probe could not traverse those paths and was discarded.

No replay, package install, or candidate mutation was performed during this recheck. The reconciliation script reads the preserved event ledger and writes only the `/tmp` output.

## Scope limits

This closes the historical Chapter 8 package-ownership ledger gate. The ledger infers owners from ordered Btrfs create/write/delete events. It does not verify file contents against source artifacts, dependency correctness, or that this separate clean LFS candidate was incorporated into the M06/M07 desktop rootfs or current live ISO. Final rootfs/ISO packaging and runtime acceptance remain separate M09/M10 gates.
