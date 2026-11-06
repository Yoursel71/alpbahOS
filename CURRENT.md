# alpbahOS — Current state

Last updated: 2026-11-06

Claude is the only agent on this project (D100). Decisions were re-done on 2026-11-06 in a 50-question review; see [docs/DECISIONS.md](docs/DECISIONS.md). History is in [docs/WORKLOG.md](docs/WORKLOG.md), [docs/handoffs/claude/](docs/handoffs/claude/) and [docs/archive/](docs/archive/).

## What exists and is verified

Each item says how far the evidence goes. "Chroot only" means the work ran in the `/mnt/lfs` chroot, not in a booted system.

- **LFS 12.4-systemd base, kernel 6.16.1.** BIOS and UEFI (OVMF) boots reach the `alpbahos login:` prompt in QEMU ([M1 boot verification](docs/M1_BOOT_VERIFICATION.md)). The M11 BIOS install run reached the login prompt again on 2026-11-06 ([m11-boot-serial log](docs/verification/m11-boot-serial-2026-11-06.log)). The base is the test base until the rebuild boots (D140).
- **BLFS 12.4 / KDE Plasma 6.4.4 build: DONE, 338 entries, chroot build** ([handoff 020](docs/handoffs/claude/020-m07-m08-qemu-oturumu.md), commit `ebb6624`). Build scripts: [scripts/lfs-blfs/](scripts/lfs-blfs/).
- **Plasma Wayland session in QEMU** (virtio-gpu + virgl). Atatürk wallpaper and alpbahOS Konsole profile seen on the desktop ([M07/M08 evidence](docs/verification/m07-m08-qemu-evidence-2026-11-05.md)).
- **M07 T1 runtime checks in QEMU:** Kickoff menu opens; volume applet visible; keyboard layouts `tr` and `us` loaded in the KDE keyboard service; 30-minute stability run with no crash of `plasmashell` or `kwin_wayland` ([T1 evidence](docs/verification/m07-t1-runtime-2026-11-05.md)). Switching layouts with a key was not tested.
- **Konsole + Zsh with plugins:** Zsh 5.9 with zsh-autosuggestions and zsh-syntax-highlighting. In QEMU, a pty test (not Konsole) passed for suggestion display, accept-without-run, Ctrl+C and spelling correction ([VM session 1](docs/verification/vm-session-2026-11-05.md)). Konsole opened with Zsh in QEMU ([handoff 020](docs/handoffs/claude/020-m07-m08-qemu-oturumu.md)). `alp` name completion: chroot pty only ([T3 evidence](docs/verification/t3-zsh-chroot-2026-11-05.md), [T3 alp completion](docs/verification/t3-alp-completion-2026-11-05.md)).
- **Windows-style shortcuts (T2): 19 pass, 1 out of scope, in QEMU** (`clipboard-ops`, an application-layer shortcut) ([VM session 2](docs/verification/vm-session-2-2026-11-05.md), [live check output](docs/verification/evidence-2026-11-05/shortcut-live-verify-2026-11-05.txt)). Meta+E opens Dolphin in the VM. Root cause: KDE reads only the user file `~/.config/kglobalshortcutsrc`, not `/etc/xdg` ([handoff 022](docs/handoffs/claude/022-t2-kisayol-2026-11-05.md)).
- **`alp` install / run / remove of htop 3.3.0:** passed in QEMU ([VM session 1](docs/verification/vm-session-2026-11-05.md)) and in chroot ([T5 evidence](docs/verification/t5-alp-htop-chroot-2026-11-05.md)). `alp update`, rollback and dependency handling are not tested.
- **T6 apps:** in QEMU, MIME defaults for PDF (Okular), text (KWrite) and folders (Dolphin) pass, and Okular and KWrite open under Wayland ([VM session 3](docs/verification/vm-session-3-t6-2026-11-05.md)). Ark and Gwenview are built (chroot, signature check passed); their VM run is not done ([T6 deps](docs/verification/t6-apps-deps-2026-11-05.md)).
- **SDDM autologin:** fixed for the test image; the `alpbah` session opens without a password ([fix record](docs/verification/sddm-autologin-fix-2026-11-05.md)).
- **M09 live ISO first boot in VM:** the ISO boots, the `alplive` dracut hook builds the root overlay, and the Calamares binary and the squashfs source are visible in the live system ([M09 evidence](docs/verification/m09-live-iso-2026-11-05.md)). The installer has not yet installed from the live ISO.
- **M11 installer chain:** yaml-cpp 0.9.0, parted 3.6, kpmcore 25.08.3 and Calamares 3.3.14 built in the chroot ([chain record](docs/verification/m11-calamares-chain-2026-11-05.md)).
- **M11 install to a virtual disk (BIOS), partial:** the module runner `m11-run.sh` installs to a new image file and the VM reaches the login prompt. The first run failed with a kernel panic (`root=UUID=` with no initramfs), so the install used `root=PARTUUID=`; OPEN-1 is still open ([module runner record](docs/verification/m11-module-runner-2026-11-06.md)). The GUI installer click-through and UEFI install are not done.

