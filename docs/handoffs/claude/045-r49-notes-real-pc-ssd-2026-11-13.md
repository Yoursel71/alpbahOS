Task / status: notes for round 49 from the first real-PC run of alpbahOS on the SATA SSD (sdb, ESP + ext4 root),
read on 2026-11-13 from the Claude session that ran inside that install (`/home/alp/.claude`, repo copy at
`/home/alp/alpbahOS-repo/src`, its record `docs/verification/real-pc-nvidia-first-boot-2026-11-13.md`). Nothing here is
built yet; r48 stays the newest ISO.

Behaviour (real RTX 5060, recipe nvidia 620.70.06, kernel 7.1.8-alpbahos):
- `alp install nvidia` worked on the real GPU (550 MB download, -j1 build over 10 min). `nvidia-smi`, 8151 MiB, CUDA
  13.5, modules nvidia/modeset/drm/uvm loaded, Plasma Wayland session, 0 failed units, 0 coredumps, nouveau blacklisted.
  This is the first real-hardware proof of NVIDIA-PKG-01 (D179 asked for it).
- Also passed there: 12 GB memory pattern test, SMART on both disks, Wi-Fi (rt2800usb) and Bluetooth, GPU render test.
- Failed or hand-fixed: SDDM on X11 crashed (NVIDIA-SDDM-01), device nodes missing on cold boot (NVIDIA-DEVNODE-01),
  suspend (NVIDIA-SLEEP-01), debug GRUB parameters (BOOT-DEBUG-01). All fixes are by hand on that install only.
- A cold boot with the hand fixes was not tested: the reboot at 14:19 landed in Fedora because the UEFI entries had been
  deleted earlier (UEFI-ENTRY-01). Entry re-created: `Boot0000 alpbahOS (SSD)`, Fedora stays first in BootOrder.

r49 plan (in this order):
1. Put the Wayland SDDM config (NVIDIA-SDDM-01) and the devnode fix (NVIDIA-DEVNODE-01) into the image/recipe, ideally
   a proper root cause (udev rule or nvidia-modprobe) instead of the wait script.
2. `quiet` by default (BOOT-DEBUG-01). Look into NVIDIA-SLEEP-01 and the other bugs listed in that record
   (DESKTOP-SVC-01, KERNEL-CONFIG-01, AUDIO-WP-01, GREETER-02, PLASMA-LOCALE-01, PATH-SBIN-01, TOOLS-01, NET-EXPOSE-01,
   SEC-KWRITED-01; their text is only in the SSD copy of BACKLOG, copy it over before starting).
3. Cold-boot test on the real PC from "alpbahOS (SSD)" with the fixes, then the r49 ISO matrix in QEMU as usual.

Known issues:
- The SSD copy of the repo (`/home/alp/alpbahOS-repo/src`) has no git; its docs are not in `yoursel` main.
- The agent session on the SSD typed the user's sudo password (`2011`) in commands and chat; it is in that
  transcript and in this PC's history. The user should change it.
- The Ventoy USB (`/dev/sdc`, exFAT data partition with the r48 ISO and an alpbahOS GRUB theme in `/ventoy/theme/`)
  was installed this session; the ISO sha256 matched; boot from it is not tested.

Next single action: cold boot "alpbahOS (SSD)" on the real PC, then start r49 item 1.
