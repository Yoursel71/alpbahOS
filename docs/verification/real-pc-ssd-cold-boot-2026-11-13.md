# Real PC: SSD install after the hand fixes (2026-11-13, handoff 046)

Run by the Claude session inside alpbahOS on the SATA SSD, from `HANDOFF-046-ssd-tests.md` (written by the Fedora-host session).
Boot tested: one **warm reboot** (`systemctl reboot` at 14:40, up 14:42), not a cold boot from the UEFI menu. No reboot, suspend, sddm stop or UEFI change was done for the handoff; those need the user.

| # | Test | Result | Evidence |
|---|---|---|---|
| 1 | Desktop comes up without a hand step | PASS (warm reboot) | greeter at 80.4 s, user session at 88.0 s (monotonic); `systemctl --failed` empty; `coredumpctl`: no new entry (only the old 14:14:29 kwin_wayland); `/dev/nvidiactl` 195,255 and `/dev/nvidia0` 195,0 exist; `nvidia-smi`: RTX 5060, 620.70.06; `journalctl -b -p err`: usb 1-5 (-110/-71), TDX, pcspkr, `tpmrm0: Failed to find and pin callout binary /usr/lib/udev/tpm2_id` (new line, not filed) |
| 1b | Boot time | systemd-analyze 1 min 59 s = firmware 34.4 + loader 4.5 + "kernel" 66.8 + userspace 13.5. Loader fell from 13.1 s to 4.5 s. The "kernel" 66.8 s is NOT real kernel time, see the note below. Cmdline is `ro quiet` | `/proc/cmdline` |
| 2 | DEVNODE-01: who makes the nodes | **Only the workaround makes them** | `alpbahos-nvidia-wait`: "nodes missing after 10 s, trying nvidia-modprobe", then "creating nodes with major 195" (mknod). The udev rule's `nvidia-modprobe` runs and "succeeds" earlier (69.8 s) but creates neither node. So the system does not create `/dev/nvidiactl` and `/dev/nvidia0` by itself on any boot seen so far (3 boots), and the wait costs 10 s per boot (sddm start 70.2 s, started 80.3 s) |
| 3 | SDDM-01: config and greeter | PASS (warm reboot) | `DisplayServer=wayland`, `CompositorCommand=kwin_wayland --drm ...`; greeter started 80.6 s; no new greeter coredump |
| 4 | Second cold boot | not run | needs the user |
| 5 | Suspend (NVIDIA-SLEEP-01) | not run (asked first rule). Info only | `nvidia-suspend`, `nvidia-resume`, `nvidia-hibernate`: loaded, **disabled**; `Persistence Mode: Disabled`. Proposed fix (not applied): enable the three units (recipe ships them) because `NVreg_PreserveVideoMemoryAllocations=1` is set; also see SUSPEND-01 (suspend aborts with a pending wake, IRQ 28) |
| 6a | `alp list` / `alp check` | PASS | 658 packages; "Bağımlılık tutarlılığı: sorun yok" |
| 6b | Welcome first-login marker | PASS | `~/.config/alpbah-hosgeldin.tamam` exists |
| 6c | Firewall | PASS | `iptables -S INPUT`: `-P INPUT DROP` |
| 6d | zram | PASS | `/dev/zram0` 4 GiB swap, prio 100 |
| 6e | Printing stack | PASS | cups, avahi-daemon, cups-browsed active |
| 6f | Flatpak | PASS | `flatpak list` shows Google Chrome 157.0.8103.78, Freedesktop Platform 25.08.19, Mesa 26.2.5 |
| 6g | Firefox opens | PASS (headless) | Firefox 153.2.0esr, `--headless --screenshot` wrote a PNG; a shutdown JS error is printed (`AsyncShutdown`), harmless in headless mode, not checked in a window |
| 6h | Sound | PASS | default sink HyperX Cloud III Analog Stereo, NVIDIA HDMI sink present |
| 6i | Idle memory | not measured | 1696 MiB used at 2.5 min after boot (not 5 min idle) with the Claude session (363 MB), plasmashell 430 MB, kwin 311 MB running |
| 7 | Filed bugs still reproducible | see below | all 16 rows are in `docs/BACKLOG.md` of this copy |

