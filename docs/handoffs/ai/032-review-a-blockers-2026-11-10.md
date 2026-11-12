# 032 — Review section A (blockers for the real-PC USB test), round 20, 2026-11-10

Task / status: master task of 2026-11-10 (external review of 24b7c85 + design session), section A only. A1, A2, A3
done and shown in QEMU on ISO r20. Two new findings recorded, not fixed (LIVE-LOCK-01, LOCALE-DEFAULT-01). No
sub-agents were used (the work was package builds, installer changes and boot tests, which the task keeps with the
main agent).

Host, branch and commit: host `thewo` (Fedora); worktree `/home/yrslf/alpbahOS/wt-t2-kisayol`, branch
`ai/t2-kisayol-2026-11-05` (tracks `yoursel/main`). Item commits `bcdb764` (A1), `1854988` (A2), `df76056` (A3),
then the evidence commit with this note.

Changed files:
- `scripts/rebuild/r20/`: `firmware-r20.sh`, `wpa-r20.sh`, `nm-conf-r20.py`, `net-units-r20.sh`, `fw-coverage-r20.py`,
  `a3-chroot-test.sh`, `r20-lanes.sh`, `diag-r20.sh`, `disk-check-r20.sh`.
- `scripts/rebuild/iso/build-iso.sh`, `scripts/rebuild/iso/live/target-cleanup.sh`, new `target-live-user.sh`,
  Calamares `settings.conf`, new `shellprocess_live-user.conf`, `services-systemd.conf` (now `units:`).
- `scripts/rebuild/image/vm-start.sh` (KERNEL/INITRD/APPEND for direct kernel boot).
- `docs/DECISIONS.md` (D147-D150), `docs/BACKLOG.md`, `CURRENT.md`, `docs/verification/review-a-blockers-2026-11-10.md`.
- r4-root (not in Git): records `linux-firmware 20261019`, `wpa_supplicant 2.12`, `networkmanager-alpbahos-r20 0.9-r20`;
  unit symlinks (NM on, networkd off). Snapshot before: `scratch-lfs-bench/r4-snapshots/r4-before-r20-2026-11-10`.

Behaviour (what works now, QEMU only):
- NetworkManager manages wired networking in the live and installed systems; DNS goes through systemd-resolved; the
  plasma-nm applet lists the connection; wpa_supplicant 2.12 and the full linux-firmware are in the image.
- The first installed user has UID/GID 1000; `/` is owned by root; the live user is gone before the users step.
- The live cleanup fails the install when a security post-check fails (test hook `alpbahos.testfail=live-cleanup`).

Checks run and results: see the record, sections 3.1 and 3.2. Summary: chroot exit-code test 7/7; firmware coverage
0 missing (r4-root and squashfs); L1, I1, I2, I1/I2 disk checks, B1D, U1D PASS; F1 forced failure: install stopped at
live-cleanup (disk evidence). Not run on r20: L2-L4, B2, B3, U2, FP, REC1, S1, R1; real hardware.

Logs / screenshots / artifacts: `scratch-lfs-bench/r20/` (build, records, firmware, chroot test, cleanup log),
`scratch-lfs-bench/lfs13-logs/iso-beta-0.9/r20/` (run directories, disk checks, diag outputs). ISO:
`scratch-lfs-bench/images/alpbahos-beta-0.9-2026-11-09-r20.iso`. Test password: `scratch-lfs-bench/test-secrets/r20.pw`
(generated at run time, outside the repo). Space: superseded r13-r18 ISOs and r17/r19 test disks were removed
(`scratch-lfs-bench/r20/space-cleanup.log`).

Known issues and open decisions:
- LIVE-LOCK-01: live session locks after about 5 idle minutes and the live user cannot unlock it. Blocks the real-PC
  USB test. Fix proposal: live-only `kscreenlockerrc` with no autolock and no lock on resume.
- LOCALE-DEFAULT-01: installed time zone America/New_York and en_US LC_* (Calamares defaults), against D120.
- Harness: first-login Alt+Space `konsole` opened System Settings; installed checks now use `diag-r20.sh` (serial text).
- `mt7921s` (SDIO) in the live initramfs without firmware (dracut); not a problem for PCIe cards.
- Push: the round 20 commits are fast-forwarded to `yoursel` main at the end of the session.
- The A3 review fixes (no account deletion in the cleanup, installer-chosen autologin kept, `live` forbidden as a login name) are in the repo and shown by the chroot test only; they are not in ISO r20. Rebuild before the full matrix.
- No-network boot not tested: `NetworkManager-wait-online` is now enabled; add an installed boot with `-nic none` to the full matrix (boot delay or failed unit if something pulls `network-online.target`).
- Kept for the next session: `images/inst-bios-msdos-r20.raw`, `images/inst-uefi-gpt-r20.raw` (installed r20 disks). Removed: `inst-bios-f1-r20.raw` (forced-failure target).

Next single action: fix LIVE-LOCK-01 in build-iso.sh (live user only), build one ISO, run the full matrix
(L1-L4, I1, I2, B1-B3, U1, U2, FP, REC1, S1, R1) with the r20 harness, then start section B in a new session.
