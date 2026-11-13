#!/bin/bash
# Round 47 (WELCOME-02): the Welcome row for design 4 ("Başlangıç merkezi"). The round 25 row (run-r25.sh welcome)
# looks for the old window colour and clicks the old card positions, so it finds no window on design 4. Design 4 opens
# centred at the same place on the 1280x800 test screen (window 160,8 - 1120,755); the positions below are taken from
# its first-login screenshot (round 47y). Verdicts come from the screenshots and the pixel checks in the log.
# Usage: ROUND=rNN welcome4-r47.sh   (uses scratch-lfs-bench/images/inst-bios-msdos-$ROUND.raw, test password r21.pw)
set -u
WT=/home/yrslf/alpbahOS/wt-t2-kisayol; cd "$WT"
B=/home/yrslf/alpbahOS/scratch-lfs-bench; RND=${ROUND:?ROUND=rNN}
L=$B/lfs13-logs/iso-beta-0.9/$RND; R=$L/W4; IMG=$B/images/inst-bios-msdos-$RND.raw
Q() { python3 "$WT/scripts/rebuild/image/qmpctl.py" "$@" > /dev/null 2>&1; }
G() { bash "$WT/scripts/rebuild/r24/vm-gui.sh" "$@"; }
log() { echo "[$(date +%T)] $*" | tee -a "$L/run.log"; }
# px <png> <x> <y>: the pixel colour; app <png>: "yes" when the window is there (blue "Uygula ve başla" button and
# the dark window body), else "no"
px() { python3 -c "from PIL import Image; print(*Image.open('$1').convert('RGB').getpixel(($2,$3)))"; }
app() { python3 -c "
from PIL import Image
im = Image.open('$1').convert('RGB')
# two points inside the 'Uygula ve başla' button, off its label: (1040, 703) hit the text when the button was in its
# hover colour and gave a false 'no' on the reopened window (rounds 47x and 48)
blue = any(b > 180 and r < 80 for r, g, b in (im.getpixel((940, 690)), im.getpixel((1060, 715))))
r2, g2, b2 = im.getpixel((640, 620))
print('yes' if blue and r2 + g2 + b2 < 120 else 'no')"; }
[ -f "$IMG" ] || { log "W4: no BIOS install $IMG"; exit 1; }
log "W4 (Welcome design 4, BIOS copy of $(basename "$IMG"))"
G start bios "$IMG" "$R"
G login "$R"; sleep 50; Q "$R" shot w01-first-login
log "W4 first login: app open: $(app "$R/w01-first-login.png")"
# choices: Atatürk (theme), Glass (disabled: must stay unselected), Ortada (taskbar)
Q "$R" click 410 345; sleep 1; Q "$R" click 709 345; sleep 1; Q "$R" click 1005 345; sleep 1
Q "$R" shot w02-choices-ataturk-orta
log "W4 choices: Atatürk $(px "$R/w02-choices-ataturk-orta.png" 300 345) / Glass $(px "$R/w02-choices-ataturk-orta.png" 600 345) / Ortada $(px "$R/w02-choices-ataturk-orta.png" 960 345)"
Q "$R" click 997 703; sleep 20; Q "$R" shot w03-desktop-ataturk-orta
log "W4 after apply: app open: $(app "$R/w03-desktop-ataturk-orta.png")"
# lock screen shows the chosen theme; the password unlocks
Q "$R" combo meta_l l; sleep 6; Q "$R" shot w04-locked
Q "$R" key shift; sleep 3; G type "$R" "$(cat "$B/test-secrets/r21.pw")"; Q "$R" key ret; sleep 6; Q "$R" shot w05-unlocked
# open again from the run dialog: alpbahOS + Solda, apply
Q "$R" combo alt f2; sleep 3; G type "$R" "alpbah-hosgeldin"; Q "$R" key ret; sleep 20; Q "$R" shot w06-reopened
log "W4 reopened: app open: $(app "$R/w06-reopened.png")"
Q "$R" click 275 345; sleep 1; Q "$R" click 868 345; sleep 1; Q "$R" shot w07-choices-alpbahos-sol
Q "$R" click 997 703; sleep 20; Q "$R" shot w08-desktop-alpbahos-sol
# quick start card: Yazıcı opens the printer settings page
Q "$R" combo alt f2; sleep 3; G type "$R" "alpbah-hosgeldin"; Q "$R" key ret; sleep 12
Q "$R" click 640 458; sleep 15; Q "$R" shot w09-quick-printer
# second login: power off, boot the same copy again, log in: the app must not open
Q "$R" powerdown; sleep 25; Q "$R" quit; sleep 3
G boot bios "$R" second
G login "$R/second"; sleep 50; Q "$R/second" shot w10-second-login
log "W4 second login: app open: $(app "$R/second/w10-second-login.png") (expected no)"
G stop "$R"
log "W4 end"