## Correction to my own BOOT-DEBUG-01 claim
I said the debug cmdline made the "kernel" phase 66.8 s. Restoring `quiet` did not change it (66.8 s again). The kernel's own clock starts at about 67.6 s (`Linux version` is logged at 67.6 s monotonic, the TSC counts from power-on), so systemd-analyze's "kernel" figure is mostly that offset. Real time from kernel start to the greeter is about 12.7 s, of which 10 s is the NVIDIA node wait. Keep the debug-cmdline row (it still logged debug output to the console), but its boot-time claim was wrong.

## Bug status after this boot
Reproduced this boot: NVIDIA-DEVNODE-01 (nodes missing, hidden by the workaround), NVIDIA-SLEEP-01 (units disabled), PATH-SBIN-01 (not rechecked, PATH unchanged), KERNEL-CONFIG-01 and HW-NOTES-01 (usb 1-5, pcspkr, TDX still in `-p err`), DESKTOP-SVC-01 (UDisks2/UPower/rtkit not installed, not rechecked in the journal), GREETER-02, PLASMA-LOCALE-01, AUDIO-WP-01 (journal not rescanned for those lines). Not reproduced: NVIDIA-SDDM-01 (greeter works with the hand config; the image itself still has the stock x11 default). New: `tpm2_id` udev callout binary missing (tpmrm0).

Next single action: user does a real cold boot (power off, UEFI menu entry "alpbahOS (SSD)") to complete test 4, and says if suspend (test 5) may be tried.

## Suspend retry (14:44, user said go)
`rtcwake -m mem -s 60` as a detached unit. Result: **PASS with a caveat**. S3 entered 14:44:46, resumed 14:44:58 (about 12 s, not the 60 s alarm), `/sys/power/suspend_stats`: success 1, fail 0, errno 0. Wake source: IRQ 28 = `PCIe PME` on `0000:00:08.1` (the root port of the Ryzen USB/audio functions), most likely the USB keyboard (Logitech G213, `power/wakeup=enabled`) or a key/mouse touch by the user; not proven. After resume: desktop session alive, `nvidia-smi` RTX 5060 P0, no failed units, no new `-p err`. The first try (13:5x, before the reboot) failed with `Wakeup pending. Abort CPU freeze`; this one did not, so SUSPEND-01 is intermittent, not fixed. NVIDIA sleep units are still disabled, and this run did not need them for the suspend itself to complete. Whether the screen came back visibly was not seen by the agent.

User confirmation (14:5x): the PC really went to sleep, the user touched the keyboard (G213) and it woke and the screen came back. So the 12 s wake was the user, not a fault. The 60 s RTC alarm path was not exercised. Suspend/resume on the RTX 5060 with the NVIDIA sleep units still disabled: PASS once. The first try's `Wakeup pending. Abort CPU freeze` (before the reboot) may also have been a pending keyboard/USB event, not proven.

## Cold boot, 14:48 (user) and the usb 1-5 complaint
- Boot after a full power-off: desktop came up; systemd-analyze 1 min 53 s = firmware 28.8 + loader 3.9 + "kernel" 66.9 (clock offset, see above) + userspace 13.7. sddm +10.1 s (the node wait), NetworkManager-wait-online +5.4 s.
- usb 1-5 (xhci `0000:02:00.0`, the B450 chipset controller): `device descriptor read/64, error -110` x4, `not accepting address 5/6, error -71`, `unable to enumerate USB device`. Nothing is enumerated on 1-5 (present devices: 1-2 HyperX, 1-8 BT dongle, 1-9 SanDisk stick, 3-1 Ralink Wi-Fi, 5-1 G213, 5-2 G203). In the kernel log there is no time gap at those lines (all in the same few ms, the next gaps are 1.2 s, 3.2 s, then userspace), so Linux does not wait on it; the 28.8 s firmware time is the only part that may be affected, and that is outside the OS. A faulty device, cable or empty header on that port is the likely cause (not identified).
- `alpbahos-nvidia-wait` shortened from 10 s to 2 s (the nodes are never there at 2 s either, so the 10 s was waste). Saves about 8 s of sddm start. Real boot not re-measured yet.

