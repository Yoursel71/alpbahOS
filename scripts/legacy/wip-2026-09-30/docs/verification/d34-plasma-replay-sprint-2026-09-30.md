# D34 Plasma replay sprint — 30 September 2026

## Scope

Added a sequential D34 Plasma package order and corresponding ownership-ledger gates. Plasma source builds remain inside the runner's private writable snapshot on NVMe; the HDD `/mnt/lfs` root is only used as the runner's protected base.

## Results

- `kdecoration` 6.4.4 PASS: run `20260930T134707Z-bbc9c1df`, after-ro subvolume 1154, UUID `98fcd644-1716-ba4d-b2f4-b3c30d81f951`.
- `breeze` 6.4.4 PASS: run `20260930T134929Z-f6fba400`, after-ro subvolume 1159, UUID `2db1f777-66e1-1b45-8270-22ae5bd15f1d`. Qt5 style was disabled because this root contains Qt6 only.
- Reconciled ledger: COMPLETE, 79/79 Chapter 8, 142 supplemental packages, 121,039 final owned paths. Ledger: `/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs/breeze-20260930T134929Z-f6fba400/d34-ownership-ledger.json`.
- `plasma-activities` attempt `20260930T135052Z-d82b1e15` failed at configure because Boost headers are absent from the D34 root (`Boost_INCLUDE_DIR`). Failed attempts are excluded from the ledger. Add Boost as an ordered supplemental D34 package before retrying.
- Breeze's first attempt failed because its default Qt5 style requires Qt5. The retry with `BUILD_QT5=OFF`, `BUILD_QT6=ON` passed.

The Plasma chain is not complete and this work has not produced a new ISO. No checksum was run. No tests were added or executed; shell and Python syntax checks passed for the changed runner, reconciler, and builder.

## Continuation — KWin prerequisites and current blocker — 30 September 2026

The Plasma chain continued through these successful D34 replays:

- `boost-headers` `20260930T135449Z-c3b62859` (subvolume 1164), `plasma-activities` `20260930T135543Z-de0e2b11` (1167), `kglobalacceld` `20260930T135659Z-bdb1d59a` (1172), `kwayland` `20260930T135718Z-1c56bbb6` (1175), `layer-shell-qt` `20260930T135752Z-a2a00247` (1178), and `libplasma` `20260930T135838Z-d1fd550c` (1183).
- Qt Sensors `20260930T140132Z-f80f6c1e` (1188), libepoxy `20260930T140536Z-b21a8a41` (1193), libevdev `20260930T140613Z-1abaa3fe` (1196), mtdev `20260930T140626Z-db1f55ea` (1199), libinput `20260930T140642Z-16b3f085` (1202), libxcvt `20260930T140719Z-e236c16c` (1207), and LCMS2 `20260930T140824Z-e23dcedf` (1212).
- Current reconciled ledger: COMPLETE, 79/79 official Chapter 8 packages plus 155 supplemental packages, 6,690,817 path events, and 139,209 final system path owners. File: `/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs/lcms2-20260930T140824Z-e23dcedf/d34-ownership-ledger.json`.

KWin initially stopped because common KWin source includes `<xcb/xcb.h>` (`src/cursor.h`); the first compiler log is `/mnt/alpbahOS-data/alpbahOS-build/logs/blfs-12.4-systemd/plasma-kwin-6.4.4-d34-20260930T141235625579552Z.log`. The first xcb-proto attempt (`20260930T142131Z-622b07a0`) did exit with no useful build log because the staged `.pc` check used the wrong directory (`/usr/lib/pkgconfig` instead of `/usr/share/pkgconfig`). That check was corrected. Successful D34 replays now include xcb-proto `20260930T142623Z-d25b16a2` (subvolume 1223), util-macros `20260930T142759Z-7091c2f2` (1228), xorgproto `20260930T142815Z-3c3fd5c4` (1231), libXau `20260930T142852Z-ef2efd22` (1234), and libxcb `20260930T142910Z-52ca8b0c` (1237).

KWin replay `20260930T142948Z-8f9617b1` then compiled past XCB and stopped at `src/inputmethod.cpp` because QtBase's private `qxkbcommon_p.h` was absent. The earlier M07 WORKLOG records that QtBase must be configured with `FEATURE_xkbcommon=ON`; this D34 root already had libxkbcommon, but its QtBase predates that package. A D34 `qtbase-xkbcommon` overlay PASSed as `20260930T144453Z-6ed93f59` (after-ro subvolume 1244, UUID `153c52ab-6ed6-ba47-a430-99542a100038`). It staged 4,053 paths, and the 4,027 existing paths were verified as QtBase-owned by the COMPLETE candidate ledger before replacement. The refreshed ledger is COMPLETE: 79/79 Chapter 8, 161 supplemental packages, 6,729,045 path events, 142,034 final system path owners. KWin replay `20260930T145827Z-92bf3d84` PASSed (after-ro subvolume 1247, UUID `495db1b4-4a46-a04c-9fbd-2ba51a833849`). Reconciliation is COMPLETE: 79/79 official packages +162 supplemental, 6,747,415 path events, 142,034 final system path owners; ledger: `/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs/kwin-20260930T145827Z-92bf3d84/d34-ownership-ledger.json`. The latest existing ISO is `/mnt/alpbahOS-data/alpbahOS-build/artifacts/m10-packagekit-simhelper-20260930/alpbahOS-live-m10-pk-sim-helper.iso` (2,339,700,736 bytes, built at 13:55 TRT); it predates this D34 KWin chain, which has not produced a new ISO. No Ventoy USB is currently enumerated. No checksums or test suites were run.

