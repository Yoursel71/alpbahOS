# AlpbahOS artifact cleanup audit — 2026-10-03

The frozen cleanup plan at `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/cleanup-root.plan.json` has SHA-256 `67c3b0c8cbd5b660199f60ce30cb7b633d7eae7584782fcad08057c7f55dd675`.

The existing completion receipts report the NVMe cleanup removed 1,222 selected targets with no deferred removals (`cleanup-root-result-removed-targets.json`, SHA-256 `5e6e788a8a19b9fe2257a71e80c52fa74f65a6f366967eadba029192816accd0`). The HDD cleanup removed 93 selected directories with no deferred removals (`cleanup-hdd-result-2026-10-02.json`, SHA-256 `7586048d4434125caa8294c931b74ec5fde1f3c10355ac1dbe385968af9c4b63`). The combined receipt marks both operations complete (`cleanup-final-summary-2026-10-02.json`). The root RPM verification output hash was unchanged across the recorded before/after audit; this records a stable baseline, not a pristine host.

The M09 VirGL ISO was moved from NVMe to `/mnt/alpbahOS-data/alpbahOS-build/artifacts/m09-virgl-desktop-20260929/alpbahOS-live-m09-virgl.iso`; its current 2,339,172,352-byte HDD copy hashes to `7d0fe9cd1188ee37c6d70efd8ccb5371951efbf97b4f965019eda260728cf384`, matching the move receipt.

The frozen plan is now stale for replay because it still requires the removed NVMe M09 source path to exist. Its dry-run correctly refused that changed layout; no cleanup targets were removed during the 2026-10-03 audit. The previous read-only HDD dry-run was interrupted while rehashing retained multi-gigabyte milestones. Do not replay the old plan. Generate and validate a new frozen plan before any additional deletion.

At audit time, `df -h` reported 73 GiB free on `/` (about 15.2%), 46 GiB on `/mnt/alpbahOS-ssd` (about 41%), and 264 GiB on `/mnt/alpbahOS-data` (about 58%). The temporary builder VM was powered off cleanly. KDE remained running (`kwin_wayland` and `plasmashell`).
