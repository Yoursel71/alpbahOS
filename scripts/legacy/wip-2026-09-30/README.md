# WIP import 2026-09-30 (legacy, not reviewed)

## Origin

Uncommitted work found in an old clone on 2026-11-06. The files date from about 2026-09-26 to 2026-09-30 and were imported as-is (work tree of the old clone). They were NOT reviewed and NOT tested in the current Fedora + QEMU setup. They may contain paths for an older build host (`/mnt/lfs`, `/mnt/alpbahOS-data`, and similar). Do not run them as-is.

- Full copy of the old clone: `~/saklanan/alpbahOS-codex-klonu-20261106.tar.gz` (includes doc changes that are not imported here).
- Verification records: `docs/verification/` (35 files, same names as the old clone).
- Everything else: this folder, 290 files, same relative paths as in the old clone.
- `tracked-code-changes.patch`: `git diff` of tracked code (`scripts`, `tests`, `docs/patches`) from the old clone at import time.

## Groups

**PackageKit/Discover backend for alp** (`scripts/packagekit/` alpBackend.py and pk-backend-alp.c, `scripts/install-packagekit-alp-helper.sh`, `scripts/configure-live-packagekit-polkit.sh`, `configs/polkit/`, `tests/test_m08_alp_packagekit_backend.py`): helper and PolicyKit glue for a PackageKit backend that talks to alp. May help D124 (Discover + alp).

**LFS book Ch. 5–10 build scripts** (`scripts/build-lfs-*` with `-pass1`, `-pass2`, `-ch6`, `-ch7`, `-ch8`, `-ch10` suffixes, plus `build-lfs-kernel-ch10.sh`, `configure-lfs-system-ch9.sh`, `prepare-lfs-chroot.sh`, `lfs-build-guard.sh`, `resume-lfs-*`, `install-lfs-*`): one script per package or step, for the LFS base. Reference for the D140 rebuild.

**D34 replay runner and ownership ledger** (`run-d34-package-replay.py`, `resume-d34-package-replay.py`, `d34_reconcile_package_deltas.py`, `preflight-d34-candidate-root.py`, `btrfs_send_ledger.py`, `kf6-d34-package-order.json`, `plasma-d34-package-order.json`, `tests/test_d34_*`, `tests/test_m04_btrfs_send_delta.py`): runs each package install on a Btrfs snapshot, records the delta, and builds a file-ownership ledger. Reference for D141 (install through `alp` so ownership is recorded).

**BLFS helper scripts** (`build-blfs-*`, 136 files, plus `configure-blfs-*`, `rebuild-blfs-shadow-pam.sh`): per-package builds for libraries, Qt/KF6 and Plasma pieces, Mesa and Wayland. Reference for the desktop part of the build.

**Patches** (`docs/patches/`, 3 files): Wayland-only changes to KWin, libkscreen and plasma-desktop 6.4.4. Note: D132 now adds Xwayland, so these Wayland-only patches may be the opposite of the new direction. Check before reuse.

**`tracked-code-changes.patch`**: the tracked-code diff described above. Apply only to a matching base, and only after review.

## Verification records (`docs/verification/`, imported by name)

- D34 BLFS replays: `d34-blfs-alsa-lib`, `-audio-stack`, `-ca-trust-stack`, `-hwdata`, `-libdisplay-info`, `-libdrm`, `-libnl`, `-libpciaccess`, `-libsndfile`, `-libyaml`, `-mesa-python-tools`, `-network-stack`, `-networkmanager-stack`, `-nss-trust`, `-polkit`, `-qt-wayland`, `-wayland-protocols`, `-wayland`, `-wpa-supplicant`, all with `-replay-2026-09-30.md` or `-2026-09-30.md`
- D34 other: `d34-kf6-framework-replay-2026-09-30.md`, `d34-ownership-ledger-recheck-2026-09-30.md`, `d34-plasma-replay-sprint-2026-09-30.md`, `d34-replay-runner-host-integration-audit-2026-09-29.md`
- M04: `m04-btrfs-send-delta-probe-2026-09-29.md`, `m04-btrfs-send-ledger-parser-2026-09-29.md`, `m04-linux-fixture-probe-2026-09-29.md`
- M08 (PackageKit): `m08-htop-prefix-root-cause-2026-09-30.md`, `m08-live-packagekit-auth-runtime-2026-09-30.md`, `m08-package-store-transaction-failure-2026-09-29.md`, `m08-packagekit-path-and-auth-retest-2026-09-30.md`
- M09: `m09-clean-lfs-desktop-integration-audit-2026-09-30.md`
- glibc: `glibc-ch8-check-review-2026-09-26.md`
- **M10 drafts (useful starting points for M10):** `m10-alpha-test-matrix-2026-09-29.md`, `m10-alpha-user-guide-draft-2026-09-29.md`, `m10-known-issues-draft-2026-09-29.md`

## Rules for this folder

- Do not run any script here. Read them, then write new code in the live tree.
- Do not edit these files. Fixes go in new files outside this folder.
- Historical records: keep as written.