## Continuation — Plasma Workspace prerequisite discovery — 30 September 2026

- KWin PASS `20260930T145827Z-92bf3d84` is followed by Qt Positioning `20260930T151912Z-1706b52f`, Qt Location `20260930T152026Z-d23632eb`, Qt WebSockets `20260930T152616Z-1a941a4d`, QCoro `20260930T153039Z-ec7f75da`, libkscreen `20260930T153843Z-63ba830b`, Plasma5Support (Wayland-only) `20260930T154000Z-1c06ea7d`, and Plasma Activities Stats `20260930T154147Z-6b207ee0`; all PASSed.
- `plasma-workspace` configuration progressed through those missing dependencies and now identifies `kscreenlocker` / `ScreenSaverDBusInterface` as required. `kscreenlocker` configure attempt `20260930T155029Z-a5471cf9` stopped because target-rootfs `libX11` and `xcb-util-keysyms` are missing; it found the existing libxcb and XTEST components. Existing LFS source archives include libX11 1.8.12, xtrans 1.6.0, and other X libraries; add the required modules as ordered D34 replays, then resume KScreenLocker and Workspace.
- Reconciler gained an explicit terminal-run selector to follow the Btrfs ancestry of a chosen candidate and ignore successful but superseded branches without deleting their artifacts. Latest chain ledger is COMPLETE: 79/79 Chapter 8 +169 supplemental, 6,758,252 path events, 145,213 final path owners; selected terminal `20260930T154147Z-6b207ee0`; two superseded successes excluded: Plasma5Support `20260930T153339Z-7cd7c5a5` and Activities Stats `20260930T153612Z-b2ba4bce`. Ledger: `/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs/plasma-activities-stats-20260930T154147Z-6b207ee0/d34-ownership-ledger.json`.
- The only existing M10 ISO remains `/mnt/alpbahOS-data/alpbahOS-build/artifacts/m10-packagekit-simhelper-20260930/alpbahOS-live-m10-pk-sim-helper.iso` (2,339,700,736 bytes, built 13:55 TRT); it predates these D34 additions. No D34 ISO has been produced, and no Ventoy USB is connected. No checksums or package test suites were run.

## Continuation — X11 build dependencies — 30 September 2026

- Added a reusable D34 X11 library builder and package order entries for `xtrans`, `libX11`, and `xcb-util-keysyms`. Fixed its source-directory path after the first replay stopped before compilation; the failed candidates were preserved and the corrected chain passed.
- `xtrans` PASS `20260930T160224Z-83808e7f` (after-ro subvolume 1305); `libX11` PASS `20260930T160301Z-167d296e` (subvolume 1308); `xcb-util-keysyms` PASS `20260930T160414Z-72e1aa28` (subvolume 1311). All changes are isolated to sequential NVMe replay candidates.
- Reconciled ledger is COMPLETE: 79/79 official Chapter 8 packages +172 supplemental packages, 6,768,744 path events, and 146,470 final system path owners; terminal run `20260930T160414Z-72e1aa28`. Ledger: `/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs/xcb-util-keysyms-20260930T160414Z-72e1aa28/d34-ownership-ledger.json`.
- KScreenLocker and Plasma Workspace remain unresolved; these three X11 packages remove only the missing library/header gates. No refreshed live ISO exists yet. The older M10 ISO above can be selected in Ventoy, but it does not contain this replay chain.


## Continuation — Qt XCB, KScreenLocker, Phonon — 30 September 2026

- QtBase XCB 6.9.2 PASS `20260930T175950Z-be07f6fa` (after-ro subvolume 1358, UUID `38907fd7-572e-264f-89e1-a260b91751e1`); KWindowSystem X11 PASS `20260930T180749Z-ccccaf48` (1361); KScreenLocker PASS `20260930T180914Z-7b95baf3` (1364).
- Workspace required Phonon4Qt6. Added `phonon` before `plasma-workspace` in the D34 package order and a staged NVMe replay builder. Phonon 4.12.0 PASS `20260930T181233Z-16a5766b` (1371). Latest ledger COMPLETE: 79/79 official +184 supplemental, 6,788,574 path events, 147,107 owned paths; ledger is stored in the Phonon run directory above.
- Workspace retry `20260930T181345Z-de0e678c` found the next required target packages: KSysGuard, PolkitQt6-1, and ICU. Continue adding/replaying these dependencies in order before retrying. No fresh ISO exists; the previous M10 ISO remains stale. No checksum or package test suite was run.
