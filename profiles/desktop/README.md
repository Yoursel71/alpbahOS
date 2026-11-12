# alpbahOS Desktop Profile — UI-01

Status: **M08 first slice — installable package ready; not yet run in a real Plasma session.** The look-and-feel package, the Atatürk wallpaper, the symbol icon, system defaults and the install script are in the repo. They were written against the Plasma 6.4.4 source code and pass the static tests (`tests/test_m08_desktop_profile.py`, run on 26 September 2026). Nothing counts as "applied" until it has been installed on the Gen2 test image and checked with a screenshot. Details: [015 handoff](../../docs/handoffs/ai/015-m08-lookandfeel-wallpaper-shortcuts.md).

Current design (2026-11-06, not yet run in a real Plasma session): the desktop uses a single bottom panel with a Start menu, the Solid appearance is the default and Glass is an option (D115, D116). Liquid is not in the first release (D116). The look-and-feel defaults use the `alpbahOS-Brand` wallpaper (D114). The Atatürk wallpaper is installed and can be selected (D114). Brand assets: [../../branding/alpbahos-brand/README.md](../../branding/alpbahos-brand/README.md). See the sections below for each item.

## 0. M08 file layout and installation

| Repo path | Install target | Content |
|---|---|---|
| `lookandfeel/org.alpbahos.solid.desktop/` | `/usr/share/plasma/look-and-feel/org.alpbahos.solid.desktop/` | `metadata.json`, `contents/defaults` (color scheme, icon, decoration, wallpaper name), `contents/layouts/org.kde.plasma.desktop-layout.js` (single 44 px bottom panel, D115) |
| `colorscheme/alpbah-dark.colors` | `/usr/share/color-schemes/alpbah-dark.colors` | Color scheme |
| `../../branding/ataturk-theme/wallpaper/alpbahOS-Ataturk/` | `/usr/share/wallpapers/alpbahOS-Ataturk/` | `Wallpaper/Images` package (5 resolutions). Stays installed and selectable (D114) |
| `../../branding/alpbahos-brand/wallpaper/alpbahOS-Brand/` | `/usr/share/wallpapers/alpbahOS-Brand/` | Default alpbahOS brand wallpaper package (D114). The look-and-feel defaults use `alpbahOS-Brand`. See [brand README](../../branding/alpbahos-brand/README.md) |
| `../../branding/icons/hicolor/` | `/usr/share/icons/hicolor/` | `alpbahos` symbol icon (32–256 px, temporary raster) |
| `xdg/kdeglobals` | `/etc/xdg/kdeglobals` | `LookAndFeelPackage=org.alpbahos.solid.desktop` |
| `xdg/kwinrc` | `/etc/xdg/kwinrc` | Solid: blur/contrast effect off |
| `../shortcuts/generated/kglobalshortcutsrc` | `/etc/skel/.config/kglobalshortcutsrc` and `<home>/.config/kglobalshortcutsrc` for each `--user-home` | Windows-familiar shortcuts ([conflicts.md](../shortcuts/conflicts.md)). kglobalacceld does not read `/etc/xdg` (v1 D43) |
| `bin/alpbah-gorunum` | `/usr/bin/alpbah-gorunum` (0755) | Solid/Glass switch tool (§5.1) |

Install: `profiles/desktop/install-desktop-profile.sh --destdir <root> [--datadir /usr/share] [--user-home /home/user ...] [--manifest file]`. The script requires a target root; for `/` it also requires `--allow-live-root`. It does not overwrite a file with different content unless `--force` is given, and it writes the SHA-256 of every file it installs to the manifest. Installing into the `/mnt/lfs` rootfs is the job of the BLFS build chain. Plasma is installed under the `/opt/kf6` prefix, so `/usr/share` must be in `XDG_DATA_DIRS` (a separate `--datadir` can also be given).

Mechanism (from the Plasma 6.4.4 source): on the first session, `startplasma` applies the `contents/defaults` file of the package named in `kdeglobals [KDE] LookAndFeelPackage` to `~/.config/kdedefaults/`. The default wallpaper is read from the `[Wallpaper] Image` key of that same file through `libkworkspace` `DefaultWallpaper`; the lock screen uses the same default. `contents/layouts/...-layout.js` runs only for a new user with no layout, or with `plasma-apply-lookandfeel -a org.alpbahos.solid.desktop --resetLayout`.

Scope: only `profiles/desktop/`. The `pkg` backend, toolchain, kernel, rootfs and the earlier Windows-host VM settings were not touched (history in [docs/archive/](../../docs/archive/)). See also [AGENT.md](../../AGENT.md) and [AGENT_START.md](../../docs/archive/AGENT_START.md). Ready-made KDE/Qt/GTK components are customised; no new compositor or desktop shell is proposed.

Sources: [docs/MASTER_PLAN.md](../../docs/MASTER_PLAN.md) §6–7, [docs/alpbahOS-design-mockups.md](../../docs/alpbahOS-design-mockups.md), [docs/assets/alpbahOS-logo.png](../../docs/assets/alpbahOS-logo.png).

