# M04 Linux fixture probe — 29 September 2026, follow-up

**Result: disposable-fixture security gate PASS (7/7); production ownership remains OPEN.**

## Environment and scope

- Host: Fedora 44 x86_64; kernel 7.2.7; Python 3.14.7; Bubblewrap 0.12.0; strace 7.2.
- Unit command: `python3 tests/test_m04_install_event_capture.py -v` — **23/23 passed**.
- Linux integration command: `M04_RUN_LINUX_SECCOMP_INTEGRATION=1 python3 tests/test_m04_linux_seccomp_integration.py -v` — **7/7 passed**.
- Both suites used disposable temporary roots under `/tmp`. No command wrote `/mnt/lfs`, the NVMe candidate root, a VM disk, or an ISO. The LFS writer lock was free before these runs.
- Logs: [unit suite](</mnt/alpbahOS-data/alpbahOS-build/m06-m10-progress-20260929/d34-fixture-hardening-20260929T230000+0300/logs/m04-install-event-unit.log>) and [Linux integration suite](</mnt/alpbahOS-data/alpbahOS-build/m06-m10-progress-20260929/d34-fixture-hardening-20260929T230000+0300/logs/m04-linux-seccomp-integration.log>).

## Changes and evidence

- Integrated the process-tree capture path: Bubblewrap status JSON, `strace -ff --decode-pids=pidns`, descendant trace mapping, PID-qualified trace parsing, and hashes for every raw trace.
- Capture now resolves a write path through symlinks before accepting it as inside the fixture. Absolute, `..`-relative, dirfd-relative, and symlink-mediated writes to host sentinels were denied by the read-only host bind, persisted in the event, and rejected. Sentinels stayed unchanged.
- Mount-related syscalls are included in the trace filter and any attempt invalidates the event. The nested tmpfs probe received EPERM/EACCES and left a persisted rejection event.
- A forced exit-23 installer retained its partial file, before/after delta, stdout, stderr, process tree, trace artifacts, and event manifest; it raised `InstallCommandFailed` as expected.
- Attempts to modify the capture root identity and evidence-store status were denied with EROFS, recorded, and rejected. The existing io_uring denial probe also passed.

## Remaining limits

- This remains a **fixture-only** capture tool. It still refuses `/`, `/mnt/lfs`, and descendants; no Chapter 8 install was replayed and the canonical ledger remains **0/79**.
- These tests do not prove mount-ID stability across the full tree, race-safe descriptor-relative snapshotting, exclusive/quiescent candidate ownership, a complete Btrfs delta/replay design, Alp final-owner projection, or 79-package reconciliation.
- Do not begin candidate replay until those independent production gates and a measured complete-delta method pass. This 7/7 fixture result does not close M04 or M09.
