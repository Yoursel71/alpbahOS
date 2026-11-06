# D34 font and Qt Wayland stack — 30 September 2026

## Result

Extended the preserved NVMe D34 chain after the official LFS 12.4-systemd Chapter 8 sequence. Each package ran in the replay runner; the runner returned `PASS` and produced a read-only output subvolume.

| Package | Version | Replay | Output subvolume | Delta events |
|---|---:|---|---:|---:|
| FreeType bootstrap | 2.13.3 | `freetype-bootstrap-20260930T095059Z-6b37ec65` | 754 | — |
| HarfBuzz | 11.4.1 | `harfbuzz-20260930T095233Z-f12eb554` | 757 | — |
| Fontconfig | 2.17.1 | `fontconfig-20260930T095443Z-cb000cb5` | 760 | — |
| DejaVu fonts | 2.37 | `dejavu-fonts-20260930T095708Z-77662ad2` | 763 | — |
| libpng | 1.6.50 | `libpng-20260930T100000Z-bffb3a10` | 766 | — |
| CMake | 4.1.0 | `CMake-20260930T100620Z-9dda59f0` | 773 | — |
| SQLite desktop runtime | 3.50.4 | `sqlite-desktop-20260930T101348Z-8ebb3bcb` | 778 | — |
| QtBase | 6.9.2 | `QtBase-20260930T101539Z-9fa4a904` | 783 | 412,237 |
| Qt ShaderTools | 6.9.2 | `qtshadertools-20260930T103244Z-4c99ba98` | 786 | 1,012 |
| Qt Declarative (QML/Quick) | 6.9.2 | `qtdeclarative-20260930T103349Z-55c2ca94` | 789 | 37,085 |
| Qt Wayland | 6.9.2 | `qtwayland-20260930T104814Z-1d9e7487` | 792 | 6,900 |

QtBase completed all 1,656 Ninja targets. QtDeclarative completed its build and staged-install checks; Qt ShaderTools and Qt Wayland likewise passed their builder checks. The final Qt Wayland candidate contains `libQt6WaylandClient.so.6`, `libqwayland-egl.so`, Qt Quick, and Qt ShaderTools. DejaVu installed 22 TTF files under `/usr/share/fonts/dejavu`; the builder log reports a Turkish font match to DejaVu Sans.

The event-derived ledger was regenerated at:

`/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs/qtwayland-20260930T104814Z-1d9e7487/d34-ownership-ledger.json`

It reports `COMPLETE`: all 79 official Chapter 8 packages and 47 supplemental packages reconcile in sequence, with 74,886 final system-path owners. A privileged read-only path walk found all 74,886 owner paths in the final `after-ro` candidate. The Qt runtime/plugin paths listed above were also checked directly.

## Scope and remaining work

This is a clean D34 package candidate, not the existing Plasma rootfs or a new live ISO. The separately preserved M07 Gen2 Plasma session and M10 alpha ISO remain independent artifacts; this ledger does not prove those images contain this D34 candidate. The current M10 ISO was not changed. Its 2,339,700,736-byte copy is now stored on the HDD at `/mnt/alpbahOS-data/alpbahOS-build/artifacts/m10-packagekit-simhelper-20260930/alpbahOS-live-m10-pk-sim-helper.iso`. The connected-device inventory showed no Ventoy USB. Completing the desktop candidate still requires reconciling its KDE Frameworks/Plasma/application payload and then running rootfs, initramfs, ISO, and VM acceptance gates. Upstream checksums and upstream `make check` were skipped according to the user's standing instruction.

Failed early attempts remain preserved outside the successful chain and are not counted by the reconciler.
