#!/bin/bash
# PLYMOUTH-01 (D160), round 23: record alpbahos-plymouth-theme 0.9-r23 (/usr/share/plymouth/themes/alpbahos from
# branding/plymouth-theme/alpbahos) and alpbahos-plymouth-config 0.9-r23 (/etc/plymouth/plymouthd.conf, taken over from
# the plymouth record: Theme=alpbahos, ShowDelay=0, DeviceTimeout=8, UseSimpledrm=1). Plymouth itself
# (plymouth 26.134.222) is recorded by pkg-url-r11.sh. Run as root on the host.
# UseSimpledrm=1: GPU drivers are modules outside the initramfs (D150), so without it Plymouth waits for a real DRM
# device; simpledrm uses the firmware framebuffer (GRUB gfxpayload=keep on BIOS, GOP on UEFI) from the start.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=$SB/r4-root
ST=$SB/r23/stage-plymouth
[ -x "$R4/usr/sbin/plymouthd" ] || { echo "plymouth missing in r4-root"; exit 1; }
rm -rf "$ST"
DONE=$(python3 "$WT/docs/handoffs/claude/alp-prototype/alp.py" --root "$R4" list 2>/dev/null | cut -f1)
install -d -m 755 "$ST/theme/usr/share/plymouth/themes/alpbahos" "$ST/config/etc/plymouth"
install -m 644 "$WT"/branding/plymouth-theme/alpbahos/* "$ST/theme/usr/share/plymouth/themes/alpbahos/"
cat > "$ST/config/etc/plymouth/plymouthd.conf" <<'CONF'
# alpbahOS (PLYMOUTH-01, D160). Defaults: /usr/share/plymouth/plymouthd.defaults.
[Daemon]
Theme=alpbahos
ShowDelay=0
DeviceTimeout=8
UseSimpledrm=1
CONF
chmod 644 "$ST/config/etc/plymouth/plymouthd.conf"
cd "$WT"
if ! grep -qx alpbahos-plymouth-theme <<< "$DONE"; then
bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-plymouth-theme 0.9-r23 \
    "$ST/theme" alpbahos-plymouth-theme 0.9-r23
fi
if ! grep -qx alpbahos-plymouth-config <<< "$DONE"; then
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-plymouth-config 0.9-r23 \
    "$ST/config" alpbahos-plymouth-config 0.9-r23
fi
# dracut reads only plymouthd.defaults when it builds a generic (--no-hostonly) initramfs: with UseSimpledrm=1
# there, its plymouth module depends on simpledrm instead of drm (all GPU drivers and their firmware: 221 MB instead
# of about 55 MB, seen 2026-11-10). So the distribution defaults file carries the same settings.
install -d -m 755 "$ST/defaults/usr/share/plymouth"
cat > "$ST/defaults/usr/share/plymouth/plymouthd.defaults" <<'CONF'
# alpbahOS distribution defaults (PLYMOUTH-01, D160); /etc/plymouth/plymouthd.conf overrides them.
[Daemon]
Theme=alpbahos
ShowDelay=0
DeviceTimeout=8
UseSimpledrm=1
CONF
chmod 644 "$ST/defaults/usr/share/plymouth/plymouthd.defaults"
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-plymouth-defaults 0.9-r23 \
    "$ST/defaults" alpbahos-plymouth-defaults 0.9-r23
chroot "$R4" /usr/sbin/plymouth-set-default-theme
ls "$R4/usr/share/plymouth/themes/alpbahos"
