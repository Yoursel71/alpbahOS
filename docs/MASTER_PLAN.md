# alpbahOS — Master plan (v2, 2026-11-06)

alpbahOS is a Linux desktop for schools and for people moving from Windows. It is built from source on a Linux From Scratch (LFS) base with BLFS, uses KDE Plasma on Wayland, and ships with its own package command (`alp`), a Windows-style taskbar, Turkish defaults and a graphical installer. The product name, target users, brand and build approach are set in D110–D113. This v2 plan follows the user's 50-question decision review of 2026-11-06 and replaces the v1 plan. The decisions are listed in [DECISIONS.md](DECISIONS.md) (v1 IDs are in [DECISIONS-v1.md](archive/DECISIONS-v1.md)). The old plan is kept as [archive/MASTER_PLAN-v1.md](archive/MASTER_PLAN-v1.md) and is history only.

Status values in this file come from the handoffs, verification records and commits. Anything not recorded is marked "not verified" or "not started".

## 1. Product goal and first release

### 1.1 Goal

A PC that works out of the box for daily tasks: documents, web, files, media, school software and simple app installs, with a Windows-familiar layout and shortcuts. Target hardware is an older x86_64 PC with about 4 GiB RAM (D135). Both Legacy BIOS and UEFI boot are required (D136). Turkish UI, Turkish Q keyboard and the Europe/Istanbul time zone are defaults that the user can change (D120).

Audiences (D112):

- Schools and education: shared lab machines, several accounts, lock screen, LibreOffice documents.
- People moving from Windows: taskbar, Start menu, Alt+Tab, Win+D, Win+E, file manager, simple app installs.

### 1.2 First release (v0.2-alpha target)

The first release is a **live USB image plus a graphical disk installer** (D137, D138):

- Live USB/ISO boots on BIOS and UEFI and starts the desktop without touching internal disks.
- Calamares installer, offline, can install next to Windows (dual boot). Every real-disk write needs the user's explicit permission for that action (D138).
- LUKS disk encryption is an installer option (D139).
- Preinstalled apps and drivers as in sections 5, 10 and 11.

Not in the first release:

| Item | Decision | Note |
|---|---|---|
| Liquid glass effect | D116 | Glass (blur, opaque fallback) is the only appearance option. Liquid may come later after a prototype and measurements. |
| Microsoft Office | D131 | Not a target. LibreOffice handles Word-format files; no Word compatibility is promised. |
| Secure Boot | D139 | Users disable Secure Boot for now. Signing is later work. |
| KDE Edu apps | D127 | Not preinstalled. |

Steam (D129) and Bottles for Windows apps (D130) are in the plan but have no passing test yet. They are not promised for the first release until they are tested (see section 11).

## 2. Architecture

