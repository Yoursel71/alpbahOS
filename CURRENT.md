# alpbahOS — Current state

Last updated: 2026-11-09

Claude is the only agent on this project (D100). Decisions were re-done on 2026-11-06 in a 50-question review; see [docs/DECISIONS.md](docs/DECISIONS.md). History is in [docs/WORKLOG.md](docs/WORKLOG.md), [docs/handoffs/claude/](docs/handoffs/claude/) and [docs/archive/](docs/archive/).

## Current state (2026-11-09)

- **Alpha ISO:** `alpbahos-alpha-2026-11-08.iso` in `scratch-lfs-bench/images/` (not in the repo).
- **Beta 0.9:** ISO `alpbahos-beta-0.9-2026-11-09.iso`, sha256 `1686abfd38dc04fabbb405fdec85307d2a587160d18502a1f5b50f5cfe8d4347`. Gate **not met** (record: [docs/verification/iso-beta-0.9-2026-11-09.md](docs/verification/iso-beta-0.9-2026-11-09.md), sections 10.5 and 10.6).
  - Passing on this sha: live BIOS and UEFI desktops; BIOS MSDOS and UEFI GPT installs complete; installed boots on BIOS virtio, BIOS AHCI, UEFI virtio and UEFI NVMe; sound on BIOS virtio and UEFI NVMe.
  - Open: the shutdown coredump is not reproduced and not fixed (the drop-in stop-order fix is shown only for the at-spi failure); installed BIOS on NVMe does not boot in SeaBIOS in the round 6 runs; the round 6 reruns (shutdown menu, tr_TR, trq, AHCI sound, alp update and rollback, live-ISO recovery) were not run.
- **Beta 0.9 round 16 (2026-11-10):** the r15 ISO (sha256 `e2077dcfcd384963fbc1dce981deb663bfbe8c079094121e345a8e6463d1d5ae`, no change) has now run every matrix row: L1 (3 runs), L2, L3, L4, I1, I2 (disk check), B1, B2, B3, U1, U2, FP, REC1, S1 (3 cycles, 0 dumps), R1. Section 17.6 of [docs/verification/iso-beta-0.9-2026-11-09.md](docs/verification/iso-beta-0.9-2026-11-09.md) has the rows.
  - Beta gate at QEMU level: **MET**, with caveats: S1 and R1 used Konsole instead of the Plasma menu, and S1 sessions were about 60 s; the coredump crash is not proven fixed; the real-PC test and the publication decision are the user's.
- **Beta 0.9 round 15 (2026-11-10):** ISO `alpbahos-beta-0.9-2026-11-09-r15.iso`, sha256 `e2077dcfcd384963fbc1dce981deb663bfbe8c079094121e345a8e6463d1d5ae` (TAG=r15). Gate **not met** (section 17 of [docs/verification/iso-beta-0.9-2026-11-09.md](docs/verification/iso-beta-0.9-2026-11-09.md)).
  - Fixed and shown on this sha: the SDDM greeter loads the alpbahos theme with the logo (QML import path and `Current=`); the installed keyboard layout reads as `tr` in localectl; `alp list` works without `--index`; curl to `http://ftp.gnu.org/` returns headers in the guest.
  - Passing on this sha: L1 live UEFI (1 run), I1 and I2 installs, B1 (login, greeter, desktop, localectl, fastfetch, alp list, systemctl --failed), U1 (hostnamectl, failed units, Flatpak install of org.gnome.Calculator), REC1 recovery with the repaired disk booting.
  - Not run on this sha: L2 to L4, B2, B3, U2, S1, R1. Open: the real-PC keyboard feedback, the coredump proof, and the user's publication decision.
- **Beta 0.9 round 14 (2026-11-09, later):** ISO `alpbahos-beta-0.9-2026-11-09-r14.iso`, sha256 `ae1ef2d8f1b91380958f2a9a3055b5c50abbc50a111d9234d39393c93100e4ce` (TAG=r14). Gate **not met** (section 16 of [docs/verification/iso-beta-0.9-2026-11-09.md](docs/verification/iso-beta-0.9-2026-11-09.md)).
  - Fixed and checked on this sha: GnuPG recorded and the flathub remote configured (`flathub system`); `alp` installed copy equals the repo file (no `--index` needed in the chroot); fusermount3 setuid 4755 (BLFS fuse page checked); KDE keyboard default `tr` on the installed disk; live L1 (3 runs), installs I1 and I2 with disk checks, REC1 recovery and disk boot.
  - Still failing or open: SDDM logo not visible on the login frame; `localectl` X11 layout unset; `alp list` in the guest (not explained); Flatpak install result (see section 16); double hyphen does not type in the Turkish-Q session.
  - Two orphaned live QEMU VMs from the round 14 runs could not be closed by QMP (their run directories were removed by mistake); they need closing.
