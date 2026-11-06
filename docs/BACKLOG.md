# alpbahOS — Backlog (v2, 2026-11-06)

Single agent: Claude (D100), so there is no owner column. Decisions are cited by ID from [DECISIONS.md](DECISIONS.md). The v1 task table is kept in [archive/BACKLOG-v1.md](archive/BACKLOG-v1.md).

Statuses: **Not started**, **In progress**, **Partial**, **Done**, **Blocked**. "Done" needs the acceptance test to be run and recorded. "Partial" means some of the acceptance is proven and the rest is listed in the task.

## Open tasks

| ID | Task | Depends on | Acceptance | Status | Decision |
|---|---|---|---|---|---|
| OPEN-1 | Installed-system root device: choose (a) small dracut initramfs without the live hook, or (b) `root=PARTUUID=…` with GPT and `CONFIG_EFI_PARTITION=y` | User | User picks an option; choice written to DECISIONS.md; M11 acceptance can then proceed | Blocked | OPEN-1 |
| M11-FIX-01 | Calamares follow-ups from handoff 024 items 1, 2, 4, 5: add `grubcfg` to settings.conf; `kernelSearchPath` = `/boot`; unpackfs must fail (not return 0) when squashfs is missing; `rsync` and `unsquashfs` present on the live ISO | M11 BIOS run | Each item changed in `scripts/lfs-blfs/calamares/`; runner run on a new target image shows the fixes; ISO tool check passes | Not started | D138 |
| M11-FIX-02 | `systemd-oomd` and `systemd-resolved` namespace errors (handoff 024 item 6), root cause unknown | M11 BIOS boot | Cause found and written to a verification note; `systemctl --failed` is empty on the installed test target | Not started | D138 |
| M11-UEFI-01 | Install and boot with OVMF on a virtual disk with an ESP | OPEN-1, M11-FIX-01 | UEFI install on a new image completes; boots to a login prompt; log saved under docs/verification/ | Not started | D136, D138 |
| INSTALL-DUALBOOT-01 | Install alongside Windows on virtual disks, Windows partitions kept | M11-UEFI-01 | Test disk with a Windows-like partition set survives install; boot menu lists both; no real disk written | Not started | D137, D138 |
| INSTALL-LUKS-01 | LUKS encryption as an installer option | M11-FIX-01, OPEN-1 | Install with LUKS on a new test image; boot asks for passphrase; passphrase never stored in repo | Not started | D139 |
| REBUILD-R1 | Pin the newest stable LFS book version with multilib (lib32) | — | Exact book version, URLs and checksums recorded in docs; choice logged in DECISIONS.md | Not started | D140, D111 |
| REBUILD-R2 | Build the toolchain for the pinned version | REBUILD-R1 | Toolchain build logs and test results recorded; critical test failures not hidden | Not started | D140 |
| REBUILD-R3 | Install every base package through `alp` so the file-ownership ledger is created | REBUILD-R2 | Every base package has an `alp` database record; ownership check passes; no unowned base files | Not started | D141, D122 |
| REBUILD-R4 | BLFS/KDE rebuild with features that were disabled in the test image re-enabled; trust-on-first-use hashes checked again | REBUILD-R3 | Feature list diff against test image recorded; every source hash verified against upstream | Not started | D142, D140 |
| REBUILD-R5 | Parity boot of the rebuilt base on BIOS and UEFI | REBUILD-R4, M11-UEFI-01 | Both boot modes reach login and network on a new image; logs saved | Not started | D136, D140 |
| XWAYLAND-01 | Xwayland so X11 apps run in the Plasma Wayland session | REBUILD-R4 or current base | X11 test app starts in the Wayland session in QEMU; `--xwayland` is present in the session command line (see WORKLOG, Plasma section) | Not started | D132 |
| SCREENLOCK-01 | Bring back KScreenLocker (`KWIN_BUILD_SCREENLOCKER` is OFF in the current build) | Qt/X11 greeter dependencies decided | Lock and unlock work in the Wayland session in QEMU; lock screen uses the brand default (THEME-01) | Not started | D133, D114 |
| MESA-01 | Mesa with real drivers (Intel, AMD, NVIDIA open) plus llvmpipe (needs LLVM) | REBUILD-R2 | Driver list and build options recorded; llvmpipe renders in QEMU; no hardware support claimed without a test | Not started | D134, D128 |
| NVIDIA-PKG-01 | NVIDIA proprietary driver as a separate `alp` package, one-command install | ALP-TR-01 (alp CLI), REBUILD-R3 | Package installs and removes through `alp` on a test image; GPU test not run unless done on real hardware | Not started | D128 |
| LAYOUT-01 | Windows-style single bottom taskbar with Start menu; old top panel and dock dropped | — | Screenshot in QEMU shows bottom taskbar and Start menu; screenshot saved in docs/verification/ | Not started | D115 |
| WELCOME-01 | alpbah Welcome app on first boot: theme, layout, appearance choices | LAYOUT-01 | First boot shows the app; choices are applied in Plasma; tested in QEMU | Not started | D121, D114, D116 |
| THEME-01 | Atatürk theme selectable; brand default wallpaper and lock screen (mountain/terminal logo, navy/cyan/orange) | WELCOME-01 | Theme switch works; default wallpaper and lock screen show brand assets; asset source and licence recorded | Partial | D114, D113 |
| GLASS-01 | Solid default, Glass as option; Liquid glass removed from first release | PERF-01 (for any Glass claim) | Solid is default in profile; Glass switch works; no Liquid profile in release files; Glass claims only with measured data | Partial | D116 |
| STORE-01 | Discover with an alp PackageKit backend; start from `scripts/legacy/wip-2026-09-30` | ALP-TR-01 | Install and remove a package from Discover in QEMU; same database and lock as the CLI | Partial | D124, D122 |
| FLATHUB-01 | Flathub remote enabled by default | STORE-01 | Fresh test image lists Flathub; one Flatpak installs from the Discover view; source shown to user | Not started | D125 |
| ALP-TR-01 | Turkish help and error messages in alp; `apt install` prints a hint that points to alp | — | `alp` help and errors are Turkish in a test run; `apt install …` prints the alp hint; test output saved | Not started | D123, D120 |
| APPS-01 | Preinstall LibreOffice, VLC and Firefox (default browser) with the six apps already built | ALP-TR-01 for installs | Each app installs on the test image; default browser and media MIME set; open test per app recorded | Partial | D127, D131 |
| STEAM-01 | Steam client supported natively through multilib | REBUILD-R1 to REBUILD-R3 | Steam client starts on the rebuilt multilib image; run recorded | Not started | D129, D111 |
| BOTTLES-01 | Wine through Bottles (Flatpak), not a system Wine | FLATHUB-01 | Bottles installs from Flathub; one Windows test program runs; no Word compatibility claimed | Not started | D130, D131 |
| LIVE-01 | Hybrid live ISO that boots BIOS and UEFI | M11-UEFI-01, APPS-01 | BIOS and UEFI both boot the ISO to a live session with network; logs saved | Partial | D137, D136 |
| ALPHA-01 | First alpha: test report, checksums, GitHub Release; repo public only with user approval | LIVE-01, INSTALL-DUALBOOT-01 | Test report, SHA-256 list and release notes written; user approves release and visibility change | Not started | D107, D108 |
| BETA-01 | Real-PC USB tests before each release | ALPHA-01 | Device list and results from a real PC recorded; run by the user with Claude's checklist | Not started | D106 |
| DOCS-EN-01 | Translate component READMEs in `profiles/` and `docs/handoffs/claude/alp-prototype/` to English | — | Every listed README in English; no Turkish-only live docs left in those folders | Not started | D102 |
| PERF-01 | RAM and frametime measurement against the 4 GiB target (idle at or below 1 GiB design target) | LAYOUT-01 or current base | Measurement run with the tools in `profiles/perf/`; results recorded; target stated as a requirement only if measured | Partial | D135, D116 |
| IMAGE-01 | Release image hygiene: unique machine-id, SSH host keys made on first boot, no test accounts, keys or test fonts | M09 image rules | Scan of the release image finds no test account, embedded key or password; first-boot check passes | Not started | D135, D108 |

