#!/bin/bash
# Round 23 (PLYMOUTH-01): boot timing and Plymouth state of an installed system, run by the diagnostic unit of
# diag-r21.sh (DIAG_HOOK) on the test copy. Times are CLOCK_MONOTONIC seconds since the kernel started (firmware
# and GRUB are not included), read from the journal of this boot.
mono() { journalctl -b -o short-monotonic --no-pager 2>/dev/null | grep -m1 -E "$1" | sed -E 's/^\[ *([0-9.]+)\].*/\1/'; }
echo "cmdline: $(cat /proc/cmdline)"
echo "t_sddm_started: $(mono 'Started (sddm.service|Simple Desktop Display Manager)')"
echo "t_greeter: $(mono 'sddm-greeter|Greeter (session )?started|Running: .*sddm-greeter')"
echo "t_user_session: $(mono 'pam_unix\(sddm:session\): session opened for user testuser')"
echo "t_switch_root: $(mono 'Switching root|switch_root|Reached target (Switch Root|initrd)')"
echo "plymouth units: $(systemctl is-active plymouth-start.service plymouth-quit.service plymouth-quit-wait.service 2>&1 | tr '\n' ' ')"
echo "plymouth in initramfs: $(lsinitrd /boot/initramfs-"$(uname -r)".img 2>/dev/null | grep -c -E ' usr/sbin/plymouthd$| usr/share/plymouth/themes/alpbahos/alpbahos.script$')"
echo "initramfs size: $(stat -c %s /boot/initramfs-"$(uname -r)".img 2>/dev/null)"
echo "plymouth default theme: $(plymouth-set-default-theme 2>/dev/null)"
echo "plymouth journal: $(journalctl -b --no-pager 2>/dev/null | grep -i plymouth | grep -v -i 'hook' | head -5 | tr '\n' '|')"
echo "systemd-analyze: $(systemd-analyze 2>&1 | head -1)"