| Layer | Choice | Decision | State (2026-11-06) |
|---|---|---|---|
| Base system | LFS 12.4-systemd test base, with BLFS 12.4 packages. The base is rebuilt once on the newest stable LFS book with multilib (lib32), pinned to LFS 13.1-systemd, Multilib LFS 13.1 and BLFS 13.1-systemd. | D140, D145, D111, D33 (v1) | Test base is LFS 12.4, 64-bit only. Rebuild pinned to LFS 13.1 (D145); rebuild not started (section 9). |
| Init | systemd | D33 (v1) | In use. |
| Kernel | Linux 6.16.1 (current test base), with squashfs and overlay for the live image | D143, handoff 023 | In use in QEMU. Final kernel version for the rebuild not chosen. |
| Boot | Legacy BIOS and UEFI through GRUB | D136 | BIOS: installer test, installed boot and live ISO boot checked in QEMU. UEFI: live ISO booted in QEMU (earlier ISO build); UEFI install to a virtual disk passed (M11-UEFI-01, 2026-11-06). |
| Desktop | KDE Plasma 6.4.4, Wayland session, Xwayland | D132, D143 | Plasma Wayland session runs in QEMU. Xwayland process seen. X11 app run not tested. |
| Screen locker | KScreenLocker | D133 | Not verified. |
| Graphics | Mesa with real drivers (Intel/AMD/NVIDIA open) and llvmpipe (needs LLVM) | D134, D128 | Build script enables LLVM for llvmpipe. Runtime not verified. |
| NVIDIA | Separate proprietary package, one command or click | D128 | Not started. |
| Package engine | `alp` (command set in section 5) | D122, D123 | Prototype. Install, run and remove of htop verified in chroot and in VM. |
| Store | KDE Discover with an alp PackageKit backend | D124 | Draft and one run on 2026-09-30. Not passing (section 5). |
| Software source | Flathub enabled by default | D125 | Not started. |
| Updates | Stable channel; the user starts updates | D126 | `alp update` not verified. |
| Terminal | Konsole + Zsh + zsh-autosuggestions + zsh-syntax-highlighting | D119 | Suggestions, accept, Ctrl+C and spelling help verified in VM. Konsole test pending (section 4). |
| Shortcuts | Windows-familiar profile from one source file | D118 | 19 of 20 checks passed in a QEMU run (commit 8e674a4). |
| Settings and first run | KDE System Settings plus an alpbah Welcome app | D121 | Welcome app not started. |
| Look | Solid default, Glass option, Atatürk theme selectable | D114, D116 | Atatürk wallpaper seen in QEMU (low resolution). Theme selector not started. |
| Layout | Windows-style bottom taskbar with a Start menu | D115 | Not started (current test image uses the v1 layout). |
| Installer | Calamares, graphical, offline, LUKS option, dual boot | D137–D139 | Partial. Runner installs to a virtual disk; GUI test and dual boot not done (M11). |
| Apps | Dolphin, Konsole, Kate/KWrite, Okular, Gwenview, Ark, LibreOffice, VLC, Firefox | D127 | Okular and KWrite open in VM. Others built or not verified (section 10). |
| Compatibility | Steam native (multilib); Wine via Bottles (Flatpak) | D129, D130 | Not tested. |
| Brand | alpbahOS logo, dark navy + cyan + orange | D113 | Logo in use. Logo check in terminal is open (section 4). |

## 3. Scope boundaries

- Do not write a kernel, compositor, browser or dependency solver from scratch. Build from source and customise open-source projects (v1 D04, D14, carried into v2 by D143).
- Do not promise driver, hardware or application support without a test (v1 D21, carried over).
- The Windows-host VM path of v1 is history only (see archive/MASTER_PLAN-v1.md and archive/DECISIONS-v1.md). Test environment is Fedora with QEMU/KVM (D106).

## 4. Terminal experience

### 4.1 User behaviour

While typing, a suggested continuation appears in faint text after the cursor. It does not depend on window transparency and works in the plain profile. It needs no network and no AI service (D119 and v1 §4.1). Cloud prediction is not part of the requirement.

- Suggestions come from local history and completion data.
- Right arrow or End accepts the suggestion onto the command line. Enter is still needed to run it. Accepting never runs a command.
- Tab completes commands, file names and package names from the local `alp` index.
- Ctrl+R opens history search.
- An unknown command gives clear feedback.
- A spelling correction is offered as a suggestion the user may reject. Arguments and file names are never changed silently.
- Interactive shell settings do not change `/bin/sh` or build scripts. Build scripts choose their own interpreter (v1 §4.2).

### 4.2 Completion conditions and state

| # | Condition (v1 §4.3, translated) | State | Evidence |
|---|---|---|---|
| 1 | Suggestion shows while typing on a clean user account, no network | Passed in VM (not in Konsole) | [vm-session-2-2026-11-05.md](verification/vm-session-2-2026-11-05.md) (`zt.py`: `suggestion_visible`) |
| 2 | Accepting a suggestion does not run it | Passed in VM (not in Konsole) | same |
| 3 | A spelling correction is explained and can be rejected | Passed in VM (not in Konsole) | same; also [t3-zsh-chroot-2026-11-05.md](verification/t3-zsh-chroot-2026-11-05.md) |
| 4 | Package-name completion uses the selected local index, no root or network needed | Passed in chroot pty only | [t3-alp-completion-2026-11-05.md](verification/t3-alp-completion-2026-11-05.md) (`alp install ht<TAB>` gives `alp install htop`) |
| 5 | Ctrl+C keeps its interrupt behaviour; copy and paste are explained to the user | Ctrl+C passed in VM. Copy/paste explanation not verified. | same as row 1 |
| 6 | The logo prints with correct colours in a real terminal | Open. A PNG preview is not terminal proof. | — |

