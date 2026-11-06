# M09 clean LFS to desktop-rootfs integration audit — 30 September 2026

## Current state

The D34 final `after-ro` subvolume is a clean, package-owned LFS Chapter 8 base plus supplemental audio/network/authorization, font, Qt, XKB, spell-check, and a partial KF6 chain. Since the original inventory below, QtBase 6.9.2, Qt ShaderTools, Qt Declarative, QtWayland, ECM, Qt SVG, Qt Tools, Plasma Wayland Protocols 1.18.0, XKeyboardConfig 2.45, libxkbcommon 1.11.0, Aspell 0.60.8.1, and 30 KF6 6.17.0 modules have been replayed. DocBook XML/XSL/catalogs and Perl URI::Escape were added as four build prerequisites (including the catalog package). The latest candidate is `kglobalaccel-20260930T122457Z-31099984/after-ro` (subvolume 943); its COMPLETE ledger has 79 official packages +88 supplemental packages, 6,261,288 path events, and 83,356 final owners. A privileged read-only check found 83,356/83,356 owned paths. The inventory table below records an earlier pre-Qt/KF6 comparison and is historical. The active SATA `/mnt/lfs` tree and NVMe M10 ISO extraction tree remain separate lineages.

| Payload marker | D34 final candidate after libdrm | Active `/mnt/lfs` | ISO extraction tree |
|---|---:|---:|---:|
| `/opt/kf6/bin/startplasma-wayland` | absent | present | present |
| `/usr/lib/systemd/user/pipewire.service` | present | present | present |
| `/usr/lib/systemd/user/wireplumber.service` | present | present | present |
| `/usr/lib/libdrm.so` | present | present | present |
| `/usr/lib/libwayland-client.so` | present | present | present |
| `/usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml` | present | present | present |
| `/usr/lib/libyaml.so` | present | present | present |
| `/etc/NetworkManager` | present | present | present |
| `/etc/pki/tls/certs/ca-bundle.crt` | present | absent | absent |
| `/etc/ssl/certs` regular-file count | 172 | 516 | 516 |
| `/usr/share/wallpapers` | absent | absent | present |
| `/usr/share/fonts` file count | absent | 58 | 58 |
| `/usr/share/icons` file count | 3 | 28,417 | 28,677 |
| `/usr/lib/systemd/system/sddm.service` | absent | absent | absent |

The ISO extraction has the desktop payload, but these checks establish presence only. No provenance record shows it was assembled from the D34 final candidate. The clean D34 candidate is not yet an M09 desktop rootfs; the active LFS tree and ISO extraction are not substitutes for that missing integration evidence.

## Build-path constraint (rechecked 30 September)

The earlier description that the runner accepts only Chapter 8 scripts is stale. `scripts/run-d34-package-replay.py` supports an explicitly allowlisted `--script-kind host` mode; the allowlist currently covers 26 supplemental BLFS builders/configuration steps. `scripts/lfs-build-guard.sh` recognizes the inherited lock FD and validates the exact private `/mnt/lfs` mount and Btrfs subvolume identity, so these selected host builders can run against a disposable D34 snapshot.

That support does not yet complete the desktop lineage. The allowlist now includes separate Qt, ECM, Plasma protocol, and KF6 builders, but the 68-entry KF6 package sequence is only partially complete; Plasma, SDDM, theme/wallpaper payload integration, and clean ISO lineage are still missing. The ISO extraction and active LFS root only prove that their files exist there, not that they descend from the D34 base.

## Next required implementation

Continue the ordered KF6 chain from `kwindowsystem`, then add the remaining Plasma/SDDM and desktop payload through package-owned snapshot deltas. Keep one package/configuration unit per snapshot delta. Prove each replay's ledger and installed paths, then use the resulting desktop-integrated descendant as the source for a clean M09 rootfs, initramfs, and ISO rebuild.

The libpciaccess pilot changed only its disposable NVMe working snapshot and produced the recorded after snapshot/delta. Active `/mnt/lfs` and the current ISO were not modified. M06/M07 infrastructure and VM boot evidence still exist, but clean-candidate integration and final M09 lineage remain **OPEN**.