## Milestone status

Status words: done / partial / not started / unknown. Details are in the linked records.

| ID | Status | Note |
|---|---|---|
| M00 | done | Requirements, decisions and repo set up. Re-done 2026-11-06 (D100–D143). |
| M01 | done | Linux build host and LFS build root checked on the old Ubuntu builder ([archive M01 row](docs/archive/MASTER_PLAN-v1.md)). The current host is Fedora with QEMU/KVM (D106). |
| M02 | partial | `alp` engine: install/run/remove of htop passed in QEMU and chroot. `update`, rollback and dependency handling are open. |
| M03 | not started | Reopened by D111: multilib (lib32) is now required. No multilib build exists yet. |
| M04 | partial | Base accepted with a deviation (v1 D34). The 79-package ownership ledger is open; D141 closes it in the rebuild. |
| M05 | done | Boot checks passed on the test base (BIOS and UEFI, networking, reboot). Repeat on the rebuilt base (D140). |
| M06 | partial | Virtual audio round-trip (ALSA loopback + PipeWire) passed. Physical audio and graphics checks are open ([archive M06 row](docs/archive/MASTER_PLAN-v1.md)). |
| M07 | partial | Plasma Wayland session, Kickoff, volume applet and 30-minute stability pass in QEMU. Key-switched layout change not tested. |
| M08 | partial | Wallpaper (functional, no screenshot), Konsole profile, Zsh, shortcuts (19 pass, 1 out of scope) and Meta+E in QEMU. Ark/Gwenview not checked in VM. Liquid glass is out of the first release; Solid is the default and Glass stays an option (D116). |
| M09 | partial | Live ISO boots to the live system in VM. Installing from it and the live-user policy are open. |
| M10 | not started | Alpha test matrix and release candidate do not exist yet. |
| M11 | partial | BIOS install to a virtual disk reaches the login prompt. UEFI install, GUI click-through and OPEN-1 are open. |
| M12 | not started | Beta release. Needs the user's approval for publication (D108). |

## What changed on 2026-11-06

- **Decision review v2 (50 questions, D100–D143).** Biggest reversals:
  - Multilib (lib32) is back, and Steam is supported through it (D111, D129). This reverses the v1 64-bit-only decision (v1 D32, D35).
  - Windows-style single bottom taskbar with Start menu; the old top panel and dock are dropped (D115).
  - Atatürk theme is selectable, not the only theme; the default wallpaper and lock screen use the alpbahOS brand (D114).
  - Liquid glass is dropped from the first release; Solid is the default, Glass is an option (D116).
  - Microsoft Office is not a target; LibreOffice handles Word files (D131).
  - Rebuild the base once on the newest stable LFS with multilib (D140), installing every base package through `alp` (D141). Test-image deviations are closed in that rebuild (D142).
  - Xwayland (D132), KDE screen locker (D133), Mesa with real drivers plus llvmpipe (D134).
  - LUKS disk encryption is an installer option; Secure Boot later (D139).
  - English live docs (D102) and GPL-3.0 project license (D109).
- **Claude-only project (D100).** The second agent is removed from the project: no role split, no ownership tables, no integrator. Its remote branches are archived and deleted (D104).
- **Repository restructure (D104).** Old second-agent-era scripts and tests move to `scripts/legacy/` and `tests/legacy/`. Old core docs move to `docs/archive/`. Useful uncommitted work from 2026-09-30 is imported to `scripts/legacy/wip-2026-09-30/`.
- **Delivery rules (D103, D107, D108).** Commits go straight to `main` on remote `yoursel`, fast-forward only. Builds stay local; small CI runs on GitHub Actions; ISOs go to GitHub Releases. The repo stays private until the first alpha is ready.
- **Long runs allowed (D105).** Builds and tests may run for hours, overnight included. The old one-hour limit is removed.

