# Real PC: NVIDIA install and first boot (2026-11-13)

Machine: B450M-HDV R4.0, Ryzen 7 5700, RTX 5060 (10de:2d05), installed r4-root, kernel 7.1.8-alpbahos.

## What was done
- `sudo alp install nvidia` (recipe 620.70.06): download 550 MB, single-threaded module build (-j1, about 10+ minutes), installed to `/usr/lib/modules/7.1.8-alpbahos/extra/nvidia/`, rc 0.
- Reboot. After the reboot the desktop did not start (SDDM on X11, see NVIDIA-SDDM-01). A second Claude session switched `/etc/sddm.conf` to Wayland with kwin_wayland (backup `/etc/sddm.conf.bak`); that change is by hand on this install only and was not tested across a reboot.

## Result (boot 0, up from 13:44)
- Modules loaded: nvidia, nvidia_modeset, nvidia_drm, nvidia_uvm. `nvidia-smi`: RTX 5060, driver 620.70.06, 8151 MiB, CUDA UMD 13.5.
- Plasma Wayland session running. `systemctl --failed`: none. `coredumpctl`: none.
- nouveau stays blacklisted; this install is no longer on simple-framebuffer (`nvidia-drmdrmfb` is fb0).
- Not tested: suspend/resume, hibernate, reboot with the fixed SDDM config, Xwayland/GL apps, multi-monitor.


## Deeper checks (same day, read-only or non-disruptive; no GPU stress, no suspend)
| Check | Result |
|---|---|
| `tests/` without legacy | 89 passed |
| `tests/legacy` | passed (2 skipped) |
| `profiles/` | 27 passed |
| alp-prototype suite | 468 passed, 31 skipped, 1 failed (ALP-TEST-01) |
| shellcheck -S error, 976 shell files outside legacy/archive | 7 errors, all in the 4 files already in the baseline (`064-NetworkManager`, `184-cups`, `200-sddm`, `build_image7.sh`); nothing new |
| `bash -n` on every shell file, `ast.parse` on every `.py` | no syntax errors (the CI list script needs git, which is not on this PC, so the list was made with find) |
| Docs site (`npm ci && npm run build`, in a scratch copy) | builds, 2.05 s |
| `alp check` | no dependency problems (658 packages) |
| Firewall | iptables INPUT policy DROP, loopback/established/DHCP/mDNS allowed |
| Listeners | resolved (53, 5355), avahi 5353, cupsd 631 on loopback; nothing unexpected (two other loopback ports belong to the Claude tool itself) |
| Memory | 16 workers x 750 MB (12 GB) pattern write/verify for 75 s: 0 mismatches; no MCE, OOM, hung task or Xid in the kernel log; Tctl 42 C |
| Root ext4 (`/dev/sdb2`) | state clean, no journal errors, 23 GB used of 109 GB |
| Audio | HyperX Cloud III USB headset is the default sink and works; NVIDIA HDMI sink present; the board's Ryzen HD Audio (analog) has a card but no sink (nothing plugged in or jack detection, not diagnosed) |
| Not run | GPU stress or GL/Vulkan rendering (no tools, see TOOLS-01), suspend/resume (NVIDIA-SLEEP-01), SMART (no smartctl), a reboot with the fixed SDDM config, Wi-Fi and Bluetooth use |

## Bugs filed in docs/BACKLOG.md
NVIDIA-SDDM-01, NVIDIA-DEVNODE-01, SUSPEND-01, NVIDIA-SLEEP-01, DESKTOP-SVC-01, KERNEL-CONFIG-01, AUDIO-WP-01, GREETER-02, PLASMA-LOCALE-01, HW-NOTES-01, BOOT-DEBUG-01, PATH-SBIN-01, TOOLS-01, NET-EXPOSE-01, SEC-KWRITED-01, ALP-TEST-01.

## Tests of the untested list (14:00-14:17)
| Test | Result |
|---|---|
| GPU rendering (20 s QML scene, 400 animated layers, Wayland) | GPU clocks 232 -> 2745 MHz, 25-33 W, no kernel errors; renderer name not captured |
| SMART (ATA pass-through via SG_IO, no smartctl) | `/dev/sda` and `/dev/sdb`: PASSED; 0 reallocated, 0 pending, 0 uncorrectable; sdb SSD life left 94 % |
| Bluetooth (CSR dongle, `bluetoothctl scan`) | powered, found a device |
| Wi-Fi (rt2800usb USB adapter) | scan lists networks; joined `BahadirHome` (user's password): 192.168.1.130, 270 Mbit/s, HTTPS 200 (slow first request, 7.5 s) |
| Suspend | FAILED, see SUSPEND-01 |
| Reboot with the hand-fixed SDDM config | FAILED: no desktop, see NVIDIA-DEVNODE-01 |

Screen blanking, dimming, auto-suspend and auto-lock were turned off for the user (`~/.config/powerdevilrc`, `kscreenlockerrc`), at the user's request.

## Hand fixes applied on this PC (14:17-14:19), not yet in the image
- BOOT-DEBUG-01: `/etc/default/grub` `GRUB_CMDLINE_LINUX_DEFAULT` set to `'quiet'`, `grub-mkconfig` rerun (BIOS, grub.cfg lists alpbahOS, UEFI settings, Fedora). Backups: `/etc/default/grub.bak-debugcmdline`, `/boot/grub/grub.cfg.bak-debugcmdline`. Boot time after the change is not measured yet.
- NVIDIA-DEVNODE-01 workaround: `/usr/libexec/alpbahos-nvidia-wait` plus the drop-in `/etc/systemd/system/sddm.service.d/10-nvidia-devnodes.conf` (`ExecStartPre`, `TimeoutStartSec=90`). If an NVIDIA GPU is present it waits 10 s for `/dev/nvidiactl` and `/dev/nvidia0`, then tries `nvidia-modprobe -c0 -u`, then `mknod` with major 195, and always exits 0. Tested only in an isolated mount namespace (fallback made both nodes in 10 s); a real cold boot is not tested yet.