## Suggested order

1. Installer track: OPEN-1 (user) -> M11-FIX-01 -> M11-FIX-02 -> M11-UEFI-01 -> INSTALL-DUALBOOT-01 -> INSTALL-LUKS-01.
2. Base track: REBUILD-R1 -> R2 -> R3 -> R4 -> R5. STEAM-01 and NVIDIA-PKG-01 wait for the multilib rebuild.
3. Desktop track (can run beside 1 and 2): LAYOUT-01 -> WELCOME-01 -> THEME-01, SCREENLOCK-01, XWAYLAND-01, MESA-01.
4. Store track: ALP-TR-01 -> STORE-01 -> FLATHUB-01 -> BOTTLES-01; APPS-01 uses the same alp path.
5. Release track: LIVE-01 -> ALPHA-01 -> BETA-01, with IMAGE-01 checked before any release image is built.

## Blocked on the user

- OPEN-1: root device option for the installed system (blocks M11 acceptance and everything after it in the installer track).
- ALPHA-01: release and repository visibility change need explicit approval (D107, D108).
- BETA-01: needs a real PC and the user's own USB test.
- Any write to a real disk, partition or boot entry: per action, with explicit permission (D138). These are not tracked as tasks.

## Rules for this file

- A status moves to Done only when the acceptance test was run and its log is linked from the Done section or from the task.
- Partial rows list what is still missing in the Task or Acceptance column.
- New tasks take the next free ID in their group and cite a decision ID. If no decision exists, add an OPEN item instead.
- Test results are recorded with environment (host, chroot, QEMU VM, target), command, result and log path (CLAUDE.md section 7).