- **Beta 0.9 round 13 (2026-11-09, later):** ISO `alpbahos-beta-0.9-2026-11-09-r13.iso`, sha256 `03469d2900c1cc77a28d06fe6b7a22ec83d15df744cc0228cef75842c7e2ba7b` (built with TAG=r13, the release name is taken). Gate **not met** (section 15 of [docs/verification/iso-beta-0.9-2026-11-09.md](docs/verification/iso-beta-0.9-2026-11-09.md)).
  - Passing on this sha: live UEFI and BIOS desktops (KVM and TCG); BIOS MSDOS and UEFI GPT installs with clean disk checks; installed boots on BIOS virtio, AHCI, NVMe (2G) and UEFI virtio and NVMe; shutdown 3/3 with no coredump; reboot to the greeter; both recoveries repair the disk; About this System; fastfetch.
  - Failing or open: Flatpak (remote-add fails: no gpg engine in the image); `alp` without `--index` (r4-root has an older alp.py); curl not verified in the guest; fusermount3 is not setuid (BLFS book says chmod u+s); SDDM logo not seen on the login frame.
- **Not ours to decide:** the real-PC USB test and the publication approval (D108) belong to the user.

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
- **Live ISO built by script (2026-11-06):** `scripts/lfs-blfs/live-iso/build-iso.sh` builds `alpbahos-live-<date>.iso` (2.6 GB hybrid, label `ALPBAH_LIVE`, BIOS and EFI El Torito entries) from the 12.4 rootfs. ([record](docs/verification/m11-fix02-root-cause-2026-11-06.md))
- **Live ISO boots (2026-11-06):** BIOS boot of the rebuilt ISO (v3) with the default `qemu64` CPU reaches the Plasma session with 0 SIGILL and 0 FAILED ([serial log](docs/verification/m09-iso-v3-bios-qemu64-serial-2026-11-06.log), [screen](docs/verification/m09-iso-v3-bios-qemu64-screen-2026-11-06.png)). UEFI boot (OVMF, host CPU) on the earlier ISO v2 reached a usable Plasma session ([M09 record](docs/verification/m09-iso-v2-boot-2026-11-06.md)). The live desktop is still stock KDE with English SDDM; the alpbahOS profile is not in the rootfs yet (LIVE-PROFILE-01).
- **UEFI install to a virtual disk (M11-UEFI-01, 2026-11-06):** the runner (`M11_FIRMWARE=uefi`) makes GPT with a 512 MiB ESP and installs in 2 min 10 s, rc 0. OVMF boots the installed image to `alpbahos login:` with 0 `FAILED`; root is `PARTUUID` (D144). Host NVRAM is unchanged. NVRAM registration on a real UEFI PC is not tested ([install record](docs/verification/m11-uefi-install-2026-11-06.md), [boot log](docs/verification/m11-uefi-boot-2026-11-06.log)).
- **CPU baseline fix for the 12.4 test base (D146, 2026-11-06):** libffi 3.5.2 was built with `-march=native` (AVX in `ffi_prep_cif`), which caused the SIGILL in `kwin_wayland` and `wireplumber` on CPUs without AVX. libffi, GMP and MPFR are rebuilt with generic x86-64 flags: libffi 2460 expected passes, GMP 199/199, MPFR 198/198. The `qemu64` boot above is the proof. The `audit-isa.sh` run on the rebuilt files is not recorded yet (CPU-BASELINE-02). ([sigill report](docs/verification/sigill-cpu-baseline-2026-11-06.md), [rebuild logs](docs/verification/cpu-baseline-rebuild-logs/))
- **M11 installer chain:** yaml-cpp 0.9.0, parted 3.6, kpmcore 25.08.3 and Calamares 3.3.14 built in the chroot ([chain record](docs/verification/m11-calamares-chain-2026-11-05.md)).
- **M11 install to a virtual disk (BIOS), partial:** the product path (`scripts/lfs-blfs/calamares/modules/grubcfg.conf`, no test override) writes `root=PARTUUID=` for the installed system. One boot reaches the `alpbahos login:` prompt in about 12 s (2026-11-06, D144; [D144 record](docs/verification/m11-d144-partuuid-2026-11-06.md)). The earlier `root=UUID=` kernel panic is the reason for D144 ([module runner record](docs/verification/m11-module-runner-2026-11-06.md)). The GUI installer click-through is not done. The UEFI install is done (see below).
- **M11-FIX-02 first boot (BIOS, 2026-11-06):** the installed target booted once with 0 `FAILED` units on the serial console; `systemd-resolved` and `systemd-oomd` start. The cause was a squashfs without `/tmp` ([root cause](docs/verification/m11-fix02-root-cause-2026-11-06.md)).

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
| M09 | partial | Live ISO built by script (2026-11-06). BIOS boot with `qemu64` reaches Plasma with 0 SIGILL and 0 FAILED after the CPU fix (D146); UEFI boot reached Plasma on the earlier ISO. Stock KDE and English SDDM until LIVE-PROFILE-01. Installing from the booted ISO and the live-user policy are open. |
| M10 | not started | Alpha test matrix and release candidate do not exist yet. |
| M11 | partial | BIOS and UEFI installs to virtual disks through the product grubcfg path (D144). First boots clean: BIOS (0 failed units, 2026-11-06, M11-FIX-02), UEFI (0 `FAILED`, 2026-11-06, M11-UEFI-01). GUI click-through, LUKS, dual boot and real UEFI NVRAM are open. |
| M12 | partial | Beta 0.9 gate not met (2026-11-09). Live-ISO recovery FAILED once (initramfs regeneration with dracut in the live chroot broke the boot; the grub step worked). alp has no rollback command; update needs a catalog that the installed system lacks. Publication needs the user (D108). |

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
- **Installed root device (D144).** The installed system boots with `root=PARTUUID=…` and no initramfs. This closes OPEN-1. Needs GPT.
- **Generic x86-64 build baseline (D146).** No package is built with `-march=native` or host CPU flags. Every build is audited with `audit-isa.sh`. QEMU tests use the default `qemu64` CPU model.
- **Rebuild base pinned (D145).** LFS 13.1-systemd, Multilib LFS 13.1 and BLFS 13.1-systemd. The desktop profiles must be re-checked after the rebuild (BLFS 13.1 brings newer KDE and Qt).
- **Claude-only project (D100).** The second agent is removed from the project: no role split, no ownership tables, no integrator. Its remote branches are archived and deleted (D104).
- **Repository restructure (D104).** Old second-agent-era scripts and tests move to `scripts/legacy/` and `tests/legacy/`. Old core docs move to `docs/archive/`. Useful uncommitted work from 2026-09-30 is imported to `scripts/legacy/wip-2026-09-30/`.
- **Delivery rules (D103, D107, D108).** Commits go straight to `main` on remote `yoursel`, fast-forward only. Builds stay local; small CI runs on GitHub Actions; ISOs go to GitHub Releases. The repo stays private until the first alpha is ready.
- **Long runs allowed (D105).** Builds and tests may run for hours, overnight included. The old one-hour limit is removed.