## 1. Global theme (Plasma look-and-feel)

- Package ID: `org.alpbahos.solid.desktop` ([`lookandfeel/`](lookandfeel/org.alpbahos.solid.desktop/metadata.json))
- Parent (fallback) theme: **Breeze Dark** — mature, accessibility support tested, low overhead.
- The package format follows KDE's standard `lookandfeel` layout: `metadata.json` + `contents/{colorscheme,icons,splash,lockscreen,windowswitcher,...}`. No new package format is invented.
- Default profile name: `alpbah-solid` (see MASTER_PLAN §7.1). Glass is an option built from the same token set (see `tokens.json`). Liquid is not in the first release (D116).

## 2. Color scheme

Draft KDE color scheme file: [`colorscheme/alpbah-dark.colors`](colorscheme/alpbah-dark.colors). The values were made by converting hex to RGB from the color tokens in `docs/alpbahOS-design-mockups.md` §3.1. The conversion was done by hand; the import test in System Settings → Colors was **not run**.

| Role | Token | Hex | Use |
|---|---|---|---|
| Window background | `--ab-bg-900` | `#11171c` | Window background |
| View background | `--ab-bg-950` | `#0b1014` | View/terminal background |
| Surface | `--ab-surface-800` | `#16232d` | Card, button background |
| Accent (selection/focus) | `--ab-cyan` | `#00aeef` | Selection, focus decoration, active window border |
| Secondary accent | `--ab-orange` | `#f5a623` | Warnings, primary action button, cursor |
| Text | `--ab-text` / `--ab-text-strong` | `#d4e0e8` / `#f4f8fb` | Body / heading text |

## 3. Icon theme

Open technical choice — **not tested**; two candidates:

1. **Papirus-Dark + `papirus-folders` accent** — easy to turn folder colour to cyan (ready-made tool), wide application coverage. Source: a separate upstream project; source and checksum verification belongs to BLFS under ABI-01/BUILD-01.
2. **Breeze-Dark (tinted)** — no extra dependency, probably already in the LFS/BLFS chain, better suited to the low-RAM target (v1 P08).

Recommendation: start with the Breeze-Dark tint (adds no dependency); evaluate Papirus for visual richness after the measurements against the D135 targets. The decision must be recorded in DECISIONS.md.

## 4. Window decoration

- Base: **Breeze** decoration (customised through the Aurorae/Breeze settings API; no new decoration engine is written).
- Active window border: `--ab-cyan`, `1px` (matches mockup §4.2).
- Inactive window border: `--ab-border` (`#29404f`).
- Corner radius: `10px` (general), buttons/badges `999px` — see `radius` in `tokens.json`.
- No heavy blur or shadow in Solid; Glass uses controlled transparency with its own token set.

## 5. Panel and taskbar

Current design (D115, decided 2026-11-06): a Windows-style **single bottom taskbar**. It is 44 px high, full width and opaque. It holds, left to right: the Kickoff Start menu, the icon task manager (pinned Dolphin, Firefox, Konsole and LibreOffice Writer, plus open windows), a separator, the system tray, the digital clock, and show-desktop at the right end. The top panel and the dock from the mockup are dropped. Firefox and LibreOffice are not packaged yet; they appear as launcher entries only. The layout is in [`layouts/org.kde.plasma.desktop-layout.js`](lookandfeel/org.alpbahos.solid.desktop/contents/layouts/org.kde.plasma.desktop-layout.js). It is a static draft and has **not been run in a real Plasma session**.

Notes on the design:

- Only one Kickoff launcher is added. Plasma's Meta-key handler opens the first `launchermenu` applet only (`shellcorona.cpp`); a second launcher would make the Win key behaviour unclear.
- The mockup's "Applications" item at the end of the dock is not used; the Start menu replaces it.
- The taskbar is opaque, as the Solid profile requires (MASTER_PLAN §7.2). Translucency is left to the Glass option.

Earlier M08 layout (26 September 2026, historical): a 34 px opaque top panel (Kickoff + window list, clock centre, tray right) and a floating centre dock. It was replaced by the D115 layout above. The earlier layout was also not run in a real Plasma session.

Mockup contents from §4.1, not yet implemented: left, small alpbahOS symbol + active app name; centre, date/time; right, network, sound, battery/power, quick settings. Mockup dock order: Terminal, Files, Browser, Settings, App Center, Applications. App Center will be added once the `alp` store UI is ready (PKG-02; Discover with the alp backend, D124).

## 5.1 Appearance profiles: Solid / Glass / Liquid

