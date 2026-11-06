# D34 BLFS Wayland Protocols replay — 30 September 2026

## Result

Wayland Protocols 1.45 was installed as a separate D34 package delta after Wayland 1.24.0.

- Run: `wayland-protocols-20260930T092233Z-1c418ebd`
- Base: Wayland output UUID `1a1102ea-4b7c-3146-b71d-98dd1412bbf2`, subvolume 725
- Output: UUID `2db4bac5-d861-844c-9f06-bad4b48c393a`, subvolume 728
- Btrfs stream: 9,351 events, 12,504,169 bytes; result `PASS`
- Reconciled ledger: `COMPLETE`, 79/79 Chapter 8 + 31 supplemental, 59,225 final system-path owners
- Wayland Protocols-owned paths: 174/174 found; `xdg-shell.xml` and `viewporter.xml` present

The runner used a private mount namespace and wrote only a disposable NVMe D34 snapshot. Active HDD `/mnt/lfs` and ISO were not changed. The archive's tar listing and targeted D34 tests passed; checksums and upstream package tests were skipped per standing preference.

## Scope

This supplies Wayland XML protocol descriptions for the compositor stack. It does not complete Mesa, Qt/KF6, Plasma, or D34 desktop-to-ISO lineage.