Row 1–3 and 5 must be re-run in Konsole inside the Plasma Wayland session before this section is called done. Konsole 25.08.3 and Zsh 5.9 run in the Plasma session (QEMU). The Zsh profile file is `profiles/shell/zshrc.alpbah`.

## 5. Packages and store

### 5.1 `alp` command set

Engine: `alp`, a stdlib-only Python program (D122). Commands and Turkish messages follow D123. The help and error text is Turkish in the prototype; full coverage is not checked.

| Command | Meaning | State |
|---|---|---|
| `alp install <name>` | Show the plan, ask for approval, install | Works for htop in chroot and VM |
| `alp remove <name>` | Show affected packages, remove, keep user documents | Works for htop in chroot and VM |
| `alp update` | Refresh indexes and list updates | Not verified |
| `alp upgrade` | Show upgrade plan and apply after approval | Not verified. Whether `update` and `upgrade` stay separate is not decided. |
| `alp search`, `alp info`, `alp list`, `alp help` | Search, details, installed list, help | Part of the prototype; not fully tested |

- Typing `apt install …` prints a hint that points to `alp` (D123). The hint is not implemented yet.
- `alp` writes one package database and uses one lock. The CLI and the store use the same engine, database and lock (v1 §5.3).
- Root access is never given to the whole store. Install and remove go through a separate authorised action (v1 §5.3).
- Before an install, the plan shows the download size, disk needs, source and affected packages (v1 §5.3).

### 5.2 Store (Discover)

D124 chooses KDE Discover with an alp PackageKit backend. Two drafts exist:

- `scripts/legacy/wip-2026-09-30/scripts/packagekit/alpBackend.py` with the helper scripts and PolicyKit rules next to it (2026-09-30 candidate). The README there calls it a starting point for D124.
- `docs/handoffs/claude/alp-prototype/alp_packagekit_backend.py`, a Python wrapper that calls `alp.py` as a subprocess. Its wrapper functions are tested against `alp.py` without PackageKit. The `AlpPackageKitBackend` class has never run on a PackageKit daemon. Design notes: [packagekit-integration.md](handoffs/claude/alp-prototype/design/packagekit-integration.md).

Both drafts are untested on the current 12.4 base. On 2026-09-30 a different candidate rootfs (never merged into the test base) gave these results: Discover search for `htop` returned the catalog item; a `pkcon` install of `htop` completed with a `PATH` fix; removal finished but printed a "not installed" error afterwards. That run is **not a pass** ([m08-live-packagekit-auth-runtime-2026-09-30.md](../scripts/legacy/wip-2026-09-30/docs/verification/m08-live-packagekit-auth-runtime-2026-09-30.md), [m08-packagekit-path-and-auth-retest-2026-09-30.md](../scripts/legacy/wip-2026-09-30/docs/verification/m08-packagekit-path-and-auth-retest-2026-09-30.md)). The store is not ready until install, launch and remove pass cleanly on the new base, and catalog signature checks are tested.

### 5.3 Flathub and updates

- Flathub is enabled by default (D125). It is an extra channel; it does not replace the base package system.
- Stable channel only. No automatic background install. The user starts every update. No update pop-ups (D126).
- A system update must not leave libraries half-updated. The update plan is tested before release (v1 §5.2).
- Removing a package keeps user documents and settings (v1 §5.1).

## 6. Windows-familiar shortcuts

`Win` is the Meta key on Linux. The profile is defined in one file and generated into the Plasma configuration; users can edit or reset it (D118). Only the listed keys are promised. "All Windows shortcuts" is not a claim.

| Keys | Target behaviour | Test scope |
|---|---|---|
| Alt+Tab / Alt+Shift+Tab | Switch windows forward and back | Several windows, several screens |
| Win+D | Show desktop and restore | Minimised windows are kept |
| Win+E | Open file manager (Dolphin) | Repeated calls |
| Win+L | Lock the session (KScreenLocker) | Return from the lock screen |
| Win+R | Run / launcher, focus on the search field | Focus |
| Win | Open the Start menu | Does not conflict with other Win combinations |
| Win+I | Open Settings | Correct settings app |
| Win+Left / Right | Snap window to the screen edge | Several screens and scales |
| Win+Up / Down | Maximise, restore, minimise | Consistent state order |
| Win+Tab | Overview of windows and desktops | Matches the chosen desktop action |
| Alt+F4 | Close the active window | Unsaved-document prompt |
| Ctrl+Shift+Esc | System monitor | No conflict |
| Win+Shift+S | Region screenshot (Spectacle) | Wayland permission and selection flow |
| Ctrl+C / V / X / Z | Copy, paste, cut, undo in GUI apps | Terminal is the exception (Ctrl+C is interrupt) |