- **Solid (default):** opaque panels, KWin blur/contrast effect off (`xdg/kwinrc`; the layout script sets `opacity = "opaque"`).
- **Glass (option):** the [`bin/alpbah-gorunum`](bin/alpbah-gorunum) `glass` command turns on blur/contrast in the user's `kwinrc` (`BlurStrength=8`, `NoiseStrength=0`), loads the effects over KWin D-Bus and makes the panels `translucent`. `solid` reverts; `durum` (status) shows the renderer and profile. If KWin reports a software rasterizer (softpipe/LLVMpipe) or non-OpenGL compositing in `supportInformation`, Glass is refused (`--zorla` overrides this). The values are mapped to `tokens.json` → `profiles.*.kde` in the test. Not run in a real session; performance not measured. The current Gen2 test image uses softpipe/VGEM, so Glass is expected to be refused there.
- **Liquid:** not in the first release (D116). Not implemented; the plan and criteria are in [`liquid-prototype.md`](liquid-prototype.md). It is removed from `tokens.json`.

## 6. GTK/Qt mapping

- For GTK2/3/4 sync, use **kde-gtk-config** (a ready-made KDE component).
- For Qt5/Qt6 apps outside Plasma, use **qt5ct / qt6ct** + the **Kvantum** theme, generated from the same colour tokens.
- Caveat from AGENT.md / MASTER_PLAN: one theme package is not assumed to look identical in GTK, Qt and third-party apps. The table below limits the test scope.

### 6.1 Verification status

| Component | Status | Note |
|---|---|---|
| Plasma global theme package | Package written, static test passed; not loaded in Plasma | `lookandfeel/org.alpbahos.solid.desktop/` |
| Color scheme (.colors) | Linked to the package default; import not tested | `colorscheme/alpbah-dark.colors` |
| Icon theme | `breeze-dark` selected (adds no dependency); Breeze icons missing on the Gen2 image (M07 finding) | Papirus deferred until after measurement |
| Window decoration | `org.kde.breeze` selected; Breeze decoration installed on the image not verified | No custom colour setting; colours come from the colour scheme |
| Panel / taskbar | Single bottom taskbar written (D115); not run | Earlier top panel + dock replaced; Latte Dock not used |
| Atatürk wallpaper | Package built, safe-area test passed; not shown in Plasma | `branding/ataturk-theme/wallpaper/`. Selectable theme (D114) |
| alpbahOS brand wallpaper (default) | Package in the repo; look-and-feel defaults use `alpbahOS-Brand`; not yet seen in Plasma | `branding/alpbahos-brand/` (D114) |
| Lock screen | Default wallpaper set; KScreenLocker not built, so it does not run. Planned (D133) | SCREENLOCK-01 |
| Glass profile | `alpbah-gorunum` written, unit tests passed; not run in a session | Liquid not in first release (D116) |
| Welcome app (theme, layout, appearance) | Planned, not started (D121) | First boot |
| Xwayland (X11 apps) | Planned (D132); not in the image | BLFS input, §7 |
| GTK mapping | Draft, not tested | kde-gtk-config plan exists, not run |
| Qt (outside Plasma) mapping | Draft, not tested | qt5ct/qt6ct + Kvantum plan exists |

## 7. Packages the BLFS build must add (BLFS integration input)

The list below is a request list, not an install command. Source and checksum verification must be done on the BLFS side, as AGENT.md requires.

- `plasma-desktop`, `plasma-workspace`, `kwin`, `breeze`, `breeze-gtk`
- For the M08 layout: `breeze-icons` (finding: no icons in panel/launcher), `kirigami-addons` (finding: Kickoff did not open), a font package with Turkish characters (Noto/DejaVu/Liberation; the image had no fonts), `konsole`, `dolphin`, `systemsettings`, a browser (dock launchers), `spectacle` and `plasma-systemmonitor` (shortcuts)
- Preinstalled apps (D127): Kate/KWrite, Okular, Gwenview, Ark, LibreOffice, VLC, Firefox. Dolphin and Konsole are listed above. KDE Edu is not preinstalled.
- Xwayland, so X11 apps run inside the Wayland session (D132)
- KScreenLocker, the screen locker (D133)
- Mesa with real GPU drivers (Intel/AMD/NVIDIA open) plus llvmpipe, which needs LLVM (D134). The NVIDIA proprietary driver is a separate package (D128)
- Discover with the alp PackageKit backend (D124): needs `alp` first
- `kde-gtk-config`
- `qt5ct` or `qt6ct`, `kvantum`
- (Open decision) `papirus-icon-theme` — only if the icon decision goes to Papirus
- (Open decision) `latte-dock` — not needed by the current single-taskbar design (D115); listed only in case the layout decision changes

Not BLFS packages: Steam is supported natively through multilib (D129). Bottles (Flatpak) provides Wine (D130). Flathub is on by default (D125). Microsoft Office is not a target (D131).

## 8. Integration note

UI-01 draft was prepared on branch `ai/desktop-bootstrap` and merged to main ([001](../../docs/handoffs/ai/001-desktop-bootstrap.md)). The M08 first slice is on branch `ai/m08-lookandfeel-shortcuts`; the Gen2 verification steps are in [015](../../docs/handoffs/ai/015-m08-lookandfeel-wallpaper-shortcuts.md).
