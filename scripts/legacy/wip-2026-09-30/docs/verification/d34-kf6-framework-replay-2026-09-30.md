# D34 Qt/KF6 continuation — 30 September 2026

## Result

The NVMe D34 candidate now contains QtBase 6.9.2, Qt ShaderTools, Qt Declarative, QtWayland, ECM 6.17.0, Qt SVG, Qt Tools, Plasma Wayland Protocols 1.18.0, XKeyboardConfig 2.45, libxkbcommon 1.11.0, Aspell 0.60.8.1, and the first 30 of 68 ordered KDE Frameworks 6.17.0 packages. The latest successful snapshot is `kglobalaccel-20260930T122457Z-31099984/after-ro` (Btrfs subvolume 943, UUID `67b4dd76-bfa4-484d-a424-830401919b42`) on NVMe filesystem `663b4a21-0364-4ee2-91cd-67d5994e9fe4`.

The ownership ledger regenerated from the complete sequential replay chain is `COMPLETE`: 79/79 official LFS Chapter 8 packages plus 88 supplemental packages, 6,261,288 path events, and 83,356 final system-path owners. A root-level read-only presence check found 83,356/83,356 paths, including DocBook XML/XSL/catalogs, Perl `URI::Escape`, KDocTools, KPty, and KDE Frameworks through KGlobalAccel. This is a package-owned D34 candidate, not yet the clean M09 desktop rootfs or release ISO.

## New build wiring

`scripts/build-blfs-plasma-wayland-protocols-d34.sh` adds Plasma Wayland Protocols as its own isolated snapshot delta. `scripts/build-blfs-xkb-d34.sh` separately replays XKeyboardConfig and libxkbcommon; `scripts/build-blfs-aspell-d34.sh` adds the Sonnet spelling backend. The reconciler enforces Plasma protocols before KGuiAddons, XKB runtime before KWindowSystem, and Aspell before Sonnet. The targeted D34 supplemental suite now passes 50/50; shell syntax and Python compilation pass.

KGuiAddons' first attempt exposed the missing candidate protocol package and is preserved as failed run `kguiaddons-20260930T113137Z-a4b86fdf`; it made no successful package delta. The protocol package then passed in `plasma-wayland-protocols-20260930T113453Z-4ebc0afe`, after which KGuiAddons passed in `kguiaddons-20260930T113504Z-5912c1aa`.

The subsequent PASS packages include KDNSSD, KI18n, KIdleTime, KImageFormats, KItemModels, KItemViews, KPlotting, KWidgetsAddons, KWindowSystem, NetworkManager-Qt, Solid, and Sonnet. KIdleTime, KItemModels, and KItemViews had initial download resets; preserved source archives were copied into the HDD downloads area and the replays passed. KWindowSystem first exposed the missing libxkbcommon dependency; Sonnet first exposed the missing Aspell backend. Each dependency was added as a separate D34 delta and the consumers then passed. The first Aspell stage identified shared `/usr/share/info/dir`; that file was backed up before allowing Aspell's index update. Failed attempts are preserved and excluded from the successful ownership chain. No checksum calculations or upstream package test suites were run.

## DocBook/KDocTools continuation — 30 September 2026, 15:16 TRT

`threadweaver`, `kauth`, `kcompletion`, and `kcrash` each passed as sequential package deltas after Sonnet. KDocTools initially stopped during CMake configuration because the candidate lacked DocBook DTD/XSL and Perl `URI::Escape`. Added package-owned D34 replays for DocBook XML 4.5, DocBook XSL 1.79.2 plus the BLFS stack fix, XML catalogs, and Perl URI 5.32. Each passed staged-path collision checks; shared `perllocal.pod` was excluded from the URI module payload. KDocTools 6.17.0 then configured with the DTD/XSL and built/installed successfully. The failed first attempt and subsequent fixed attempts remain preserved; failed runs are excluded from the ledger.

The supplemental reconciler now requires all four prerequisites before KDocTools and the focused regression suite passes 50/50. Source archives were already present on the LFS source cache and copied to the build downloads directory where needed. No checksum calculations or upstream package test suites were run. KPty, KUnitConversion, KColorScheme, KConfigWidgets, KService, and KGlobalAccel passed as ordered framework deltas (packages 25–30). The regenerated ledger and zero-missing root-level read-only path scan are stored alongside the latest candidate. Active HDD `/mnt/lfs` and the existing M10 ISO remain untouched.

## Scope and next step

All successful package deltas in this checkpoint are NVMe D34 Btrfs snapshots. The active SATA `/mnt/lfs` root and existing M10 ISO were not changed. The ISO still does not contain these D34 additions. Continue the approved KF6 sequence at `kpty`, then finish the remaining KDE Frameworks and Plasma payload before clean M09 rootfs/ISO integration and BIOS/UEFI acceptance.