State: the 2026-11-05 QEMU run passed 19 of 20 checks (commit 8e674a4; see [handoff 022](handoffs/claude/022-t2-kisayol-2026-11-05.md)). A Dolphin shortcut could not be checked because Dolphin was not in that test image. Two implementation rules come from the 2026-11-05 work:

- The session preparation step must run before KWin starts. Otherwise KGlobalAccel loads the old shortcut file and writes the old state back on exit (handoff 022).
- Shortcut file path and reload follow v1 D41 and D43, carried into v2 by D143.

Ctrl+C in a terminal stays "interrupt". Shortcut conflicts are listed in [profiles/shortcuts/conflicts.md](../profiles/shortcuts/conflicts.md).

## 7. Brand, themes and appearance

### 7.1 Brand and default look

- Mountain/terminal logo, dark navy, cyan and orange (D113). Every asset's source and licence is recorded.
- The default wallpaper and lock screen use the alpbahOS brand (D114). The Atatürk theme is a selectable theme in the Welcome app and in Settings (D114). It is not the forced default.
- Windows-style single bottom taskbar with a Start menu (D115). The older top-panel-and-dock mockup is dropped. See [alpbahOS-design-mockups.md](alpbahOS-design-mockups.md) for colours and components only.
- Wallpaper crop rule: scale only (D143, v1 D50). The Atatürk source image is small for 1080p (732×987 in the v1 notes). Resolution choice is not recorded as closed.
- Keep safe areas for name, password field and logo in 16:9, 16:10 and ultrawide crops. Keep a plain area for desktop icons.
- No invented quotes, signatures or text added to the images.

### 7.2 Appearance profiles

| Profile | Look | Use |
|---|---|---|
| Solid (default) | Opaque, calm surfaces; short, smooth animations | Old PCs, VMs, daily use |
| Glass | Blur and transparency with readable surfaces | Standard PCs with GPU acceleration |

Liquid glass is not in the first release (D116). Glass is named Glass only when it blurs; it is not sold as liquid. A Glass claim needs a measured result on the target hardware.

### 7.3 Animations, accessibility and performance

- Animations are smooth, fast and customisable (D117). Reduced-motion and low-transparency settings stay usable.
- Text contrast is checked. Keyboard focus is visible. Errors are not shown by colour alone.
- Effects can be turned off; the Solid profile must work with effects off (v1 §7.3).
- Performance budget (D135): idle use at or below 1 GiB of RAM on a 4 GiB machine is the design target. It is not a published requirement until measured. Measure with the same method each time: `MemTotal - MemAvailable` two minutes after login, and the sum of PSS for processes.

| Profile | Test machine | Measure |
|---|---|---|
| Low | 2 CPU, 4 GiB RAM, older x86_64, Solid | Idle use ≤ 1 GiB target; no swap thrashing |
| General | 4 CPU, 8 GiB RAM, integrated GPU, Glass | Input latency; daily apps open |
| 2 GiB (experimental) | 2 CPU, 2 GiB RAM | Shows whether the desktop starts; no support promise |

No browser, Wine, file indexing or store starts in the background by default. If the Solid profile misses the target, the next step is reducing services and theme cost before any other profile is considered.

## 8. Build environment and reproducibility

### 8.1 Environment

