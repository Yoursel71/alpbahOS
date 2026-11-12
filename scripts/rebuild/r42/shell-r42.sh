#!/bin/bash
# SHELL-R4-01 (D119, round 42): the rebuilt image had no Zsh setup (T3 was proven on the v1 base only): the installer
# gave new users bash, no plugins, no profile. Three records, run as root on the host (r4-root's only writer):
#   zsh-autosuggestions 0.7.1, zsh-syntax-highlighting 0.8.0: upstream tag archives, sha512 = Fedora's sources files
#     (not in BLFS 13.1); plain zsh scripts, copied to /usr/share/<name>/.
#   alpbahos-zsh-profile-r42: /etc/alpbahos/zshrc.alpbah (profiles/shell), /etc/zsh/zshrc (loads it in every
#     interactive Zsh), /etc/zsh/zprofile (a login Zsh takes over the environment of the bash login files, because
#     /etc/profile is bash), /etc/skel/.zshrc (no zsh-newuser-install wizard), /etc/shells with zsh, and
#     /etc/default/useradd SHELL=/bin/zsh; the last two are taken over from alpbahos-ch09-general and the shadow record.
# The installer's users.conf (userShell /bin/zsh) is in the ISO tree. root keeps bash.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=${TARGET_ROOT:-$SB/r4-root}
S=$SB/apps01-src/shell
W=$SB/r42/shell
cd "$WT"
rm -rf "$W" && mkdir -p "$W"
chk() { [ "$(sha512sum < "$S/$1" | cut -c1-128)" = "$2" ] || { echo "sha512 != Fedora: $1"; exit 1; }; }
chk zsh-autosuggestions-0.7.1.tar.gz 52c9dc8e9c4ba31788cf6c25448dbb8341545af7f763903533133d92a93e898256187e2f94b37c384926d9615b3bd61b7c6dd61337e1f47ae3babed813f9cc0b
chk zsh-syntax-highlighting-0.8.0.tar.gz 58593c8bf3fa1476ecf0fceb1fc4eab986a778de657d359a28fe48798e787896fbf2588441c69b017a08227ab44dd46473afb16e0f125aae59cc58004bfa8c2e
tar -xzf "$S/zsh-autosuggestions-0.7.1.tar.gz" -C "$W"
tar -xzf "$S/zsh-syntax-highlighting-0.8.0.tar.gz" -C "$W"
A=$W/stage-autosuggestions/usr/share/zsh-autosuggestions
install -D -m 644 "$W/zsh-autosuggestions-0.7.1/zsh-autosuggestions.zsh" "$A/zsh-autosuggestions.zsh"
install -m 644 "$W/zsh-autosuggestions-0.7.1/LICENSE" "$A/LICENSE"
H=$W/stage-highlighting/usr/share/zsh-syntax-highlighting
install -d "$H"
( cd "$W/zsh-syntax-highlighting-0.8.0" && install -m 644 zsh-syntax-highlighting.zsh .version COPYING.md "$H/" \
  && echo 0.8.0 > "$H/.revision-hash" \
  && find highlighters -type f ! -path '*/test-data/*' -exec install -D -m 644 {} "$H/{}" \; )
P=$W/stage-profile
install -D -m 644 profiles/shell/zshrc.alpbah "$P/etc/alpbahos/zshrc.alpbah"
install -D -m 644 profiles/shell/zsh/zprofile "$P/etc/zsh/zprofile"
install -D -m 644 profiles/shell/zsh/zshrc "$P/etc/zsh/zshrc"
install -D -m 644 profiles/shell/zsh/skel.zshrc "$P/etc/skel/.zshrc"
install -D -m 644 "$R4/etc/shells" "$P/etc/shells"
grep -qx /bin/zsh "$P/etc/shells" || sed -i 's|^# End /etc/shells|/bin/zsh\n/usr/bin/zsh\n\n# End /etc/shells|' "$P/etc/shells"
grep -qx /bin/zsh "$P/etc/shells" || { echo "/etc/shells not changed"; exit 1; }
install -D -m 644 "$R4/etc/default/useradd" "$P/etc/default/useradd"
sed -i 's|^SHELL=.*|SHELL=/bin/zsh|' "$P/etc/default/useradd"
grep -qx 'SHELL=/bin/zsh' "$P/etc/default/useradd"
rec() { bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py "$1" "$2" "$3" "$1" "$2"; }
recorded() { python3 -c 'import json,sys; sys.exit(0 if sys.argv[2] in json.load(open(sys.argv[1]))["packages"] else 1)' "$R4/var/lib/alp/db.json" "$1"; }
recorded zsh-autosuggestions || rec zsh-autosuggestions 0.7.1 "$W/stage-autosuggestions"
recorded zsh-syntax-highlighting || rec zsh-syntax-highlighting 0.8.0 "$W/stage-highlighting"
# r42b: zprofile exports with typeset -gx (a plain export inside a function is local in Zsh, so new variables such as
# QT_PLUGIN_PATH and XDG_DATA_DIRS were lost; seen in the chroot comparison)
PROF=${PROFILE_REC:-alpbahos-zsh-profile-r42c}   # r42c: name check with character classes (Turkish I in [A-Z] ranges)
recorded "$PROF" && { echo "$PROF already recorded"; exit 1; }
REPLACE=1 rec "$PROF" "0.9-${PROF##*-}" "$P"
echo "shell-r42 done"
