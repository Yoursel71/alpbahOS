# alpbahOS 1.0 pre-release: what must be done

Written 2026-11-13 after the first real-PC day on the SATA SSD install (RTX 5060, B450M). It lists what stands between today's state and a public "1.0 pre-release" (a GitHub Release with the pre-release flag). It uses the IDs of [BACKLOG.md](BACKLOG.md); evidence is in [verification/real-pc-ssd-cold-boot-2026-11-13.md](verification/real-pc-ssd-cold-boot-2026-11-13.md) and [verification/real-pc-nvidia-first-boot-2026-11-13.md](verification/real-pc-nvidia-first-boot-2026-11-13.md).

Status words follow BACKLOG.md. Nothing here is decided by the plan: every release needs the owner's approval (D108).

## 0. Decisions the owner must make first

Answered 2026-11-13 (D182, "Hepsi dahil"): questions 3, 4 and 5 are all "in" (Steam, Bottles, LUKS, dual boot, Chrome supported). Questions 1 and 2 (first public release vs alpha, tag name) are still open.

| # | Question | Why it matters |
|---|---|---|
| 1 | Is the 1.0 pre-release the first public release, replacing the planned ALPHA-01 (D108: repo public at the first alpha)? Or does an alpha come first? | BACKLOG ALPHA-01 is "Not started". The release plan and the visibility change (private to public) depend on this. Needs a new D-number. |
| 2 | Version and tag name, for example `v1.0.0-pre.1`, GitHub "pre-release" flag on. | The repo has a `v0.1.0-alpha.1` tag without an ISO. |
| 3 | Is Steam (STEAM-01, D111/D129) and Bottles (BOTTLES-01, D130) in 1.0, or listed as "not in 1.0"? | Both are "Not started" but the decisions promise them. Unmet promises must be in the known-issues list. |
| 4 | Is LUKS (INSTALL-LUKS-01, D139) and dual boot (INSTALL-DUALBOOT-01) in 1.0? | The test matrix (MASTER_PLAN section 13) requires "LUKS on and off; dual boot". Both are "Not started". |
| 5 | Which browser story: Firefox from the image, Chrome only as a user-installed Flatpak. | CHROME-DECOR-01 and the Flatpak defaults. |

## 1. Blockers: must be done before the pre-release

### 1.1 The system must start and stay up on real hardware
| ID | What | Done when |
|---|---|---|
| NVIDIA-DEVNODE-01 | Put `/usr/lib/tmpfiles.d/alpbahos-nvidia.conf` into the `nvidia` alp recipe (hand fix proven on one boot, 15:26 on 2026-11-13). | Three cold boots on the RTX 5060 with the wait script silent. |
| NVIDIA-SDDM-01 | The image ships the SDDM Wayland drop-in (kwin_wayland compositor), with and without the `nvidia` package. | A fresh install plus first reboot reaches the greeter with no TTY visit. |
| NVIDIA-SLEEP-01 and SUSPEND-01 | Enable `nvidia-suspend/resume/hibernate` (or drop `PreserveVideoMemoryAllocations`); suspend repeated hands-off with an RTC alarm. | 5 suspend/resume cycles on the RTX 5060, desktop and sound back each time. |
| DRIVERS-01, NVIDIA-PKG-01, INSTALLER-UI-01, INSTALLER-02 | The installer driver page installs the NVIDIA driver on the first boots; installer look finished. | A real-PC install with the NVIDIA choice ends on a working desktop. |
| BOOT-DEBUG-01 | The install gate rejects `rd.debug`, `systemd.log_level=debug`, `ignore_loglevel` in a non-DEBUG image; `splash` present (Plymouth). | Gate script fails on a planted debug cmdline. |
| KERNEL-CONFIG-01 | A supported `CONFIG_DRM_PANIC_SCREEN`. | No `Unsupported value` line at boot. |

### 1.2 Daily use must work without terminal knowledge
| ID | What |
|---|---|
| DESKTOP-SVC-01 | Build and enable udisks2, upower, rtkit (bolt if Thunderbolt stays): USB sticks mount from Dolphin, power state shows, no PipeWire RTKit errors. |
| WIFI-REGDB-01 | `wireless-regdb` so Wi-Fi uses the Turkish regulatory domain. |
| PATH-SBIN-01 | `/usr/sbin` in every user's PATH. |
| TOOLS-01 | At least `mesa-demos`, `vulkan-tools`, `libva-utils`, `smartmontools`, `nvme-cli` in the catalogue (support and test needs them). |
| AUDIO-WP-01 | Fix the BLE MIDI WirePlumber error (cause found: no bluez5/midi SPA plugin). |
| FONT-SYMBOLS-01 | A font with U+2300-23FF in the image (Noto Sans Symbols 2 and GNU FreeMono were enough for Claude Code and similar terminal tools). |
| CHROME-DECOR-01 | Flatpak browsers show minimize/maximize/close by default. |
| GREETER-02, PLASMA-LOCALE-01 | Greeter QML fix, cursor theme; UTF-8 locale for D-Bus helpers. |
| STORE-01, FLATHUB-01, ALP-FLATHUB-01, ALP-TR-01 | Discover works with alp and Flathub, Turkish messages. |
| APPS-01, APPS-02 | LibreOffice, VLC, Firefox: finish and verify on the real PC (Firefox window, not only headless). |
| PRINT-01 | Printing proven on a real printer (QEMU only so far). |