- Host: Fedora with QEMU/KVM for daily work (D106). Before each release, a USB test on a real PC (D106).
- LFS chroot at `/mnt/lfs`. Scripts live in `scripts/lfs-blfs/`. Source tarballs and disk images are not in Git.
- Long builds and tests may run for hours in the background, overnight included. Results are summarised afterwards (D105). The user spends about 1–2 hours a day.
- Builds are local. Small CI tests run on GitHub Actions ([alp-tests.yml](../.github/workflows/alp-tests.yml)). Release ISOs go to GitHub Releases (D107).
- Safety rules from [CLAUDE.md](../CLAUDE.md) apply: installer and disk tests only on new image files; one writer on `/mnt/lfs` and on any loop or nbd device; mount scripts clean up with an ERR/EXIT trap.
- Binary baseline is generic x86-64 (D146). No package is built with `-march=native` or host CPU flags. Newer instructions only with runtime dispatch. Every build is audited with `scripts/lfs-blfs/cpu-baseline/audit-isa.sh`. QEMU tests use the default `qemu64` CPU model as the gate.

### 8.2 Reproducibility inputs

Each build records:

- LFS and BLFS book version and access date.
- Host tool versions and the LFS host check result.
- Source URL, checksum and signature check (where upstream publishes one). Where upstream has no checksum, the hash is marked as computed locally.
- Patch set, recipe version, dependencies and compiler options.
- Locale, umask, user, working directory and job limit.
- Start and end time, exit code, test report and output ID.

A recipe change makes dependent results stale. An old stamp file is not enough to continue. Source archives, build trees, staging and artifacts are kept apart. Bit-for-bit identical ISOs are a separate goal and are not claimed yet.

## 9. Rebuild track (D140–D142)

The current LFS 12.4 system is the working test base. The rebuild replaces it once. The 12.4 base stays the test base until step R5 passes.

| Step | Work | Exit criteria |
|---|---|---|
| R1 | Pinned (D145): LFS 13.1-systemd, Multilib LFS 13.1 and BLFS 13.1-systemd ([research record](verification/rebuild-r1-lfs-version-2026-11-06.md)). Still to write: the source manifest (URLs, checksums, patch sets). | Pinned version recorded in DECISIONS.md (done). Manifest committed (open). |
| R2 | Build the cross toolchain and temporary tools with multilib. Apply the D146 flags (generic x86-64, `--with-gcc-arch=x86-64` for libffi, `--build=x86_64-pc-linux-gnu --enable-fat` for GMP) to every package. | Toolchain builds; test results recorded per package; no host library leaks (checked); `audit-isa.sh` passes on each package (D146). |
| R3 | Build the final base system with every package installed through `alp`, so the file-ownership ledger is produced automatically (D141). This closes the v1 D34 debt. | Ledger covers every base file with an owner; no unowned system path; removal safety tested on a sample. |
| R4 | BLFS and KDE rebuild: Xwayland, KScreenLocker, Mesa with llvmpipe, features disabled in the test image turned back on (v1 D39, D53, D54, see [archive/DECISIONS-v1.md](archive/DECISIONS-v1.md)), trust-on-first-use hashes checked again (v1 D52, D56, D142), lib32 libraries needed by Steam. | Plasma Wayland session starts; the checks in section 13 pass for the desktop; each re-enabled feature has a test. |
| R5 | Parity: the rebuilt image boots on BIOS and UEFI in QEMU and passes the same checks as the current 12.4 image. | Both boot modes boot; same check list passes; result recorded. Only then does the rebuilt base replace the 12.4 test base. |

Note: the 2026-09-30 event-derived ledger for an earlier candidate ([m10-alpha-test-matrix-2026-09-29.md](../scripts/legacy/wip-2026-09-30/docs/verification/m10-alpha-test-matrix-2026-09-29.md), D34 addendum) was not merged into the test base. R3 is the planned way to close the debt on the new base.

## 10. Milestones

Status is as of 2026-11-06. "Not started" means no record was found. "Not verified" means work exists but no passing test was recorded.

