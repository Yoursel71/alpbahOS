#!/bin/bash
# Round 21 matrix row U2: sound facts, run by the diagnostic unit of diag-r21.sh (DIAG_HOOK) on the test copy.
# The sink questions run as the test user with the environment of the running Plasma session.
as_user() { local P a=() e; P=$(pgrep -u testuser -x plasmashell | head -n 1)
  [ -n "$P" ] || { echo "no plasmashell of testuser"; return 3; }
  while IFS= read -r -d '' e; do case $e in XDG_*|WAYLAND_DISPLAY=*|DBUS_SESSION_BUS_ADDRESS=*|DISPLAY=*|HOME=*|USER=*|LOGNAME=*|PATH=*|LANG=*|LC_*=*) a+=("--setenv=$e") ;; esac
  done < "/proc/$P/environ"
  systemd-run --quiet --collect --pipe --wait --uid=testuser --gid=testuser "${a[@]}" "$@"; }
echo "sound /proc/asound/cards: $(tr '\n' ' ' < /proc/asound/cards 2>&1)"
echo "sound lspci audio: $(lspci 2>/dev/null | grep -i audio | tr '\n' ' ')"
echo "sound aplay path: $(command -v aplay || echo 'aplay not installed')"
aplay -l 2>&1 | head -n 6 | sed 's/^/sound aplay -l: /'
as_user pactl list short sinks 2>&1 | sed 's/^/sound pactl sinks: /'
as_user wpctl status 2>&1 | sed -n '/Audio/,/Video/p' | head -n 20 | sed 's/^/sound wpctl: /'
