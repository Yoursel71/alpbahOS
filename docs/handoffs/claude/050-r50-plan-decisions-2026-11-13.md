Task / status: r50 plan, 40 questions answered by the user on 2026-11-13 (AskUserQuestion). Nothing built yet from this list.

Real-PC findings behind it: first boot good; after the NVIDIA driver was installed Plasma did not start, tty worked (cause:
sddm weston line, fixed by `alpbahos-sddm-r50`, handoff 049). The image has no partition manager.

Decisions (number = question):
1  SSD test of the sddm fix waits for the r50 ISO (not now).
2  Greeter: Wayland (kwin_wayland) with X11 fallback.
3  Auto safe-graphics mode (simple framebuffer, no NVIDIA) after 2 failed Plasma starts.
4  After the NVIDIA install show a "restart" notification, no automatic reboot.
5  First boot without driver: nouveau stays blacklisted, simpledrm/EFI framebuffer.
6  Clean the small boot errors: tpm2_id, regulatory.db, pcspkr.
7-11 MirazParted = KDE Partition Manager (Qt6/KF6, latest stable KDE Gear compatible with Plasma 6), renamed everywhere (name,
   .desktop, icon, about dialog); GPL-3 notices kept and "derived from KDE Partition Manager" stated; icon: plain disk, navy
   palette, drawn by Claude (SVG); Turkish first (tr_TR).
12 Filesystem tools: ext4, FAT, NTFS, Btrfs only (no XFS, exFAT).
13 Root via polkit password dialog.
14 Installed system only, not in the live ISO.
15 Red warning + confirmation when editing the mounted system disk.
16 "Sert" = more rows, longer runs and the real PC.
17 Gate: installed root is `rw` and the greeter compositor is kwin_wayland (user said "idk"; Claude decided yes: cheap, and
   both failures slipped through r49).
18 NVIDIA row also checks nvidia-smi + a Plasma session; skipped without a GPU.
19 Every ISO gets a real-PC proof once on the USB; the round is not closed on QEMU alone.
20 Long run (5 h) and repeated suspend (10x) are in.
21 Welcome, PRINT, APPS rows rerun in full. 22 A failing row does not stop the round; the report lists all.
23 Persistent journal on in the normal ISO, verbose boot off.
24 udisks2, upower, rtkit, wireless-regdb in. 25 Only smartmontools and nvme-cli (no mesa-demos, vulkan-tools, libva-utils).
26 Adwaita Mono for U+23BF/U+23F5, with licence note. 27 BLE MIDI WirePlumber and D-Bus locale fixes in.
28 Kernel rebuild (DRM_PANIC) NOT this round. 29 CHROME-DECOR-01 default fix in.
30 Steam and Bottles IN r50 (user overrode the r51 advice). 31 LUKS and dual boot IN r50 (same). 32 One big ISO.
33 Delete the r48 ISO from disk (USB copy stays). 34 SSD: try `alp` update first, reinstall if it fails.
35 Commits: lowercase, spoken Turkish, no Claude trailer. 36 Push to `yoursel` main automatically at the end of r50.
37 Final report: short Turkish summary (passed / not proven on the real PC / what the user should try).
38 Autonomy: do everything, tell the user only about a very fatal error. 39 Source: latest stable KDE Gear matching Plasma 6.
40 Notes: handoff docs under docs/handoffs/claude (this series).

Risk: r50 now holds Steam, Bottles, LUKS and dual boot on top of MirazParted and the r49 leftovers; disk rule (>=30 GiB for the
ISO build, delete r48 first). If time runs short, cut Steam/Bottles/LUKS/dual boot first, keep graphics fixes + MirazParted.