| ID | Scope | Status (2026-11-06) | Exit criteria |
|---|---|---|---|
| M00 | Requirements, decisions, repo rules | Done. Decision review recorded as D100–D143. | DECISIONS.md and this plan agree; rule file CLAUDE.md is the only rule file. |
| M01 | Host, disk space, network, LFS host check, log layout | Not verified on the current Fedora host. The v1 record covers the earlier Windows-host setup only. | Host check passes on the current machine. |
| M02 | `alp` engine, catalogue, first store contract | Partial. Install/remove of htop verified in chroot and VM. `alp update`, real upgrade, rollback and store path open. | `alp install/remove/update/upgrade` pass on the test base with logs; rollback tested. |
| M03 | ABI and temporary tools; **multilib added** (D111) | Reopened. The 12.4 base is 64-bit only. Multilib not built. | R1–R2 pass (section 9). |
| M04 | Final LFS base system | Partial. 79-package Chapter 8 test run recorded. Ownership ledger for the current base not produced. | R3 passes: ledger complete on the new base. |
| M05 | Kernel, init, bootloader, first boot | Partial. Boots in QEMU. UEFI boot of the current base not verified. | Both BIOS and UEFI boot in QEMU; reboot and network checked. |
| M06 | Graphics, audio, session, network, certificates | Partial. DNS, TLS, D-Bus and ALSA loopback audio passed on the earlier host (v1 record). Real audio and graphics on hardware open. | Audio and network checked on real hardware in M12. |
| M07 | Desktop: Plasma Wayland session, Konsole, Zsh | Partial. Session, Konsole and Zsh run in QEMU. Kickoff menu, volume applet, keyboard layout list (tr, us) loaded. 30-minute stability run passed. Key-based layout switch not tested. | Key layout switch, Xwayland app run and the Plasma checks in section 13 pass on the rebuilt base. |
| M08 | Terminal help, store, shortcuts, Atatürk and Glass themes, **Windows taskbar, Welcome app, Discover** | Partial. Shortcuts 19/20 in VM; Atatürk wallpaper and Konsole profile seen; PDF/text/folder default apps pass. Taskbar, Welcome app and Discover not started or not passing. | Every row in section 6 tested; taskbar and Start menu in place; Welcome app runs on first boot; Discover install, launch and remove pass cleanly. |
| M09 | Live rootfs, initramfs, live ISO (BIOS + UEFI), VM image | Partial. ISO built by script on 2026-11-06 (`scripts/lfs-blfs/live-iso/build-iso.sh`, 2.6 GB hybrid, BIOS and EFI entries). BIOS boot with the default `qemu64` CPU reaches Plasma with 0 SIGILL and 0 FAILED after the D146 fix (ISO v3). UEFI boot reached a usable Plasma session on the earlier ISO v2 (host CPU). The live desktop is still stock KDE with English SDDM (LIVE-PROFILE-01). Its squashfs was the install source for the M11-FIX-02 and M11-UEFI-01 runs. | Repeatable ISO builds on BIOS and UEFI; boots to desktop; no internal disk touched; default account and secrets rules met. |
| M10 | Alpha: test matrix, known issues, GitHub Releases, public repo | Not started on the current base. Draft test matrix from 2026-09-29 exists. Pre-release `v0.1.0-alpha.1` exists with no ISO. | Section 13 matrix run; checksums; known issues; repo public (D108); user approval. |
| M11 | Calamares installer: BIOS and UEFI, LUKS, dual boot with Windows | Partial. BIOS and UEFI installs to virtual disks through the product grubcfg path (D144). BIOS first boot clean (0 failed units, 2026-11-06; M11-FIX-02, [record](verification/m11-fix02-root-cause-2026-11-06.md)). UEFI install done 2026-11-06 (M11-UEFI-01, [record](verification/m11-uefi-install-2026-11-06.md)): OVMF boot to login, 0 `FAILED`. NVRAM registration on a real UEFI PC not tested. OPEN-1 is resolved (section 14). GUI click test, LUKS and dual boot not done. | Install to virtual disk on BIOS and UEFI passes; LUKS install passes; dual boot test on a virtual disk passes; real disk only with the user's permission. |
| M12 | Beta: installable build, maintenance, real-PC USB tests | Not started. Depends on M11. | USB test on real PCs (matrix in section 13); update and recovery test; user approval. |

## 11. Apps, drivers and compatibility

### 11.1 Preinstalled apps (D127)

| App | Use | State |
|---|---|---|
| Dolphin | Files: copy, undo, archives, eject | Built. Win+E check pending (Dolphin not in the 2026-11-05 shortcut test). |
| Konsole + Zsh | Terminal | Runs in QEMU session (section 4). |
| Kate / KWrite | Text, UTF-8, Windows line endings | KWrite opened in VM. Kate built. |
| Okular | PDF | Opened in VM. PDF default app passed. `gio open` path partial ([vm-session-3-t6-2026-11-05.md](verification/vm-session-3-t6-2026-11-05.md)). Several non-PDF formats are not built in the test image. |
| Gwenview | Images | Built. MIME check not run. |
| Ark | Archives | Built. MIME check not run. |
| LibreOffice | Writer, Calc, Impress; Word and Excel files | Not started. No Word-compatibility claim (D131). |
| VLC | Media | Not started. |
| Firefox | Default browser | Not started. |

