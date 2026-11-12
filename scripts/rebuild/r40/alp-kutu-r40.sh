#!/bin/bash
# Round 40 (D164, ALP-KUTU-01): the Debian box in alp, and the package-manager hint.
#   alp-kutu-r40 0.9-trust1.2: /usr/lib/alp/alp.py with the Debian box ('alp install <name>': alp catalogue, then the
#     Flathub app on an exact match, then apt in the user's Debian 13 Distrobox box; 'alp install --kutu', 'alp remove'
#     and 'alp list' for box packages). Takes alp.py over from alp-flathub-r40 (REPLACE=1). Signed-catalogue code is
#     unchanged, so the ISO trust gate keeps passing.
#   alpbahos-pm-hint-r40 0.9-r40: /usr/libexec/alpbahos/pm-hint (profiles/shell/pm-hint.sh) with /usr/bin links apt,
#     apt-get, apt-cache, aptitude, dnf, yum, pacman, zypper (D123: the hint also under sudo), and
#     /etc/profile.d/alp-local-bin.sh (~/.local/bin appended to PATH for the box's exported commands).
# r40b (alp-kutu-r40b 0.9-trust1.3): the image has no runuser/setpriv (LFS util-linux), so alp switches to the sudo user
#   itself (--alp-internal-as-user); plain root in fallback mode skips the box. The hint record is made only once.
# Run as root. Env TARGET_ROOT/LEDGER_DIR (apply-r7.sh) for another root.
set -euo pipefail
ALP_REC=alp-kutu-r40b ALP_VER=0.9-trust1.3
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
ST=$SB/r40/stage-alp-kutu
rm -rf "$ST" && install -D -m 755 "$WT/docs/handoffs/ai/alp-prototype/alp.py" "$ST/usr/lib/alp/alp.py"
grep -q 'def _as_user_main' "$ST/usr/lib/alp/alp.py"
cd "$WT"
R4=${TARGET_ROOT:-$SB/r4-root}
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py $ALP_REC $ALP_VER "$ST" $ALP_REC $ALP_VER
if [ -e "$R4/usr/libexec/alpbahos/pm-hint" ]; then echo "pm-hint already recorded"; else
SH=$SB/r40/stage-pm-hint
rm -rf "$SH"
install -D -m 755 "$WT/profiles/shell/pm-hint.sh" "$SH/usr/libexec/alpbahos/pm-hint"
install -D -m 644 "$WT/profiles/shell/alp-local-bin.sh" "$SH/etc/profile.d/alp-local-bin.sh"
install -d "$SH/usr/bin"
for n in apt apt-get apt-cache aptitude dnf yum pacman zypper; do ln -s ../libexec/alpbahos/pm-hint "$SH/usr/bin/$n"; done
bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-pm-hint-r40 0.9-r40 "$SH" \
    alpbahos-pm-hint-r40 0.9-r40
fi
chroot "$R4" /usr/bin/apt install htop 2>&1 | head -3 || true
echo "alp-kutu-r40 done"