## usb 1-5, user wants it skipped (14:56)
Wall-clock check (journal realtime): previous boot's last entry 14:52:24.9, this boot's first userspace entry 14:54:43.9 = 139 s (an earlier pair: 13:42:07 -> 13:44:35 = 148 s). systemd-analyze says firmware 32.5 + loader 4.6 + "kernel" 67.0 + userspace 8.8 = 113 s. The kernel log shows the usb 1-5 retries (4 x `device descriptor read/64 error -110`, power cycle, 2 x `not accepting address`, `unable to enumerate`) stamped within 0.5 ms, so the kernel timestamps are not trustworthy for this phase; the earlier claim that the "kernel" figure is only a clock offset is NOT proven and may be wrong (the real gap is about 2.3 min). The retry timeouts are 5 s each by default (`usbcore.initial_descriptor_timeout=5000`), which would add up to tens of seconds.
Applied: `GRUB_CMDLINE_LINUX_DEFAULT='quiet usbcore.initial_descriptor_timeout=1000'`, grub.cfg regenerated (backups `*.bak-usbtimeout`). This only shortens the descriptor-read part (4 x 5 s -> 4 x 1 s); the xHCI `Device not responding to setup address` timeouts (xhci command timeout) are not tunable by a parameter. There is no kernel parameter that skips one USB port; the port can be disabled in the BIOS or by removing the device/cable. Effect not measured yet: compare the realtime gap (139 s) after the next reboot.

## Finishing the handoff (14:59, user AFK, sudo allowed; no reboot, suspend or sddm stop was done)
**6i Idle memory (5 min after boot, desktop idle, the Claude session running):** 1495 MiB used of 23899 (available 22403). Top RSS: claude 382 MB, plasmashell 369, kwin_wayland 312, kded6 93, Xwayland 93. Without the Claude process about 1.1 GB. The 1 GiB design target was set for a 4 GiB machine, so this number is not directly comparable.

**Test 7, filed bugs re-checked against the journal of this boot (counts of the matching lines):**
| Bug | This boot |
|---|---|
| DESKTOP-SVC-01 | reproduced: UDisks2 x21, UPower x6, RTKit x15, Bolt x1; udisks2, upower, rtkit-daemon and bolt are not installed |
| KERNEL-CONFIG-01 | reproduced: `Unsupported value for CONFIG_DRM_PANIC_SCREEN` x1; the installed `/boot/config-7.1.8-alpbahos` has `"qr_code"` |
| AUDIO-WP-01 | reproduced (x2) and cause found: BLE MIDI monitor, no bluez5/midi SPA plugin (BACKLOG updated) |
| GREETER-02 | reproduced: `Main.qml:241:17 Parameter "username" is not declared` x1, `Failed to load cursor theme "default"` x1, `atomic commit failed` x1; the earlier `output layer configuration` line did not appear this boot |
| PLASMA-LOCALE-01 | reproduced: `not UTF-8` x3, `NewPrinterNotification` x1, `Failed to register with host portal` x18; `/etc/locale.conf` is `LANG=tr_TR.UTF-8` (so the D-Bus helpers do not get it) |
| PATH-SBIN-01 | reproduced: PATH `/usr/bin:/home/alp/.local/bin:/opt/qt6/bin`; `ip`, `ss`, `rfkill`, `iptables` all "command not found" for the user |
| TOOLS-01 | reproduced: eglinfo, glxinfo, vulkaninfo, vainfo, smartctl, nvme not present (checked earlier today) |
| NET-EXPOSE-01 | reproduced: 4 listeners on port 5355 (resolved, TCP/UDP, IPv4/IPv6) |
| SEC-KWRITED-01 | reproduced: `/usr/bin/kwrited` is `-rwsr-xr-x root` |
| HW-NOTES-01 | reproduced: usb 1-5, pcspkr x2, TDX x1, real time priority x6, drop supplementary groups x1 |
| NVIDIA-SLEEP-01 | reproduced: nvidia-suspend, nvidia-resume, nvidia-hibernate all `disabled` |
New this pass: WIFI-REGDB-01 (`regulatory.db` missing, 2 lines per boot) and TPM-UDEV-01 (`tpm2_id` missing). Backlog now has 18 rows from this session. No new failed unit and no new coredump since 14:14:29.