### 11.2 Graphics drivers

- Open drivers preinstalled: Mesa with real GPU drivers and llvmpipe (D128, D134).
- NVIDIA proprietary driver: separate package, installed with one command or click (D128). Not started.
- Kernel modules and firmware for storage, USB, HID, Ethernet, audio and graphics.
- Wi-Fi and Bluetooth firmware common to the target PCs.
- Driver support is claimed only per device that passed a real-PC test (section 13). Devices not tested are listed as untested in the release notes.

### 11.3 Compatibility

- **Steam** is supported natively thanks to multilib (D129). Requires R4 (lib32 libraries). Not tested.
- **Wine** comes through **Bottles** (Flatpak), not as a system Wine (D130). Not tested.
- **Microsoft Office** is not a target (D131).
- **Printing** (CUPS) and scanning are not in the decision list. Not decided; not promised.

## 12. Updates, maintenance and release

- Stable channel, user-started updates (D126). No update notifications.
- Old kernel or recovery media as a fallback is still to be decided. Atomic system updates are not planned for the first release.
- Licence: GPL-3.0 for project code, with a LICENSE file (D109). Third-party components keep their own licences. A licence and source record is kept for every shipped package and image.
- Release gate:
  - User approval for every release (D108).
  - No test accounts, test passwords, embedded keys or test fonts in release images (safety rules in [CLAUDE.md](../CLAUDE.md)). Check this before each release.
  - Checksums for every ISO, published with the release notes and known issues.
  - Test matrix (section 13) run and recorded; failures listed.
- Repository: private until the first alpha ISO is ready, then public (D108).
- Releases are uploaded to GitHub Releases (D107). Source is in the repository, ISOs and packages are not.

## 13. Test matrix

| Area | Test | Passed when |
|---|---|---|
| Boot, BIOS | QEMU, Legacy BIOS, live ISO and installed disk | Boots to login and desktop; reboot works |
| Boot, UEFI | QEMU with OVMF, live ISO and installed disk | Same as BIOS |
| Real PC | USB from the release ISO on at least one real PC per boot mode | Boots and runs the daily checklist; hardware results listed per device |
| Low RAM | 4 GiB VM and a real 4 GiB PC | Idle use ≤ 1 GiB target measured (section 7.3); no swap thrashing |
| Install | Virtual disk install with LUKS on and off; dual boot on a virtual disk | Installed system boots; the Windows test partition is untouched |
| School lab | Several user accounts; lock screen (Win+L); LibreOffice files opened and saved; print-free daily tasks | Accounts separate; lock and unlock work; files open in LibreOffice |
| Ex-Windows user | Shortcuts (section 6); Dolphin; install an app from Discover or Flathub; Steam start; Bottles start | Each step passes or is listed as failed |
| Terminal | Suggest, accept, run, reject correction (section 4) in Konsole | Logged interaction; no command runs without Enter |
| Store | `alp` and Discover install, launch, remove | Clean remove with no error after finish |
| Desktop | Plasma checks: Kickoff, layout switch, volume, 30-minute stability, Xwayland app start | Each check logged with a screenshot or command output |

Tests not run are reported as "not run". A test with a log but no pass is "failed" until fixed.

## 14. Open decisions

### OPEN-1 — resolved by D144 (2026-11-06)

Option (b) was chosen: the installed system boots with `root=PARTUUID=…` and no initramfs. It needs GPT and `CONFIG_EFI_PARTITION=y`. Implemented in `scripts/lfs-blfs/calamares/modules/grubcfg.conf`; proven on a BIOS virtual disk ([record](verification/m11-d144-partuuid-2026-11-06.md)).

History: `grub-mkconfig` wrote `root=UUID=…` for the installed system; with no initramfs the kernel panicked ([handoff 024](handoffs/claude/024-devir-m11-modul-kosucu-2026-11-06.md), item 3). No other open user decisions are recorded as of 2026-11-06.
