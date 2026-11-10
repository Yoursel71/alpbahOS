# alpbahOS — Decisions (v2)

Date: 2026-11-06. This v2 log was written from a 50-question user review ([handoffs/claude/025-karar-gozden-gecirme-2026-11-06.md](handoffs/claude/025-karar-gozden-gecirme-2026-11-06.md)). Q# in the tables is that review's question number.
Old IDs D01–D56 and P01–P13 are in [archive/DECISIONS-v1.md](archive/DECISIONS-v1.md). They are valid only as history, except where D143 carries a v1 fact forward.

Status labels:

- **Accepted (user)**: the user's explicit choice.
- **Technical choice**: delegated to Claude. A starting approach, not proof that it works.
- **Carried over**: a v1 technical fact that is still valid.
- **Open**: needs a user decision.

"Replaces (v1)" lists the v1 IDs a row supersedes.

## Process and repo

| ID | Status | Decision | Replaces (v1) | Q# |
|---|---|---|---|---|
| D100 | Accepted (user) | Claude is the only agent. Codex is removed from the project: no role split, no ownership tables, no integrator. The user decides and approves. | P11, v1 AGENTS roles, D29 | Q1, Q6 |
| D101 | Accepted (user) | One rule file: CLAUDE.md. AGENTS.md merged into it and deleted. | — | Q2 |
| D102 | Accepted (user) | Live docs are in English. Historical records (handoffs, verification, WORKLOG, archive) stay as written. Replies to the user stay Turkish. | — | Q12 |
| D103 | Accepted (user) | Delivery: commits go straight to `main` on GitHub Yoursel71/alpbahOS (remote `yoursel`), fast-forward only, no force push. Remote `origin` in this clone points to another account and is left untouched; open PR #5 is left untouched. | v1 rule 13 kept | Q8, Q11 |
| D104 | Accepted (user) | Historical Codex-era scripts/tests moved to scripts/legacy and tests/legacy; historical Hyper-V/Windows docs and PowerShell moved to docs/archive and scripts/legacy. Old Codex clone: useful uncommitted work (code and 35 records) imported to scripts/legacy/wip-2026-09-30, full tarball kept at ~/saklanan/alpbahOS-codex-klonu-20261106.tar.gz, clone deleted. Remote codex/* branches tagged archive/codex/* and deleted. Codex CLI on the machine is not touched. | — | Q3, Q4, Q5, Q9, Q10 |
| D105 | Accepted (user) | Long builds and tests may run for hours in the background, overnight included; results are summarised afterwards. The v1 one-hour test limit and the per-session time box are removed. The user still spends about 1–2 h/day. | D42, v1 D15 (time part kept) | Q49 |
| D106 | Accepted (user) | Test environment: Fedora host + QEMU/KVM for daily work; before each release, a USB test on a real PC. | D16, D36 | Q45 |
| D107 | Accepted (user) | Builds stay local. Small CI tests run on GitHub Actions. Release ISOs are uploaded to GitHub Releases. | D18 | Q23 |
| D108 | Accepted (user) | The repo stays private until the first alpha ISO is ready, then becomes public. Every release still needs the user's approval. | D18, M12 gate | Q50 |
| D109 | Accepted (user) | Project code license: GPL-3.0 (LICENSE file). Third-party components keep their own licenses. | — | Q44 |

## Product

| ID | Status | Decision | Replaces (v1) | Q# |
|---|---|---|---|---|
| D110 | Accepted (user) | Product name is exactly `alpbahOS`. | D01 | Q13 |
| D111 | Accepted (user) | Architecture x86_64 with 32-bit multilib (lib32) user space. | D02 kept; reverses D32, D35, P01 | Q33 |
| D112 | Accepted (user) | Target users: schools/education and people moving from Windows. | D03 | Q14 |
| D113 | Accepted (user) | Brand unchanged: mountain/terminal logo, dark navy + cyan + orange. | D05 | Q15 |
| D114 | Accepted (user) | The Atatürk theme becomes a selectable theme (Welcome app / Settings). The default wallpaper and lock screen use the alpbahOS brand. | D09 | Q16 |
| D115 | Accepted (user) | Layout: Windows-style single bottom taskbar with a Start menu. The old top panel + dock mockup is dropped. | D19 | Q17 |
| D116 | Accepted (user) | Appearance: Solid by default, Glass as an option. Liquid glass is removed from the first release. | D10, P04 | Q18 |
| D117 | Accepted (user) | Animations: smooth, fast, customisable. | D25 | Q19 |
| D118 | Accepted (user) | Keyboard shortcuts: Windows-familiar profile (Alt+Tab, Win+D, Win+E, …), generated from one source; v1 D41/D43 implementation notes still apply. | D08 | Q20 |
| D119 | Technical choice (user delegated, said "I don't understand") | Terminal: Konsole + Zsh + zsh-autosuggestions + zsh-syntax-highlighting (already built and verified in chroot). | D06, P03, D45–D47 | Q21 |
| D120 | Accepted (user) | Turkish UI, Turkish Q keyboard, Europe/Istanbul default time zone (changeable). | D20, P12 | Q22 |
| D121 | Accepted (user) | Settings: KDE System Settings plus an alpbah Welcome app on first boot (theme, layout, appearance choices). | D28 | Q24 |
| D122 | Accepted (user) | Package engine: `alp`. | D31, P13 | Q25 |
| D123 | Accepted (user) | Commands `alp install/remove/update`; help and error messages in Turkish; typing `apt install …` prints a hint that redirects to alp. | D07, D11 | Q26 |
| D124 | Accepted (user) | GUI store: KDE Discover with an alp PackageKit backend. (v1 D31 dropped the pacman/alpm Discover path; this is a different path through alp.) | D11 GUI part, PKG-02 | Q27 |
| D125 | Accepted (user) | Flathub is enabled by default. | — | Q28 |
| D126 | Accepted (user) | Updates: stable channel; the user starts updates (no update notifications). | D30, P07 | Q29 |
| D127 | Accepted (user) | Preinstalled apps: Dolphin, Konsole, Kate/KWrite, Okular, Gwenview, Ark (already built) + LibreOffice, VLC and Firefox (default browser). KDE Edu is not preinstalled. | D21 apps part, P09 | Q30, Q31 |
| D128 | Accepted (user) | GPU drivers: open-source Mesa drivers preinstalled; the NVIDIA proprietary driver is a separate package installable with one command/click. | D21 driver part | Q32 |
| D129 | Accepted (user) | Steam: supported natively thanks to multilib (D111). | reverses D35 Steam part | Q33 |
| D130 | Accepted (user) | Wine: provided through Bottles (Flatpak), not a system Wine build. | D22 Wine part, D35 | Q34 |
| D131 | Accepted (user) | Microsoft Office is not a target; LibreOffice handles Word files. | D22 Word part, D23, OFFICE-01 | Q35 |
| D132 | Accepted (user) | Add Xwayland so X11 apps run inside the Wayland session. | closes v1 open "X11" | Q36 |
| D133 | Accepted (user) | Bring back the KDE screen locker (KScreenLocker). | closes v1 open "screen lock" | Q37 |
| D134 | Accepted (user) | Mesa: real GPU drivers (Intel/AMD/NVIDIA open) + llvmpipe (needs LLVM). | closes v1 open "Mesa renderer" | Q38 |
| D135 | Accepted (user) | Hardware target: old x86_64 PC with 4 GiB RAM; idle ≤ 1 GiB design target (measure before publishing as a requirement). | D13, P08 | Q39 |
| D136 | Accepted (user) | Boot: Legacy BIOS and UEFI. | D27 | Q40 |
| D137 | Accepted (user) | First release = live USB + disk installer. | D12 | Q41 |
| D138 | Accepted (user) | Installer: Calamares, graphical, offline, and alongside Windows (dual boot). Real-disk writes need explicit user permission each time. | D26, P10 | Q42 |
| D139 | Accepted (user) | Disk encryption (LUKS) is an installer option in the first release. Secure Boot comes later (users disable Secure Boot for now). | v1 Q10 | Q43 |

## Build and evidence

| ID | Status | Decision | Replaces (v1) | Q# |
|---|---|---|---|---|
| D140 | Accepted (user) | Rebuild the base once on the newest stable LFS with multilib (the exact book version is pinned by D145). The current LFS 12.4 system stays as the working test base until the rebuild boots. | D33 | Q46 |
| D141 | Accepted (user) | During the rebuild every base package is installed through `alp`, so the file-ownership ledger is created automatically. This closes the v1 D34 debt. | D34 | Q47 |
| D142 | Accepted (user) | Test-image deviations (v1 D39, D40, D53, D54, D56) are closed in the rebuild: disabled features are enabled again and trust-on-first-use hashes (v1 D52, D56) are checked again. | D39, D40, D52–D54, D56 | Q48 |
| D143 | Carried over | Still valid technical facts from v1: D37 (Konsole 25.08.3), D38 (Zsh 5.9), D41 (kglobalaccel reload), D43 (shortcut file path via install-desktop-profile.sh), D49 (Dolphin), D50 (wallpaper scale-only crop), D51 (VM session record), D55 (open: `gio open` DBus env issue). See [archive/DECISIONS-v1.md](archive/DECISIONS-v1.md). | — | — |
| D144 | Accepted (user) | The installed system boots with `root=PARTUUID=…` and no initramfs. Implemented by [`scripts/lfs-blfs/calamares/modules/grubcfg.conf`](../scripts/lfs-blfs/calamares/modules/grubcfg.conf): `GRUB_DISABLE_LINUX_UUID=true`, `GRUB_DISABLE_LINUX_PARTUUID=false`. Needs GPT (and `CONFIG_EFI_PARTITION=y`). Proven on a BIOS virtual disk on 2026-11-06: one boot to the login prompt, no override ([verification](verification/m11-d144-partuuid-2026-11-06.md)). | OPEN-1 | — |
| D145 | Accepted (user) | Rebuild pinned to LFS 13.1-systemd, Multilib LFS 13.1 (https://linuxfromscratch.org/mlfs/view/13.1/, systemd edition) and BLFS 13.1-systemd. Key versions: glibc 2.44, GCC 16.2.0, binutils 2.47, Linux 7.1.8, systemd 261.2, Python 3.14.7 ([research](verification/rebuild-r1-lfs-version-2026-11-06.md)). BLFS 13.1 brings newer KDE and Qt than the 12.4 test base, so the desktop profiles must be re-checked after the rebuild. | refines D140 | — |
| D146 | Technical choice | Binary baseline is generic x86-64 (v1). Packages must not be built with `-march=native` or host-detected CPU flags. libffi uses `--with-gcc-arch=x86-64`; GMP uses `--build=x86_64-pc-linux-gnu --enable-fat` with generic CFLAGS; MPFR uses generic CFLAGS. Newer instructions only with runtime dispatch. Every build is audited with `scripts/lfs-blfs/cpu-baseline/audit-isa.sh`. QEMU tests use the default `qemu64` CPU model as the gate. Reason: the old-PC target (D135) cannot run AVX code. The SIGILL on non-AVX CPU models came from libffi built with `-march=native` and GMP/MPFR built for znver3 ([sigill report](verification/sigill-cpu-baseline-2026-11-06.md); fixed boot: [m09-iso-v3 serial log](verification/m09-iso-v3-bios-qemu64-serial-2026-11-06.log); rebuild logs: [cpu-baseline-rebuild-logs](verification/cpu-baseline-rebuild-logs/)). | — | — |
| D147 | Accepted (user) | Network: NetworkManager manages all links (wired and Wi-Fi) with wpa_supplicant 2.12 as the Wi-Fi backend; systemd-networkd and all of its sockets are disabled in r4-root and by the installer (Calamares `services-systemd` with the `units:` list). NetworkManager uses its internal DHCP client and hands DNS to systemd-resolved (`dns=systemd-resolved`). plasma-nm is the panel applet. iwd is not shipped (NetworkManager needs only one backend). Proposed by review, accepted by user 2026-11-10 (NET-FW-01). | — | — |
| D148 | Accepted (user) | The first installed user gets UID 1000: the installer removes the live user (UID 1000) from the target before the `users` step (`shellprocess@live-user`, `target-live-user.sh`) and fails when UID/GID 1000 is not free or any file still belongs to it. The squashfs root `/` is owned by root (build-iso.sh `chown 0:0`, checked with `unsquashfs -lln`); before this, `/` of the live and installed systems belonged to UID 1000. Proposed by review, accepted by user 2026-11-10 (INSTALL-UID-01). | — | — |
| D149 | Accepted (user) | The installer's live cleanup fails hard: removal of the live user, the live polkit rule, the live-only helpers and the sddm autologin user is followed by post-checks (also: no account without a password, `/` owned by root); a failed post-check fails the Calamares job. "Already gone" passes. The cleanup never deletes an account (the live user is removed before the `users` step) and keeps an autologin the user chose in the installer; Calamares refuses `live` as a login name (`user.forbidden_names`). Test hook: the kernel argument `alpbahos.testfail=live-user` or `alpbahos.testfail=live-cleanup` skips the removal so the post-checks must fail; it can only make an install fail. Proposed by review, accepted by user 2026-11-10 (INSTALL-CLEANUP-01). | — | — |
| D150 | Accepted (user) | Firmware: the full linux-firmware release (20261019, sha256 from the signed kernel.org list) is shipped as an alp package, zstd-compressed (`copy-firmware.sh --zstd`; the kernel has `FW_LOADER_COMPRESS_ZSTD=y`), about 1 GB on disk. GPU drivers and the PCIe Wi-Fi drivers are not in the initramfs, so their firmware is loaded from the root file system; dracut adds the firmware of the storage drivers it includes (113 files; live initramfs 43.8 MB to 55.2 MB, installed 54.1 MB). Exception: dracut includes `mt7921s` (SDIO), `mt7921-common` and `mt792x-lib` without firmware; PCIe `mt7921e` is not included. Proposed by review, accepted by user 2026-11-10 (NET-FW-01). | — | — |
| D151 | Accepted (user) | sudo 1.9.17p2 (BLFS 13.1) is installed; members of `wheel` run any command after their own password (`/etc/sudoers.d/10-alpbahos-wheel`, checked with `visudo -c`; Calamares `sudoersGroup: wheel` writes the same rule). root stays locked; pkexec keeps working. Proposed by review, accepted by user 2026-11-10 (SUDO-01). | — | — |
| D152 | Accepted (user) | Swap is zram: one compressed RAM device of half the RAM (at most 4 GiB), zstd, priority 100, started at boot by `alpbahos-zram.service` (`/usr/libexec/alpbahos/zram-swap`, util-linux `zramctl`/`mkswap`/`swapon`), in the live and the installed system. No swap partition (the installer keeps `neverCreateSwap`). Reason: the base already has util-linux and `CONFIG_ZRAM=m`; zram-generator would add a Rust package outside the book for the same result. Proposed by review, accepted by user 2026-11-10 (ZRAM-01). | — | — |
| D153 | Accepted (user) | Firewall: iptables 1.8.13 (BLFS 13.1, legacy x_tables build; BLFS has no nftables page) with `alpbahos-firewall.service` loading `/etc/alpbahos/firewall/rules.v4` and `rules.v6` before the network: inbound DROP except loopback, replies to own traffic, DHCP replies and the ICMPv6 messages IPv6 needs; forward DROP; outbound ACCEPT. On in the live and the installed system. No Plasma settings page: plasma-firewall needs firewalld or ufw, and neither is on this base (FIREWALL-UI-01). Proposed by review, accepted by user 2026-11-10 (FIREWALL-01). | — | — |
| D154 | Accepted (user) | The live session never locks the screen and never suspends on idle (live user only: `kscreenlockerrc` Autolock and LockOnResume off, PowerDevil auto-suspend off). The installed system keeps the KDE defaults. Reason: the live user has no password, so a locked live session cannot be unlocked (seen in round 20). Accepted by user 2026-11-10 (LIVE-LOCK-01, "B ve C ile devam et" after the round 20 report). | — | — |
| D155 | Accepted (user) | Wordmark on dark backgrounds: the mountain/terminal mark is unchanged (D113), but next to it the name is live text "alpbahOS" in Inter Bold, "alpbah" in #f4f8fb and "OS" in #00aeef, instead of the navy wordmark of the logo PNG (unreadable on #0b1014). The mark is cropped from `scripts/rebuild/iso/live/calamares/branding/logo.png` (rows above the wordmark, trimmed) and never enlarged past its native size. Proposed by review, accepted by user 2026-11-10 (master task, section D shared values). | refines D113 | — |
| D156 | Accepted (user) | GRUB boot menu of the installed system uses the alpbahOS theme (`/boot/grub/themes/alpbahos/`, package `alpbahos-grub-theme`): `GRUB_TERMINAL_OUTPUT=gfxterm`, `GRUB_GFXMODE=auto`, `GRUB_THEME` and `GRUB_FONT` set by Calamares `grubcfg.conf`. Fonts are .pf2 files made on the host with grub2-mkfont from Inter 4.1 and JetBrains Mono 2.304 (the target GRUB has no FreeType); both fonts are also installed as alp packages (`font-inter`, `font-jetbrains-mono`, OFL 1.1). Layout as fractions of the screen; menu area of 3 rows (more entries scroll); countdown text assumes a one-digit `GRUB_TIMEOUT` (5). GRUB stays off the serial console, as before. The GRUB entry name follows D110 (`bootloaderEntryName: alpbahOS`). Proposed by review, accepted by user 2026-11-10 (GRUB-THEME-01, review item D1); the look itself waits for the user's screenshot approval. | — | — |
| D157 | Accepted (user) | GRUB entry titles are short: the newest kernel is "alpbahOS", older kernels "alpbahOS (Linux <version>)", the firmware entry "UEFI ayarları" (record `alpbahos-grub-config` takes over `/etc/grub.d/10_linux` and `30_uefi-firmware`, exact edits in `scripts/rebuild/r23/product-r23.py`). Reason: the GRUB 2.14 Turkish catalogue has no translation for these titles, and the long English title is cut on small screens. Decided by Claude under the user's instruction of 2026-11-10 ("/goal: do not stop, finish everything"), after the D1 approval questions. | — | — |
| D158 | Accepted (user) | The installer writes the live display's preferred mode into the installed GRUB: `GRUB_GFXMODE='<WxH>,auto'` (`target-grub-gfxmode.sh`, Calamares `shellprocess@grub-gfxmode` after grubcfg); no connected display found: `auto`. The live ISO menu uses `1024x768,auto` on BIOS and `auto` on UEFI. Reason: GRUB's `auto` falls back to 640x480 without an EDID mode (QEMU, VirtualBox, some old monitors), where the theme's columns overlap (round 22, G1). Same decision basis as D157. | refines D156 | — |
| D159 | Accepted (user) | The live ISO boot menu uses the same GRUB theme (copied from r4-root by build-iso.sh) with the Turkish entry "alpbahOS 0.9 Beta (canlı)" and GRUB's Turkish texts (`tr.mo` on the ISO). Same decision basis as D157. | — | — |
| D160 | Accepted (user) | Boot splash: Plymouth 26.134.222 (upstream release, sha1 checked against the upstream .sha1sum; not in BLFS 13.1) as an alp package, script theme `alpbahos` (`branding/plymouth-theme/`), in the installed initramfs (dracut `45plymouth` with `UseSimpledrm=1`, so no GPU driver enters the initramfs; D150 unchanged), `quiet splash` on the installed kernel line. The live ISO and the DEBUG ISO's installs have no splash (evidence stays readable); Esc shows the boot log. Proposed by review (item D2), accepted by user 2026-11-10; started under the same instruction as D157. | — | — |
| D161 | Accepted (user) | os-prober 1.85 (Debian source, sha256 checked against the .dsc; not in BLFS 13.1) is in the image and `GRUB_DISABLE_OS_PROBER=false` is set by Calamares grubcfg, so the installed GRUB lists Windows and other systems, and Calamares can offer "install alongside" (D138). Found 2026-11-10: GRUB 2.14 disables os-prober by default and the image had none. Decided by Claude under the user's instruction of 2026-11-10 ("/goal: do not stop, finish everything"). | refines D138 | — |
| D162 | Accepted (user) | Section E layers on Breeze, no own widget style or icon set: Inter (UI) and JetBrains Mono (fixed) are the system fonts (`/etc/xdg/kdeglobals`, fontconfig `60-alpbahos-fonts.conf`); the Breeze Plasma style ("default") follows the alpbah-dark scheme carried in `/etc/xdg/kdeglobals` instead of own panel SVGs; KSplash uses the look of the Plymouth splash (look-and-feel `splash/Splash.qml`); window decoration stays Breeze with the scheme colours; icons stay breeze-dark; the installer starts with the KDE platform theme. Same decision basis as D161 (the master task lists E as "only when the user asks"; the /goal instruction is taken as that request). | — | — |

## Open — needs a user decision

| ID | Topic | Options | Source |
|---|---|---|---|
| OPEN-1 (Resolved by D144, 2026-11-06) | Installed system root device: `grub-mkconfig` writes `root=UUID=…`, but the installed system has no initramfs, so the kernel panics. | (a) build a small dracut initramfs without the live hook; (b) set `root=PARTUUID=…` (used in the M11 evidence; needs GPT and `CONFIG_EFI_PARTITION=y`). M11 acceptance depends on this. | [handoffs/claude/024-devir-m11-modul-kosucu-2026-11-06.md](handoffs/claude/024-devir-m11-modul-kosucu-2026-11-06.md), item 3 |

There are no other open user decisions as of 2026-11-06.

## Principles kept from v1 (not re-asked, still valid)

- Build the LFS base from source; customise existing open-source desktop/apps (v1 D04, D14). Do not write a kernel, compositor, browser or dependency solver from scratch.
- User delegated technical choices (v1 D24): proceed with technical choices, revise with reasons when an experiment fails, ask when a choice is the user's.
- Rich driver coverage wanted (v1 D21). Never promise hardware support without tests.

## How to change a decision

1. The user's explicit new choice wins. Claude does not overturn a decision on its own.
2. Add a new row with the next free ID (D163, …). "Replaces (v1)" names the row it supersedes.
3. Mark the old row's status "Superseded by Dxxx". Do not delete it.
4. Update the other live docs (CLAUDE.md, CURRENT.md, README.md, docs/MASTER_PLAN.md, docs/BACKLOG.md) in the same commit.
5. Run `python3 docs/handoffs/claude/tools/check_docs.py` before committing.

## Reversals worth knowing

- 64-bit only → 32-bit multilib and native Steam: v1 D32, D35 → D111, D129.
- Atatürk theme as default → selectable theme; default wallpaper and lock screen use the alpbahOS brand: v1 D09 → D114.
- Top panel + dock → Windows-style bottom taskbar: v1 D19 → D115.
- Liquid glass dropped from the first release: v1 D10, P04 → D116.
- MS Office via Wine dropped; LibreOffice handles Word files: v1 D22, D23 → D131.
- LFS 12.4 pinned → rebuild on the newest LFS with multilib: v1 D33 → D140.
- Hyper-V replaced by Fedora + QEMU, plus a USB test on a real PC before each release: v1 D16, D36 → D106.
- Two agents → Claude as the only agent: v1 P11 → D100.