## Next actions

1. **OPEN-1 (installed-system root device).** Ask the user to choose: (a) small dracut initramfs without the live hook, or (b) `root=PARTUUID=…` with GPT and `CONFIG_EFI_PARTITION=y`. Record the answer in [docs/DECISIONS.md](docs/DECISIONS.md). M11 acceptance depends on it.
2. **M11 follow-ups from [handoff 024](docs/handoffs/claude/024-devir-m11-modul-kosucu-2026-11-06.md):** add `grubcfg` to the Calamares `settings.conf`; set `kernelSearchPath` to `/boot`; make `unpackfs` fail when squashfs support is missing (it returns 0 now); make sure `rsync` and `unsquashfs` are on the live ISO.
3. **M11 services:** find the cause of the `systemd-oomd` and `systemd-resolved` namespace errors (`systemctl status` in the next VM session), then run the UEFI install test (needs an ESP).
4. **Rebuild R1:** check and pin the newest stable LFS book version, enable multilib, and install every base package through `alp` (D140, D141). Record the pinned version and its sources in docs/DECISIONS.md before building.
5. **Windows-style taskbar and Welcome app** (D115, D121): layout profile and first-boot app with theme, layout and appearance choices.
6. **Discover with an alp backend** (D124): PackageKit backend that calls `alp`. Start after the `alp` command contract is fixed.
7. **Translate the component READMEs in `profiles/*` to English** (D102).
8. **Small VM checks:** key-switched keyboard layout (M07), Ark and Gwenview MIME/open test (M08).

## Known issues

From [handoff 024](docs/handoffs/claude/024-devir-m11-modul-kosucu-2026-11-06.md) and [handoff 023](docs/handoffs/claude/023-devir-m11-m09-2026-11-06.md):

- **OPEN-1:** `grub-mkconfig` writes `root=UUID=…` on a real disk; the installed system has no initramfs, so the kernel panics. The virtual-disk run works only with `root=PARTUUID=…`.
- **`grubcfg` missing from `settings.conf`:** distro name and GRUB defaults are not set by the installer config (product item, not a blocker).
- **Wrong bootloader search path:** `kernelSearchPath` must be `/boot`, not `/usr/lib/modules`.
- **`unpackfs` silent success:** without squashfs support, it returns 0 and copies nothing. Fix: fail hard.
- **`systemd-oomd` and `systemd-resolved` fail** with namespace errors (`/tmp` mount, missing `/usr/lib/systemd/...`). Root cause not known.
- **Two boots in one VM session:** the 2026-11-06 morning session used two boots (kernel panic, then login). Reported to the user on 2026-11-06.
- **Deviations v1 D39/D40** (test image) are closed in the rebuild (D142); the list is in [DEVIATIONS.md](docs/verification/evidence-2026-11-05/DEVIATIONS.md).
- **`gio open` does not start Okular under Wayland** (v1 D55): the DBus-activated process does not get `WAYLAND_DISPLAY`. Direct start works. Candidate fix: `dbus-update-activation-environment` or `systemctl --user import-environment` in the Plasma session.
- **Not verified:** Ark and Gwenview run in VM; Konsole tab completion in VM; LFS Chapter 8 long tests (Python, systemd, util-linux) not run (v1 D42).

## Where things are

- **Working tree:** `/home/yrslf/alpbahOS/wt-t2-kisayol` (branch `claude/t2-kisayol-2026-11-05`).
- **LFS chroot:** `/mnt/lfs`. Mount with `sudo bash scripts/lfs-blfs/mount_lfs.sh`; unmount with `scripts/lfs-blfs/umount_lfs.sh`. Run one writer at a time.
- **Work and scratch dir:** `/home/yrslf/alpbahOS/scratch-lfs-bench` (ISO build in `alp-iso/` and `alp-iso-out/`, installer targets and logs in `m11-runner/`, test passwords in `test-secrets/`, which is outside the repo).
- **Build scripts:** `scripts/lfs-blfs/` (installer runner: `scripts/lfs-blfs/calamares/runner/m11-run.sh`).
- **Profiles:** `profiles/` (shortcuts, apps, shell, desktop, perf). Generated shortcut file: `profiles/shortcuts/`.
- **Evidence:** `docs/verification/`. Handoffs: `docs/handoffs/claude/`.
- **Remote:** push target is `yoursel` only (D103).
