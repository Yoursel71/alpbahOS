#!/bin/bash
# Round 21 matrix, test copies only: runs a command as the test user with the environment of the running Plasma
# session (taken from plasmashell: XDG_RUNTIME_DIR, WAYLAND_DISPLAY, DBUS_SESSION_BUS_ADDRESS, ...).
# QML2_IMPORT_PATH is passed too (round 45: without it systemsettings aborts, "module org.kde.kirigami is not
# installed", because the KF6 QML modules are in /usr/lib/qml).
# Usage: r21m-as-user [--bg] <command> [args]     --bg: start it and return (GUI programs)
set -u
BG=0; [ "${1:-}" = --bg ] && { BG=1; shift; }
P=$(pgrep -u testuser -x plasmashell | head -n 1)
[ -n "$P" ] || { echo "r21m-as-user: no plasmashell of testuser"; exit 3; }
a=()
while IFS= read -r -d '' e; do
  case $e in XDG_*|WAYLAND_DISPLAY=*|DBUS_SESSION_BUS_ADDRESS=*|DISPLAY=*|HOME=*|USER=*|LOGNAME=*|PATH=*|LANG=*|LC_*=*|XAUTHORITY=*|QT_*=*|QML2_IMPORT_PATH=*|QML_IMPORT_PATH=*|KDE_*=*)
    a+=("--setenv=$e") ;; esac
done < "/proc/$P/environ"
if [ "$BG" = 1 ]; then
  exec systemd-run --quiet --collect --uid=testuser --gid=testuser --working-directory=/home/testuser "${a[@]}" "$@"
fi
exec systemd-run --quiet --collect --pipe --wait --uid=testuser --gid=testuser --working-directory=/home/testuser "${a[@]}" "$@"