**Handoff status:** tests 1, 2, 3, 5 (user allowed), 6 and 7 done; test 4 partial (one cold boot at 14:48, then two warm reboots; the same results each time, but not two cold boots in a row). Not done and not mine: committing to the host repo (`Yoursel71/alpbahOS`), there is no git here; the host-side Claude or the user must copy `docs/BACKLOG.md`, `CURRENT.md` and this record. Next single action: a second cold boot to close test 4 and to measure the usb 1-5 timeout change (baseline gap 139 s between the last log line of the old boot and the first userspace line of the new one).

## Cold boot by RTC wake (15:14) and the usb timeout result
`rtcwake -m off -s 120` (detached unit): journal stopped 15:14:16, the PC powered itself off and **back on** (the board supports RTC wake from S5) and the new boot's first kernel line was 15:16:00, so this is a true cold boot (not a warm reboot). Result: desktop up, `systemctl --failed` empty, no new coredump (last one still 14:14:29), `/dev/nvidiactl` and `/dev/nvidia0` present because `alpbahos-nvidia-wait` made them again ("nodes missing after 2 s", "creating nodes with major 195") so NVIDIA-DEVNODE-01 is still real on a cold boot, `nvidia-smi` RTX 5060. This closes handoff test 4 (cold boot, nodes made only by the workaround, 5th boot in a row).
Boot time with `usbcore.initial_descriptor_timeout=1000`: `systemd-analyze` 1 min 16.5 s = firmware 28.8 + loader 5.3 + **kernel 33.2** + userspace 9.2. Before the parameter: 1 min 53 s with kernel 67.0 (and 66.9, 66.8 on the earlier boots). So the "kernel" phase halved (about 34 s less) and the total fell by 37 s; the usb 1-5 retries were therefore a real cost and not a clock offset (my earlier offset theory is wrong). The `usb 1-5` retry lines are still in the log (14 lines). About 33 s of the kernel phase remains; the xHCI `Device not responding to setup address` command timeouts are the likely rest, not tunable by a parameter.

## Screenshot 15:17 (user): box glyphs in Konsole
Filed as FONT-SYMBOLS-01. Fonts installed for the user only: FreeMono.ttf, NotoSansSymbols2-Regular.ttf in `~/.local/share/fonts` (fc-cache run). Konsole must be restarted to see them.

## FONT-SYMBOLS-01 confirmed (user, after restarting Konsole)
The user restarted Konsole and confirmed the boxes are gone: Claude Code's `⎿` (U+23BF) and `⏵⏵` (U+23F5) show as real symbols. The running Konsole (started 15:16:18) had read the font list before the fonts were installed (15:19), so a restart was needed. Fix on this PC: `~/.local/share/fonts/FreeMono.ttf` plus `NotoSansSymbols2-Regular.ttf`, user-level only. The image itself still has neither font, so the bug stays open for the image (FONT-SYMBOLS-01 in `docs/BACKLOG.md`).