## Next actions

1. **REBUILD-R2** on LFS/MLFS 13.1 (D145) with the D146 flags: build the toolchain, record source checksums first, run `audit-isa.sh` on each package.
2. **LIVE-PROFILE-01:** install the alpbahOS desktop profile into the rootfs (D114, D115, D120, D121). Then run LAYOUT-01 and THEME-01 in a Plasma session with screenshots in docs/verification/.
3. **Store track (STORE contract):** ALP-TR-01, then STORE-01 (Discover with an alp PackageKit backend, D124), FLATHUB-01, BOTTLES-01.
4. **Small VM checks:** key-switched keyboard layout (M07), Ark and Gwenview MIME/open test (M08).
5. **Installer track (kept separate):** INSTALL-DUALBOOT-01, then INSTALL-LUKS-01. Real-disk writes need per-action permission (D138).

## Known issues

From [handoff 024](docs/handoffs/claude/024-devir-m11-modul-kosucu-2026-11-06.md) and [handoff 023](docs/handoffs/claude/023-devir-m11-m09-2026-11-06.md):

- **Stock KDE live desktop and English SDDM (2026-11-06):** the live session shows the Breeze wallpaper, the default KDE panel, English UI, and the KDE Welcome Center text "Linux From Scratch". The SDDM greeter is English with the `us` layout. Fix: LIVE-PROFILE-01.
- **CPU baseline, open items (CPU-BASELINE-02):** `audit-isa.sh` on the rebuilt libffi, GMP and MPFR is not recorded yet. OpenCV 4.12.0 needs an SSE3 baseline, so spectacle may fail on a strict SSE2-only CPU. Mesa `libgallium` / `pipe_swrast`, gnutls and nettle carry AVX or v3 "ISA used" markers (not triggered in the `qemu64` Plasma test). The v1-strict run on the rebuilt base is not recorded.
- **Root device (resolved by D144):** `grub-mkconfig` writes `root=UUID=…`, which panics without an initramfs. The product grubcfg module writes `root=PARTUUID=…`.
- **Fixed on 2026-11-06 (M11-FIX-01):** `grubcfg` is in the installer sequence, `kernelSearchPath` is `/boot`, and `unpackfs` fails hard when squashfs is missing. `rsync` 3.4.1 and `squashfs-tools` 4.7.5 are built in the chroot; `check-live-tools.sh` exits 0.
- **`/blfs-work` in the installed root:** the squashfs source left a build directory in the target (seen 2026-11-06). `build-iso.sh` excludes it; the live ISO is not yet checked in a boot. Release images still need IMAGE-01 (test accounts, machine-id, SSH keys, fonts).
- **Fixed 2026-11-06 (M11-FIX-02):** `systemd-oomd` and `systemd-resolved` failed with `226/NAMESPACE` because the hand-made squashfs had no `/tmp`. `build-iso.sh` keeps `/tmp` (1777), `/root`, `/dev`, `/proc`, `/sys`, `/run`.
- **Locale:** under `tr_TR.UTF-8`, bash `[A-Z]` does not match `I`. Scripts that check labels or names must set `LC_ALL=C` (`build-iso.sh` does).
- **SELinux test host:** the Fedora host puts `security.selinux` labels on files. The squashfs build drops them. Installing onto the SELinux host with `rsync -X` needs the runner's test-only filter (`M11_HOSTTOOLS=0`). The product rsync call is unchanged, and the live ISO has no SELinux.
- **Backup:** `/mnt/lfs-12.4-backup-20261106` is a reflink copy of the 12.4 rootfs, taken 2026-11-06 before writing to it.
- **Two boots in one VM session:** the 2026-11-06 morning session used two boots (kernel panic, then login). Reported to the user on 2026-11-06.
- **Deviations v1 D39/D40** (test image) are closed in the rebuild (D142); the list is in [DEVIATIONS.md](docs/verification/evidence-2026-11-05/DEVIATIONS.md).
- **`gio open` does not start Okular under Wayland** (v1 D55): the DBus-activated process does not get `WAYLAND_DISPLAY`. Direct start works. Candidate fix: `dbus-update-activation-environment` or `systemctl --user import-environment` in the Plasma session.
- **Not verified:** Ark and Gwenview run in VM; Konsole tab completion in VM; LFS Chapter 8 long tests (Python, systemd, util-linux) not run (v1 D42).

## Where things are

- **Working tree:** `/home/yrslf/alpbahOS/wt-t2-kisayol` (branch `claude/t2-kisayol-2026-11-05`).
- **LFS chroot:** `/mnt/lfs`. Mount with `sudo bash scripts/lfs-blfs/mount_lfs.sh`; unmount with `scripts/lfs-blfs/umount_lfs.sh`. Run one writer at a time.
- **Work and scratch dir:** `/home/yrslf/alpbahOS/scratch-lfs-bench` (ISO build in `alp-iso/` and `alp-iso-out/`, rebuilt live ISO in `alp-iso-v2-20261106/`, installer targets and logs in `m11-runner/`, test passwords in `test-secrets/`, which is outside the repo).
- **Build scripts:** `scripts/lfs-blfs/` (installer runner: `scripts/lfs-blfs/calamares/runner/m11-run.sh`).
- **Profiles:** `profiles/` (shortcuts, apps, shell, desktop, perf). Generated shortcut file: `profiles/shortcuts/`.
- **Evidence:** `docs/verification/`. Handoffs: `docs/handoffs/claude/`.
- **Remote:** push target is `yoursel` only (D103).
