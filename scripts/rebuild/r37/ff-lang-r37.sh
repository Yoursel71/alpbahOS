#!/bin/bash
# Round 37 follow-up: Firefox UI language on the installed r37 image (the APPS row showed an English first-run tab).
# Boots an instrumented copy (matrix-r21.sh mkcopy/agent, MROUND=r37), closes the Welcome app, starts Firefox with
# about:preferences twice (first run creates the profile and installs the distribution language pack; second run),
# and logs the profile's language-pack state and locale prefs. Runs as the build user. Copy removed at the end.
set -u
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
cd "$WT"
M() { env MROUND=r37 bash scripts/rebuild/r21/matrix-r21.sh "$@"; }
D=/home/yrslf/alpbahOS/scratch-lfs-bench/lfs13-logs/iso-beta-0.9/r37/matrix
R=$D/${NAME:-FF1}
G() { python3 scripts/rebuild/r21/gsh.py "$R" "$@"; }
M mkcopy uefi "${NAME:-FF1}-disk"
M agent "${NAME:-FF1}" uefi "${NAME:-FF1}-disk" virtio 6G
G 10 'pkill -u testuser alpbah-hosgeld; sleep 2; echo "welcome left: $(pgrep -u testuser -c alpbah-hosgeld)"'
for run in 1 2; do
  G 15 'r21m-as-user --bg firefox about:preferences; echo started'
  sleep 40; M shot "${NAME:-FF1}" "ff-run$run-prefs"
  M key "${NAME:-FF1}" alt; sleep 2; M shot "${NAME:-FF1}" "ff-run$run-menubar"
  G 20 'P=$(ls -d /home/testuser/.mozilla/firefox/*.default* 2> /dev/null | head -n 1); echo "profile: $P";
    echo "langpack in extensions.json: $(grep -o "\"id\":\"langpack-tr@firefox.mozilla.org\"[^}]*\"active\":[a-z]*" "$P/extensions.json" 2> /dev/null | head -c 300)";
    echo "extensions dir: $(ls "$P/extensions" 2> /dev/null | tr "\n" " ")";
    echo "prefs: $(grep -E "intl\.|extensions\.autoDisable" "$P/prefs.js" 2> /dev/null | tr "\n" " ")";
    echo "env LANG of session: $(tr "\0" "\n" < /proc/$(pgrep -u testuser -x plasmashell | head -n 1)/environ | grep -E "^LANG=|^LANGUAGE=|^LC_ALL=" | tr "\n" " ")"'
  G 10 'pkill -u testuser firefox; sleep 4; echo "left: $(pgrep -u testuser -c firefox)"'
done
M quit "${NAME:-FF1}"
rm -f "$D/${NAME:-FF1}-disk.raw"
echo "ff-lang-r37 done $(date +%T)"
