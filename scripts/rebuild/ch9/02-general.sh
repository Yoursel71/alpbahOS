#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1-systemd, chapter 9: hostname and hosts, "Configuring the System Clock" (time zone
# symlink only), "Configuring the Linux Console", "Configuring the System Locale", inputrc and /etc/shells.
# Values approved by the user: hostname alpbahos; locales tr_TR.UTF-8 (system default) and en_US.UTF-8;
# time zone Europe/Istanbul; KEYMAP=trq; FONT=eurlatgr.
# Not written: /etc/adjtime (book default is UTC; no dual boot), and the timedatectl/localectl steps
# (they need a running systemd; /etc/localtime, /etc/vconsole.conf and /etc/locale.conf are the files they write).
set -euo pipefail

echo alpbahos > /etc/hostname

cat > /etc/hosts << "EOF"
# Begin /etc/hosts

127.0.0.1 localhost
127.0.1.1 alpbahos
::1       ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters

# End /etc/hosts
EOF

# Locales: build with localedef only when the locale archive lacks them. The here-string keeps
# locale -a out of a pipe, so set -o pipefail cannot trip on grep -q exiting early.
avail=$(locale -a)
for loc in tr_TR en_US; do
    if ! grep -qix "${loc}.utf8" <<< "$avail"; then
        localedef -i "$loc" -f UTF-8 "${loc}.UTF-8"
    fi
done
avail=$(locale -a)
grep -qix "tr_TR.utf8" <<< "$avail"
grep -qix "en_US.utf8" <<< "$avail"

cat > /etc/locale.conf << "EOF"
LANG=tr_TR.UTF-8
EOF

cat > /etc/profile << "EOF"
# Begin /etc/profile

for i in $(locale); do
  unset ${i%=*}
done

if [[ "$TERM" = linux ]]; then
  export LANG=C.UTF-8
else
  source /etc/locale.conf

  for i in $(locale); do
    key=${i%=*}
    if [[ -v $key ]]; then
      export $key
    fi
  done
fi

# End /etc/profile
EOF

# Console: the keymap and font must exist in the kbd package.
test -f /usr/share/keymaps/i386/qwerty/trq.map.gz
test -f /usr/share/consolefonts/eurlatgr.psfu.gz
cat > /etc/vconsole.conf << "EOF"
KEYMAP=trq
FONT=eurlatgr
EOF

# Time zone (book clock page: the timedatectl step is replaced by the symlink it writes).
test -f /usr/share/zoneinfo/Europe/Istanbul
ln -sfv /usr/share/zoneinfo/Europe/Istanbul /etc/localtime

cat > /etc/inputrc << "EOF"
# Begin /etc/inputrc
# Modified by Chris Lynn <roryo@roryo.dynup.net>

# Allow the command prompt to wrap to the next line
set horizontal-scroll-mode Off

# Enable 8-bit input
set meta-flag On
set input-meta On

# Turns off 8th bit stripping
set convert-meta Off

# Keep the 8th bit for display
set output-meta On

# none, visible or audible
set bell-style none

# All of the following map the escape sequence of the value
# contained in the 1st argument to the readline specific functions
"\eOd": backward-word
"\eOc": forward-word

# for linux console
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": beginning-of-history
"\e[6~": end-of-history
"\e[3~": delete-char
"\e[2~": quoted-insert

# for xterm
"\eOH": beginning-of-line
"\eOF": end-of-line

# for Konsole
"\e[H": beginning-of-line
"\e[F": end-of-line

# uncomment for history search mode with up/down
# "\e[A": history-search-backward
# "\e[B": history-search-forward

# End /etc/inputrc
EOF

cat > /etc/shells << "EOF"
# Begin /etc/shells

/bin/sh
/bin/bash

# End /etc/shells
EOF

test "$(cat /etc/hostname)" = alpbahos
test "$(readlink /etc/localtime)" = /usr/share/zoneinfo/Europe/Istanbul
echo "OK 02-general"
