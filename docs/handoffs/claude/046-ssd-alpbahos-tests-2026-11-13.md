For: the Claude session that runs inside alpbahOS on the SATA SSD (user `alp`, repo copy `/home/alp/alpbahOS-repo/src`).
From: the Claude session on the Fedora host (thewo), 2026-11-13. Same machine: B450M-HDV R4.0, Ryzen 7 5700, RTX 5060.

Status: the user booted the Ventoy USB (r48 ISO, `/dev/sdc`) on this PC and it worked, so the ISO boots on the real PC.
The SSD install still has hand fixes that were never tested across a cold boot. Run the list below on the SSD
install, write each result (PASS / FAIL / not run, command, output) into
`docs/verification/real-pc-ssd-cold-boot-2026-11-13.md` next to the first-boot record, and tell the user what failed.

Rules (user): do not reboot, suspend, stop sddm or touch UEFI entries without asking first (the user is at the PC).
Never type or store the sudo password in files or logs; ask the user to run privileged steps with `! sudo ...`.
Commit style: short lowercase casual, no Co-Authored-By trailer. There is no git on this PC: just edit the docs.

Tests, in this order:
1. Cold boot (user reboots from the UEFI menu, entry "alpbahOS (SSD)"): desktop comes up without a hand step.
   Check `systemctl --failed`, `coredumpctl`, `ls -l /dev/nvidiactl /dev/nvidia0`, `nvidia-smi`, `journalctl -b -p err`.
   Time to the greeter and to the desktop (`systemd-analyze`); GRUB is now `quiet` (BOOT-DEBUG-01).
2. NVIDIA-DEVNODE-01: do the device nodes exist because of the system or only because of
   `/usr/libexec/alpbahos-nvidia-wait`? Read `journalctl -b -u sddm` and the wait script's output; find out which step made the nodes.
3. NVIDIA-SDDM-01: `/etc/sddm.conf` has `DisplayServer=wayland` and the kwin_wayland compositor line; greeter appears,
   no crash of the greeter's kwin_wayland in `coredumpctl`.
4. Second cold boot (user reboots again) to show 1-3 are repeatable, not luck.
5. Suspend (NVIDIA-SLEEP-01): ask the user first. Check `nvidia-smi -q | grep -i persist` and
   `systemctl status nvidia-suspend nvidia-resume nvidia-hibernate`; if the units are missing, say so and propose the
   fix (recipe ships them, `NVreg_PreserveVideoMemoryAllocations=1`), do not apply it unasked.
6. Quick regressions of the r48 matrix on real hardware: `alp list`/`alp check`, Welcome app first-login marker, firewall
   (`iptables -S INPUT` policy DROP), zram, printing stack (`systemctl status cups avahi-daemon cups-browsed`), Flatpak
   (`flatpak list`), Firefox opens, sound (HyperX headset sink and NVIDIA HDMI sink), idle memory (`free -m` after 5 min).
7. Look at the remaining filed bugs (DESKTOP-SVC-01, KERNEL-CONFIG-01, AUDIO-WP-01, GREETER-02, PLASMA-LOCALE-01,
   PATH-SBIN-01, TOOLS-01, NET-EXPOSE-01, SEC-KWRITED-01): copy their BACKLOG rows into `docs/BACKLOG.md` of the host repo
   notes (the host repo is `Yoursel71/alpbahOS` main; the user or the host Claude commits it) and say which ones are
   still reproducible.

Report format: a table row per test (PASS / FAIL / not run), the evidence command and its output, and one line "next
single action". Keep long output in files.