## Done (selected)

Status is taken from the evidence named. Nothing here is "Done" unless the row says so.

| Item | Status | Evidence |
|---|---|---|
| LFS 12.4 base boots, BIOS and UEFI (M05) | Partial | Boot evidence in [M1_BOOT_VERIFICATION.md](M1_BOOT_VERIFICATION.md) and [WORKLOG.md](WORKLOG.md) (M05 entries); package-ownership ledger now comes from the rebuild (D141, was v1 D34) |
| BLFS / Plasma 6.4.4 Wayland session | Partial | [handoffs/claude/023-devir-m11-m09-2026-11-06.md](handoffs/claude/023-devir-m11-m09-2026-11-06.md); session gap noted in WORKLOG (`--xwayland` not in session command) |
| T2 shortcuts, 19 of 20 pass in VM | Partial | Commit `8e674a4`; handoff 023 |
| T3 Zsh with suggestions, acceptance, Ctrl+C, typo fix | Done (chroot and VM) | [verification/t3-zsh-chroot-2026-11-05.md](verification/t3-zsh-chroot-2026-11-05.md); commits `29cfab9`, `350d623`; handoff 023 |
| T5 `alp` install, run and remove htop in chroot and VM | Done (chroot and VM) | [verification/t5-alp-htop-chroot-2026-11-05.md](verification/t5-alp-htop-chroot-2026-11-05.md); commits `fa3d908`, `ebb6624` |
| T6 apps: MIME defaults; Dolphin, Okular, KWrite open | Partial | [verification/t6-apps-deps-2026-11-05.md](verification/t6-apps-deps-2026-11-05.md); `gio open` path partial (D55, commit `b30b443`) |
| M09 live ISO opens with BIOS; `alplive` overlay and installer source visible | Partial | [verification/m09-live-iso-2026-11-05.md](verification/m09-live-iso-2026-11-05.md); commit `38bf6a9`; UEFI not run |
| M11 BIOS install on a virtual disk, serial login prompt reached | Partial | [verification/m11-module-runner-2026-11-06.md](verification/m11-module-runner-2026-11-06.md); [handoffs/claude/024-devir-m11-modul-kosucu-2026-11-06.md](handoffs/claude/024-devir-m11-modul-kosucu-2026-11-06.md); commits `86d113a`, `9539a5e`; OPEN-1 still open |
| Calamares 3.3.14 chain built in chroot | Done (build only) | Commit `35dfa87` (D56); [verification/m11-calamares-chain-2026-11-05.md](verification/m11-calamares-chain-2026-11-05.md) |
| Tag `v0.1.0-alpha.1` | Partial | Tag exists; it has no ISO, so it is not the first alpha (ALPHA-01) |
| LICENSE (GPL-3.0) | Done | [LICENSE](../LICENSE), standard FSF text (D109) |
| Single-agent restructure, decision review v2, English core docs | Done (2026-11-06) | [DECISIONS.md](DECISIONS.md), [handoffs/claude/025-karar-gozden-gecirme-2026-11-06.md](handoffs/claude/025-karar-gozden-gecirme-2026-11-06.md) (D100–D104) |
</content>