### 1.3 Security and trust
| ID | What |
|---|---|
| ALP-TRUST-01 | The signed catalogue uses temporary build keys (D173, `alp-keyring 1-temporary`). Real keys, key custody and a rotation note are needed before anything is public. |
| SEC-KWRITED-01 | Decide whether `/usr/bin/kwrited` must be setuid; fix the mode. |
| NET-EXPOSE-01 | Decide on LLMNR (listening on 0.0.0.0:5355); record the decision. |
| IMAGE-01 | The release image has no test account, test password, test font or embedded key (AGENT.md rule); unique machine-id and SSH host keys made on first boot. Includes removing the sudo password that was typed in chat sessions from any image or record. |
| FIREWALL-01 | Already done; keep in the matrix. FIREWALL-UI-01 and APPARMOR-01 can be listed as "not in 1.0". |

### 1.4 Release process (MASTER_PLAN section 12 gate)
1. User approval for the release and for the visibility change (D108).
2. Run the whole test matrix (MASTER_PLAN section 13) on the **final** ISO, record each row as PASS / FAIL / not run: BIOS and UEFI (QEMU and a real PC each), 4 GiB RAM idle test (PERF-01, target at or below 1 GiB), install with LUKS on and off and dual boot (if in scope), school-lab accounts and lock screen, ex-Windows checklist, terminal, store, desktop 30-minute stability.
3. BETA-01: the user boots the release USB on at least one real PC per boot mode; device list and results recorded. Today: one PC (UEFI); the r48 ISO booted from the Ventoy USB and the SSD install runs; a BIOS-mode real PC has not been tested.
4. SHA-256 for every ISO, release notes, known-issues list (everything in section 3 below).
5. Licence and source record for every shipped package and the image; `LICENSE` is GPL-3.0 (D109); NVIDIA files are downloaded at install time and not redistributed (D165).
6. Upload ISOs to GitHub Releases with the pre-release flag (D107); source stays in the repo.

## 2. Should be done (raises quality, not a hard block)
| ID | What |
|---|---|
| ALP-TEST-01 | alp test that fails on a machine with distrobox and podman; make `alp_plan` raise a clear error on non-JSON output. Fix before CI is trusted as the release gate. |
| HW-NOTES-01, TPM-UDEV-01 | Classify the boot-log noise; fix or allowlist (`tpm2_id`, pcspkr, TDX, usb 1-5). |
| Boot time | About 1 min 20 s now on the SSD PC (firmware 32 s, "kernel" 33 s with `usbcore.initial_descriptor_timeout=1000`, userspace 9 s). Find what the remaining about 24 s fixed part is; document the BIOS setting for unused USB ports. |
| PERF-01 | Idle RAM measured over hours (leak check); today one 5-minute snapshot: 1.5 GiB used of 24 GiB, about 1.1 GiB without the Claude session. |
| REBUILD-R5, SHELL-R4-01, FW-DIRLINK-01, XWAYLAND-01, MESA-01, VAAPI-01, SENSORS-01, FONTS-01 | Finish the "Partial" rebuild and hardware items; each needs its acceptance line in BACKLOG. |
| WELCOME-02, THEME-02, GLASS-01 | Welcome app and theme polish; Glass stays optional (D116). |
| RECOVER-UX-01, GRUB-OTHERS-01, GRUB-CR0-01 | Recovery and boot-menu polish. |
| Documentation | English live docs (D102) and the Turkish docs site (`site/`) updated for the release. |

## 3. Can be listed as "known issues" in the release notes (do not wait for them)
Steam and Bottles if the owner decides they are out (decision 3), AppArmor, firewall settings page, Secure Boot (D139: later), atomic updates, Distrobox box (DISTROBOX-01, ALP-KUTU-01), Thunderbolt, Wi-Fi/Bluetooth on hardware not tried, suspend on other machines, 4 GiB real PC if none is available.

## 4. Suggested order
1. Owner answers section 0 (one sitting).
2. Section 1.1 and 1.3 first: they decide whether a fresh install works and is safe. One cold-boot proof each on the RTX 5060.
3. Section 1.2 items, grouped by package build (udisks2, upower, rtkit, wireless-regdb, tools, fonts) in one REBUILD round.
4. One ISO build with everything, then the full matrix (1.4 step 2) and BETA-01 on a real PC.
5. Fix matrix failures, rebuild once, repeat only the failed rows.
6. Release notes, checksums, owner approval, upload.

## 5. What is already good (do not redo)
Live ISO and Calamares install (BIOS and UEFI), Turkish default and keyboard, KDE Plasma Wayland desktop with Windows-style taskbar, firewall on by default, signed alp catalogue code (with temporary keys), NetworkManager Wi-Fi, PipeWire audio, printing stack (QEMU), Flatpak, GRUB theme, Plymouth theme, NVIDIA driver on the RTX 5060 with `nvidia-smi` and rendering, suspend once, both SATA disks SMART-clean, 12 GB memory test clean, idle RAM about 1.1 GiB, 89 + 27 repo tests and the alp suite passing (one test environment-dependent), docs site builds.
