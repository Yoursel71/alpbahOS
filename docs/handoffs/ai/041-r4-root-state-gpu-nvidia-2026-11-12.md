# 041: r4-root state after rounds 40-41, GPU stack, NVIDIA recipe, host disk (2026-11-12)

For: the other session (rc01/rc02 work, handoffs 037/038) and the next session.

Task / status: rounds 40-41 fixes and the NVIDIA groundwork are in r4-root. Round 40's run stopped at I1 (harness
click), round 41's run stopped in L1 (host disk full); rc02 (other session) covers most rows on the same root.

Host, branch and commit: host `thewo`, worktree `wt-t2-kisayol`, branch `ai/t2-kisayol-2026-11-05`, pushed to
`yoursel` main (this note's commit).

## What r4-root has now (newest first; alp records)

| Record | What | Commit |
|---|---|---|
| `alp-catalog 2026.11.12-v3` | catalogue re-signed with the `nvidia` offer (recipe pinned by recipe_sha256) | a3b4588 |
| `alp-r41b 0.9-trust1.6` | alp.py: recipe `unpack: false`, `@KERNEL_RELEASE@`/`@KERNEL_BUILD@`, TMPDIR, ldconfig/depmod triggers; `/usr/lib/alp/helpers/nvidia-stage.py` | a3b4588 |
| `linux-headers 7.1.8-alpbahos` | `/usr/src/linux-headers-7.1.8-alpbahos`; the `build` link of usr/lib/modules points there (was /sources) | a3b4588 |
| `alp-catalog 2026.11.12-v2`, `alp-r41`, `plymouth 26.134.222-alp1` | handoff 037/038 steps of rc01-root.sh applied to the live root (`r41-root.sh`) | 73d1a90 |
| `netavark 1.17.2`, `aardvark-dns 1.17.1` | handoff 038 (rows 435-436) | 73d1a90 |
| `mesa-glvnd 26.1.7`, `libglvnd 1.7.0` | MESA-01: Intel/AMD drivers, glvnd (rows 433-434) | 9cca367 |
| `calamares-r41`, `alp-kutu-r40b`, `alpbahos-pm-hint-r40`, `linux-firmware-dirlinks` | installer strings, Debian box, apt/dnf/pacman hint, FW-DIRLINK-01 | 31588b0 and earlier |

Both sessions built netavark (rc02 in its snapshot, this session in r4-root): r4-root's records are the ones to keep.
The rc02 snapshot (`r4-snapshots/r4-rc02-2026-11-12`) was taken before linux-headers, alp-r41b and catalogue v3.

## Host disk (2026-11-12 07:23)

`/home` reached 100 % (388 KiB free) while rc02's two installs (19 + 21 GiB) and r41's I1 (20 GiB) were on disk. An
`alp install nvidia` test in a snapshot failed with ENOSPC. Freed with the user's go-ahead ("kullanmadığımız her şeyi
sil"): the alpha, first beta, r25 and images/r39 ISOs; keep-r39's two install images (the r39 ISO stays in
keep-r39); 34 old ISO-source snapshots (prev-r12 to prev-r38, 2026-11-08, klavye, r5fix2); r4-snapshots before-r20
and before-trust; r41's I1 image (its checks are in docs/verification/round-41-2026-11-12/i1-install-checks.txt).
Free afterwards: 74 GiB. Left: `lfs13-snapshots/after-ch11-2026-11-07` and `before-ch11-2026-11-07` (plain
directories, 38 GiB each by du; deleting them was refused by the tool's permission check, the user decides).
Rule for both sessions: an install image is about 19-21 GiB; start one only with at least 40 GiB free, and delete
images when their rows are done.

## Checks run

- r41 ISO (sha256 in round-41 record): I1 install PASS (Kur button found at y 684), installer summary strings in the
  future tense ([screenshot](../../verification/round-41-2026-11-12/installer-summary-r41.png)); installed system:
  `nvidia/gb206 -> gb202` with the GSP files and the alp record, `/usr/bin/apt` hint, netavark, alp-local-bin.sh.
- Not run in r41: L1, I2, Welcome, timing, KSplash, APPS, KUTU, B2 (stopped: disk). rc02's queue covers I1, I2,
  KUTU, U1, ALP, APPS, B1, S1, PLY, KF on the same content minus the headers/NVIDIA work.
- `alp install nvidia` end to end in a snapshot chroot with the sandbox: see the round 41 record (first try:
  ENOSPC; rerun after the cleanup).

## Next single action

Finish the NVIDIA end-to-end check in the snapshot, then a short round on an ISO with linux-headers and catalogue
v3 (Welcome, timing, KSplash, `alp install --dry-run nvidia`), and the real-PC boots (nouveau on sda2 first, then
NVIDIA on a fresh install) at a quiet window, with the user's approval.