## NVIDIA-DEVNODE-01 fix (15:23, user asked to solve it)
Diagnosis: on the real devtmpfs, `nvidia-modprobe -c0 -u` (as the udev rule runs it) returns 0 and silently creates only `/dev/nvidia-uvm` and `/dev/nvidia-uvm-tools`; in an isolated tmpfs `/dev` the same binary does create `nvidiactl` and `nvidia0` (it returns 1 there). The cause inside nvidia-modprobe is not found (no strace/ltrace on the image).
Fix: `/usr/lib/tmpfiles.d/alpbahos-nvidia.conf` (`c!` rules for `/dev/nvidiactl` 195:255, `/dev/nvidia0` 195:0, `/dev/nvidia-modeset` 195:254). `systemd-tmpfiles-setup-dev.service` runs before `systemd-udevd.service`, so the nodes exist before the driver loads and before SDDM. Isolated test: all three nodes created, rc 0. `alpbahos-nvidia-wait` and the SDDM drop-in stay as a safety net (they return at once when the nodes exist).
Limits: single GPU only (minor 0); the major 195 is NVIDIA's fixed frontend major (`/proc/devices` shows `195 nvidia`, `195 nvidiactl`).
**Proof still needed:** one boot. Expected after the next boot: `journalctl -b -t alpbahos-nvidia-wait` is empty (no "nodes missing"), `ls -l /dev/nvidiactl /dev/nvidia0` has the boot-time stamp, sddm starts without the 2 s wait, no new `kwin_wayland` coredump.

## NVIDIA-DEVNODE-01 fix proven on a boot (15:26-15:28) and a lower usb timeout (15:29)
Boot at 15:26 (warm reboot with the tmpfiles rule): `/dev/nvidiactl`, `/dev/nvidia0`, `/dev/nvidia-modeset` stamped 15:26:23 (boot time), `journalctl -b -t alpbahos-nvidia-wait` EMPTY (no "nodes missing"), sddm no longer in the top of `systemd-analyze blame`, no failed units, no new coredump (last still 14:14:29). So the tmpfiles fix works on a booted system (one boot; a second boot and a cold boot would make it firm).
Boot time at that boot: 1 min 21.4 s = firmware 32.3 + loader 7.1 + kernel 33.1 + userspace 8.8.
Kernel-phase figure versus `usbcore.initial_descriptor_timeout`: 5000 ms -> about 67 s, 1000 ms -> about 33 s. A straight line through those two points gives about 8.5 s per 1000 ms plus a fixed part of about 24.5 s, so 200 ms should give about 26 s (7 s less). Applied `usbcore.initial_descriptor_timeout=200` (grub.cfg regenerated, backups `*.bak-usbtimeout2`). Risk: a slow-starting USB device (some external HDDs) may fail its first descriptor read within 200 ms; revert by setting 1000 or 5000. Not measured yet.

## USB timeout back to 1000 ms, boot splash restored (15:31, user request)
The user wanted the timeout to stay at 1000 ms and the Plymouth boot screen back (no terminal text at boot). `GRUB_CMDLINE_LINUX_DEFAULT='quiet splash usbcore.initial_descriptor_timeout=1000'`, grub.cfg regenerated (backups `*.bak-splash`; the `200` value is not in use). Plymouth is installed with the `alpbahos` theme (`/etc/plymouth/plymouthd.conf`: `UseSimpledrm=1`, `DeviceTimeout=8`). `splash` was missing because the debug cmdline and then `quiet` alone replaced the installer's value. Not seen on screen by the agent; the user must say if the splash shows, and whether the NVIDIA driver taking over the display (nvidia-drm at about 1.3 s) makes it flicker or drop to text.

## Chrome window buttons (15:34, user screenshot) and idle RAM
Filed as CHROME-DECOR-01 (Flatpak Chrome shows only a close button; GTK decoration layout is correct but ignored; workaround: tab strip right-click, "Use system title bar and borders"). Not fixed on this PC yet; the user may apply the workaround.
Idle RAM answer given to the user (15:31, 5 min after boot, desktop idle): 1516 MiB used of 23899, buff/cache 1347 MiB, available 22382 MiB, zram swap unused. By group: KDE desktop about 1200 MB (plasmashell 362, kwin_wayland 309, Xwayland 91, kded6 91), system about 314 MB, audio 44 MB, the Claude session 390 MB, other 385 MB. Without the Claude session about 1.1 GB. One snapshot, no long-run leak check.

## CHROME-DECOR-01 workaround confirmed
The user enabled "Use system title bar and borders" in Chrome, closed it, and the agent found `custom_chrome_frame=False` already in Preferences (no edit was made; the file was left byte-identical). After reopening Chrome the user confirmed the minimize and maximize buttons appear. The bug stays open for the image: the default should not need this manual step.
