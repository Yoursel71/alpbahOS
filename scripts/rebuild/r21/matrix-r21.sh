#!/bin/bash
# Round 21 beta matrix rows on ISO r21 (L2-L4, B2, B3, U2, FP-GUI, S1, R1, REC1, REC2, KF, F1). Runs as the build
# user on the host; sudo only for loop mounts. The two kept installs (inst-bios-msdos-r21.raw, inst-uefi-gpt-r21.raw)
# are used only through reflink copies with new names. Every sub-command refuses an existing run directory or
# target file; nothing is removed except reflink copies made by the same sub-command.
# Evidence: scratch-lfs-bench/lfs13-logs/iso-beta-0.9/r21/matrix/. Verdicts are written by the reviewer after the
# screenshots and logs are read (results21.tsv), never by this script.
#   sha                      sha256 of the ISO -> iso-sha256.txt
#   live <name> <fw> <accel> <seconds>     live boot, a screenshot every 30 s (L2, L3, L4)
#   diag <B2|B3|U2>          installed rows through diag-r21.sh (bus, RAM, NVMe bootindex, sound hook)
#   mkcopy <bios|uefi> <copy-name> [src]   reflink copy with the test shell unit (guest-agent-r21.sh)
#   agent <name> <bios|uefi> <copy-name> <bus> <mem>   boot an instrumented copy and log the test user in
#   s1 | r1 | fpgui          shutdown cycles, reboot, Flatpak Calculator in the session
#   apps                     APPS-01 (round 37+): Firefox, VLC, LibreOffice in the session; alp trust rows
#   check <copy-name> <label>              read-only look at a copy: coredumps and the last boot's journal
#   recprep, reclive, recboot              REC1/REC2: break a copy, repair it from the live ISO, boot it alone
#   kflive, kffill, kfgo, kfdisk, kfboot, kfagent   KF: Turkish F in the live session, install to a new image, checks
#   f1                                     forced-failure install (lane3 of r20-lanes.sh) and read-only facts
#   type, enter, key, combo, click, shot, run, quit   single manual steps on a running guest
# Guest typing (live session, Turkish Q): tq, with the AltGr keys for | > & etc.
set -u
B=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=${MATRIX_WT:-/home/yrslf/alpbahOS/wt-t2-kisayol}   # MATRIX_WT: run the helpers of another worktree
W=$WT/scripts/rebuild/image
S=$WT/scripts/rebuild/r21
MR=${MROUND:-r21}   # round 27+: MROUND=r27 (ISO, installs, password file and evidence directory of that round)
D=${MATRIX_DIR:-$B/lfs13-logs/iso-beta-0.9/$MR/matrix}
# ISO_PATH, IMGB_PATH, IMGU_PATH: the ISO and the two installs from another directory (e.g. a kept copy)
ISO=${ISO_PATH:-$B/images/alpbahos-beta-0.9-2026-11-09-$MR.iso}
IMGB=${IMGB_PATH:-$B/images/inst-bios-msdos-$MR.raw}
IMGU=${IMGU_PATH:-$B/images/inst-uefi-gpt-$MR.raw}
PWF=$B/test-secrets/$MR.pw
mkdir -p "$D"

q() { python3 "$W/qmpctl.py" "$@"; }
gsh() { python3 "$S/gsh.py" "$@"; }
fresh() { local e; for e in "$@"; do [ ! -e "$e" ] || { echo "REFUSED: $e exists"; exit 2; }; done; }
alive() { pgrep -f -- "-qmp unix:$1/qmp.sock" > /dev/null; }
waitq() { local i; for i in $(seq 1 "${2:-30}"); do alive "$1" || return 0; sleep 1; done
  echo "WARNING: QEMU still running for $1: pid $(pgrep -f -- "-qmp unix:$1/qmp.sock" | tr '\n' ' ')"; return 1; }
vmquit() { q "$1" quit 2> /dev/null; waitq "$1"; }
shot() { q "$1" shot "$2" > /dev/null 2>&1; rm -f "$1/$2.ppm"; }
stamp() { echo "[$(date +%F_%T)] $*"; }

# Turkish-Q typing through QMP key codes (xkb tr): - = equal, i = apostrophe, . = slash, / = shift 7, | = AltGr equal ...
tq() { local RUN="$1"; shift; local s="$*" i c
  for ((i=0; i<${#s}; i++)); do c=${s:i:1}
    case $c in
      -) q "$RUN" key equal ;;
      i) q "$RUN" key apostrophe ;;
      '*') q "$RUN" key minus ;;
      .) q "$RUN" key slash ;;
      :) q "$RUN" combo shift slash ;;
      /) q "$RUN" combo shift 7 ;;
      ' ') q "$RUN" key spc ;;
      '|') q "$RUN" combo alt_r equal ;;
      '>') q "$RUN" combo shift less ;;
      '<') q "$RUN" key less ;;
      '&') q "$RUN" combo shift 6 ;;
      '=') q "$RUN" combo shift 0 ;;
      _) q "$RUN" combo shift equal ;;
      ';') q "$RUN" combo shift backslash ;;
      ,) q "$RUN" key backslash ;;
      \") q "$RUN" key grave_accent ;;
      \') q "$RUN" combo shift 2 ;;
      '$') q "$RUN" combo alt_r 4 ;;
      '(') q "$RUN" combo shift 8 ;;
      ')') q "$RUN" combo shift 9 ;;
      '?') q "$RUN" combo shift minus ;;
      '{') q "$RUN" combo alt_r 7 ;;
      '}') q "$RUN" combo alt_r 0 ;;
      '[') q "$RUN" combo alt_r 8 ;;
      ']') q "$RUN" combo alt_r 9 ;;
      *) q "$RUN" text "$c" ;;
    esac; sleep 0.15; done; }

cmd_sha() { fresh "$D/iso-sha256.txt"; sha256sum "$ISO" | tee "$D/iso-sha256.txt"; }

cmd_live() { # name fw accel seconds
  local N=$1 FW=$2 ACC=$3 MAX=$4 R=$D/$1 T0 t; fresh "$R"
  T0=$(date +%s); stamp "$N start ($FW, $ACC)"
  ACCEL=$ACC bash "$W/vm-start.sh" "$FW" "$ISO" "$R" "" virtio 6G
  while :; do sleep 30; t=$(( $(date +%s) - T0 )); shot "$R" "shot-$(printf %04d "$t")"; [ "$t" -lt "$MAX" ] || break; done
  vmquit "$R"; stamp "$N end"; ls -l "$R"/*.png | awk '{print $5, $NF}'
}

cmd_diag() { # B2 | B3 | U2
  stamp "$1 start"
  case $1 in
    B2) OUTD=$D BUS=sata MEM=4G bash "$S/diag-r21.sh" bios "$IMGB" B2 ;;
    B3) OUTD=$D BUS=nvme MEM=2G NVME_BOOTINDEX=0 bash "$S/diag-r21.sh" bios "$IMGB" B3 ;;
    U2) OUTD=$D BUS=nvme MEM=4G EXTRA_ARGS="-device intel-hda -device hda-duplex" DIAG_HOOK=$S/hook-sound-r21.sh \
          bash "$S/diag-r21.sh" uefi "$IMGU" U2 ;;
    *) echo "unknown diag row $1"; exit 2 ;;
  esac
  stamp "$1 end"
}

# --- instrumented copies -------------------------------------------------------------------------------------
rootpart() { local p; for p in "$1"p*; do [ "$(sudo blkid -o value -s TYPE "$p")" = ext4 ] && echo "$p"; done | tail -n 1; }

cmd_mkcopy() { # bios|uefi copy-name [source-image]
  local SRC CP=$D/$2.raw M=$D/mnt-$2 LO P
  SRC=${3:-$([ "$1" = uefi ] && echo "$IMGU" || echo "$IMGB")}
  fresh "$CP" "$M"; cp --reflink=always "$SRC" "$CP"
  LO=$(sudo losetup -f -P --show "$CP"); P=$(rootpart "$LO")
  [ -n "$P" ] || { echo "no ext4 root in $CP"; sudo losetup -d "$LO"; rm -f "$CP"; exit 1; }
  mkdir "$M"; sudo mount "$P" "$M" || { sudo losetup -d "$LO"; rmdir "$M"; rm -f "$CP"; exit 1; }
  sudo install -m 755 "$S/guest-agent-r21.sh" "$M/usr/local/sbin/r21m-agent"
  sudo install -m 755 "$S/guest-as-user-r21.sh" "$M/usr/local/sbin/r21m-as-user"
  sudo install -m 644 "$S/guest-agent-r21.service" "$M/etc/systemd/system/r21m-agent.service"
  sudo mkdir -p "$M/etc/systemd/system/graphical.target.wants"
  sudo ln -sf /etc/systemd/system/r21m-agent.service "$M/etc/systemd/system/graphical.target.wants/r21m-agent.service"
  sudo umount "$M"; sudo losetup -d "$LO"; rmdir "$M"
  stamp "copy $CP made from $SRC (test shell unit added)"
}

agent_start() { # name fw copy-name bus mem   (NO_REBOOT, NVME_BOOTINDEX, EXTRA_ARGS from the caller)
  local N=$1 FW=$2 CP=$D/$3.raw BUS=$4 MEM=$5 R=$D/$1; fresh "$R"
  EXTRA_ARGS="${EXTRA_ARGS:-} -serial unix:$R/ser1.sock,server,nowait -qmp unix:$R/qmp-ev.sock,server,nowait" \
    ACCEL=kvm bash "$W/vm-start.sh" "$FW" "" "$R" "$CP" "$BUS" "$MEM" > /dev/null
  sleep 1; nohup setsid python3 "$S/qmp-events.py" "$R" > /dev/null 2>&1 &
  date +%s > "$R/t-start"
}
greeter_login() { # run-dir shot-prefix [password-file]: waits for the boot line of the test shell, then logs in
  local R=$1 P=$2 i PWFILE=${3:-$PWF}
  for i in $(seq 1 90); do grep -aq "R21M begin" "$R/serial.log" 2> /dev/null && break; sleep 2; done
  sleep 20; shot "$R" "$P-greeter"; q "$R" click 622 474; sleep 2; shot "$R" "$P-greeter-clicked"
  q "$R" text "$(cat "$PWFILE")"; q "$R" key ret
  for i in $(seq 1 60); do gsh "$R" 8 'pgrep -u testuser -x plasmashell > /dev/null && echo SESSION-UP' 2> /dev/null | grep -q SESSION-UP && break; sleep 3; done
  gsh "$R" 8 'echo "session: plasmashell pid $(pgrep -u testuser -x plasmashell | head -n 1), $(loginctl list-sessions --no-legend | tr -s " " | tr "\n" ";")"'
}
cmd_agent() { agent_start "$@"; greeter_login "$D/$1" "$1"; sleep 25; shot "$D/$1" "$1-desktop"; stamp "$1 session up"; }

# Read-only look at a copy after a cycle: coredump directory and the last boot's journal.
PAT="dumped core|core dump|coredump|core-dump|segfault|code=dumped|ABRT|SEGV|Failed to|Failed with result"
cmd_check() { # copy-name label
  local CP=$D/$1.raw M=$D/mnt-check-$1 O=$D/check-$1-$2.txt LO P JD OPT=ro
  fresh "$O" "$M"; LO=$(sudo losetup -r -f -P --show "$CP"); P=$(rootpart "$LO"); mkdir "$M"
  if ! sudo mount -o ro "$P" "$M" 2> /dev/null; then OPT=ro,noload; sudo mount -o ro,noload "$P" "$M"; fi
  JD=$(sudo find "$M/var/log/journal" -mindepth 1 -maxdepth 1 -type d | head -n 1)
  {
    echo "== check $1 $2 $(date -Is); mount option: $OPT (ro,noload means the ext4 journal was not clean)"
    echo "coredump dir: $(sudo ls -la "$M/var/lib/systemd/coredump" 2>&1 | tr '\n' ';')"
    echo "coredump entries: $(sudo find "$M/var/lib/systemd/coredump" -mindepth 1 2> /dev/null | wc -l)"
    echo "journal dir: $JD"
    echo "-- boots"; sudo journalctl --directory="$JD" --list-boots --no-pager 2>&1
    echo "-- last boot: first and last line"
    sudo journalctl --directory="$JD" -b 0 --no-pager 2>&1 | sed -n '1p;$p'
    echo "-- last boot: shutdown lines"
    sudo journalctl --directory="$JD" -b 0 --no-pager 2>&1 | grep -E "Powering off|System is powering down|Reached target.*(Power-Off|Reboot|Shutdown)|Shutting down|logoutAndShutdown|plasma-shutdown|Rebooting" | tail -n 12
    echo "-- last boot: pattern count ($PAT): $(sudo journalctl --directory="$JD" -b 0 --no-pager 2>&1 | grep -c -i -E "$PAT")"
    echo "-- last boot: matching lines"
    sudo journalctl --directory="$JD" -b 0 --no-pager 2>&1 | grep -n -i -E "$PAT"
    echo "-- all boots: pattern count: $(sudo journalctl --directory="$JD" --no-pager 2>&1 | grep -c -i -E "$PAT")"
  } > "$O" 2>&1
  sudo umount "$M"; sudo losetup -d "$LO"; rmdir "$M"; cat "$O"
}

cmd_shutlines() { # copy-name label: for every boot in the copy's journal, the lines from the power-down request on
  local CP=$D/$1.raw M=$D/mnt-shut-$1 O=$D/shutdown-lines-$1-$2.txt LO P JD b T OPT=ro
  fresh "$O" "$M"; LO=$(sudo losetup -r -f -P --show "$CP"); P=$(rootpart "$LO"); mkdir "$M"
  if ! sudo mount -o ro "$P" "$M" 2> /dev/null; then OPT=ro,noload; sudo mount -o ro,noload "$P" "$M"; fi
  JD=$(sudo find "$M/var/log/journal" -mindepth 1 -maxdepth 1 -type d | head -n 1); T=$(mktemp)
  {
    echo "== shutdown lines $1 $2 $(date -Is); mount $OPT; coredump entries: $(sudo find "$M/var/lib/systemd/coredump" -mindepth 1 2> /dev/null | wc -l)"
    for b in $(sudo journalctl --directory="$JD" --list-boots --no-pager -q | awk '{print $2}'); do
      sudo journalctl --directory="$JD" -b "$b" --no-pager | awk '/System is powering down|System is rebooting/ {on=1} on' > "$T"
      echo "== boot $b: $(wc -l < "$T") lines from the power-down request on; first: $(head -n 1 "$T" | cut -c1-80)"
      echo "-- matches of ($PAT|exit-code|timeout|status=): $(grep -c -i -E "$PAT|exit-code|timeout|status=" "$T")"
      grep -i -E "$PAT|exit-code|timeout|status=" "$T"
      echo "-- whole boot, strict crash patterns (dumped core|core dump|segfault|code=dumped|ABRT|SEGV|core-dump): $(sudo journalctl --directory="$JD" -b "$b" --no-pager | grep -c -i -E 'dumped core|core dump|segfault|code=dumped|ABRT|SEGV|core-dump')"
      echo "-- alpbahos-zram unit in this boot"; sudo journalctl --directory="$JD" -b "$b" -u alpbahos-zram --no-pager | tail -n 8
    done
  } > "$O" 2>&1
  rm -f "$T"; sudo umount "$M"; sudo losetup -d "$LO"; rmdir "$M"; cat "$O"
}

SHUTCALL='busctl --user call org.kde.Shutdown /Shutdown org.kde.Shutdown'
cmd_s1() { # three shutdown cycles on one copy: 1 and 2 through the session's org.kde.Shutdown, 3 with systemctl poweroff
  local c R T0 T1 i; fresh "$D/S1-disk.raw"; cmd_mkcopy bios S1-disk
  for c in 1 2 3; do R=$D/S1-c$c
    stamp "S1 cycle $c start"; EXTRA_ARGS="-device intel-hda -device hda-duplex" agent_start "S1-c$c" bios S1-disk virtio 4G
    greeter_login "$R" "s1-c$c"; sleep 30; shot "$R" "s1-c$c-session"
    gsh "$R" 20 "r21m-as-user busctl --user introspect org.kde.Shutdown /Shutdown 2>&1 | grep -E 'interface|method'"
    sleep 60; shot "$R" "s1-c$c-before-shutdown"
    gsh "$R" 10 'echo "before shutdown: $(date -Is) failed units $(systemctl --failed --no-legend | wc -l); coredumps $(ls /var/lib/systemd/coredump 2> /dev/null | wc -l)"'
    T0=$(date +%s)
    if [ "$c" = 3 ]; then gsh "$R" 0 "systemctl poweroff"; echo "cycle 3: systemctl poweroff sent $(date -Is)"
    else gsh "$R" 0 "r21m-as-user $SHUTCALL logoutAndShutdown"; echo "cycle $c: org.kde.Shutdown logoutAndShutdown sent $(date -Is)"; fi
    for i in $(seq 1 300); do alive "$R" || break; sleep 1; done; T1=$(date +%s)
    if alive "$R"; then shot "$R" "s1-c$c-not-off"; echo "cycle $c: QEMU STILL RUNNING after 300 s, pid $(pgrep -f -- "-qmp unix:$R/qmp.sock"); stopping here"; exit 1; fi
    echo "cycle $c: QEMU ended by itself $((T1 - T0)) s after the call (no QMP quit sent)"; cat "$R/qmp-events.log"
    cmd_check S1-disk "c$c"
  done
  stamp "S1 end"
}

cmd_r1() { # reboot through the session's org.kde.Shutdown logoutAndReboot, QEMU without -no-reboot
  local R=$D/R1 i; fresh "$D/R1-disk.raw" "$R"; cmd_mkcopy bios R1-disk
  stamp "R1 start"; NO_REBOOT=0 agent_start R1 bios R1-disk virtio 4G
  greeter_login "$R" r1-boot1; sleep 30; shot "$R" r1-boot1-session
  gsh "$R" 0 "r21m-as-user $SHUTCALL logoutAndReboot"; echo "org.kde.Shutdown logoutAndReboot sent $(date -Is)"
  for i in $(seq 1 150); do [ "$(grep -ac 'R21M begin' "$R/serial.log")" -ge 2 ] && break; sleep 2; done
  echo "boot lines in the serial log: $(grep -ac 'R21M begin' "$R/serial.log")"; grep -a 'R21M begin' "$R/serial.log"
  sleep 20; shot "$R" r1-boot2-greeter; q "$R" click 622 474; sleep 3; shot "$R" r1-boot2-greeter-clicked
  gsh "$R" 10 'echo "boot 2: $(cat /proc/sys/kernel/random/boot_id) uptime $(cut -d" " -f1 /proc/uptime) s; sessions: $(loginctl list-sessions --no-legend | tr -s " " | tr "\n" ";"); failed units $(systemctl --failed --no-legend | wc -l)"'
  cat "$R/qmp-events.log"; vmquit "$R"; cmd_check R1-disk after
  stamp "R1 end"
}

cmd_apps() { # APPS-01 (round 37+): the preinstalled apps in the test user's Wayland session, plus the alp trust rows
  # of the booted system (scripts/rebuild/r36/alp-hook-r36.sh as root). Firefox opens a page over the network (Turkish
  # UI expected); VLC plays a test video made in the guest with the image's ffmpeg, then Space pauses it (two
  # screenshots 4 s apart must match while paused); round 38+: opened through its desktop entry (Xwayland, BLFS note);
  # LibreOffice converts a text file to .docx headless, then Writer opens it. Verdicts come from the screenshots.
  local R=$D/APPS i; fresh "$D/APPS-disk.raw" "$R"; cmd_mkcopy uefi APPS-disk
  stamp "APPS start"; agent_start APPS uefi APPS-disk virtio 6G
  greeter_login "$R" apps; sleep 20; shot "$R" apps-desktop
  gsh "$R" 90 "$(cat "$WT/scripts/rebuild/r36/alp-hook-r36.sh")"
  gsh "$R" 90 'cd /home/testuser && ffmpeg -loglevel error -f lavfi -i testsrc=duration=60:size=640x360:rate=25 -f lavfi -i sine=frequency=440:duration=60 -c:v mpeg4 -q:v 5 -c:a aac test.mp4 && printf "alpbahOS APPS-01 deneme belgesi: ğüşıöç ĞÜŞİÖÇ\n" > belge.txt && chown testuser: test.mp4 belge.txt && echo "media: $(stat -c %s test.mp4) bytes"'
  gsh "$R" 15 'r21m-as-user --bg firefox https://www.kernel.org/; echo started'
  for i in 1 2 3; do sleep 15; q "$R" key shift; shot "$R" "apps-firefox-$i"; done
  gsh "$R" 10 'echo "firefox processes: $(pgrep -u testuser -c firefox)"; pkill -u testuser firefox; sleep 3; echo "left: $(pgrep -u testuser -c firefox)"'
  # Round 38+: VLC is opened the way a user opens a file (default application from mimeapps.list, through its
  # desktop entry, which starts it under Xwayland); Enter accepts VLC's first-run privacy dialog first.
  gsh "$R" 15 'r21m-as-user --bg kioclient exec /home/testuser/test.mp4; echo started'
  sleep 15; shot "$R" apps-vlc-0-privacy; q "$R" key ret; sleep 3
  shot "$R" apps-vlc-1-play-a; sleep 4; shot "$R" apps-vlc-1-play-b
  q "$R" key spc; sleep 2; shot "$R" apps-vlc-2-paused-a; sleep 4; shot "$R" apps-vlc-2-paused-b
  q "$R" key spc; sleep 3; q "$R" combo alt right; sleep 3; shot "$R" apps-vlc-3-after-jump
  gsh "$R" 10 'P=$(pgrep -u testuser -x vlc | head -n 1); echo "vlc processes: $(pgrep -u testuser -c vlc); $(tr "\0" "\n" < /proc/$P/environ | grep QT_QPA_PLATFORM)"; pkill -u testuser vlc; sleep 3'
  gsh "$R" 15 'echo "xdg-settings default browser: $(r21m-as-user xdg-settings get default-web-browser) check: $(r21m-as-user xdg-settings check default-web-browser firefox.desktop)"; echo "xdg-mime video/mp4: $(r21m-as-user xdg-mime query default video/mp4)"'
  gsh "$R" 120 'r21m-as-user libreoffice --headless --convert-to docx --outdir /home/testuser /home/testuser/belge.txt; echo "docx: $(stat -c %s /home/testuser/belge.docx 2>&1)"'
  gsh "$R" 15 'r21m-as-user --bg libreoffice --writer /home/testuser/belge.docx; echo started'
  for i in 1 2; do sleep 20; q "$R" key shift; shot "$R" "apps-writer-$i"; done
  gsh "$R" 15 'echo "soffice processes: $(pgrep -u testuser -c soffice.bin)"; echo "failed units: $(systemctl --failed --no-legend | wc -l)"; echo "coredumps: $(ls /var/lib/systemd/coredump 2> /dev/null | wc -l)"'
  # Round 40+: PIXBUF-01 (GTK image loading), PORTAL-01 (portal daemon on the session bus), ALP-FLATHUB-01 (alp offers
  # the Flathub app for a name that is not in its catalogue; dry run, nothing installed)
  gsh "$R" 30 'gdk-pixbuf-csource --raw /usr/share/pixmaps/firefox.png > /dev/null 2>&1 && echo "pixbuf png: loaded" || echo "pixbuf png: FAILED"'
  gsh "$R" 30 'r21m-as-user busctl --user call org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop org.freedesktop.DBus.Properties Get ss org.freedesktop.portal.FileChooser version 2>&1 | sed "s/^/portal FileChooser version: /"'
  gsh "$R" 600 'flatpak update --appstream -y > /dev/null 2>&1; alp install --dry-run --yes calculator 2>&1 | tail -n 4 | sed "s/^/alp-flathub: /"'
  # Round 40+: DISTROBOX-01 (D163): a Debian 13 box for the test user (rootless Podman), apt inside it
  gsh "$R" 15 'echo "subuid testuser: $(grep -c "^testuser:" /etc/subuid) subgid: $(grep -c "^testuser:" /etc/subgid)"'
  gsh "$R" 900 'r21m-as-user distrobox create --name deb --image docker.io/library/debian:13 --yes > /tmp/dbx-create.log 2>&1; echo "distrobox create rc=$?"; tail -n 3 /tmp/dbx-create.log'
  gsh "$R" 1200 'r21m-as-user distrobox enter deb -- sh -c "sudo apt-get update -qq > /dev/null 2>&1; sudo apt-get install -y -qq cowsay > /dev/null 2>&1; /usr/games/cowsay alpbahOS; cat /etc/os-release | head -n 1" 2>&1 | tail -n 10 | sed "s/^/dbx: /"'
  vmquit "$R"; rm -f "$D/APPS-disk.raw"; stamp "APPS end (copy removed)"
}

cmd_kutu() { # ALP-KUTU-01 (D164, round 41+): the Debian box through alp, as the test user and through a real sudo
  # (alp runs the box step again as SUDO_USER); the apt hint (D123, also as root); a driver name refused;
  # htop shown in Konsole from the box; remove. Needs network (image pull, Debian mirrors).
  local R=$D/KUTU; fresh "$D/KUTU-disk.raw" "$R"; cmd_mkcopy uefi KUTU-disk
  stamp "KUTU start"; agent_start KUTU uefi KUTU-disk virtio 6G
  greeter_login "$R" kutu; sleep 20; shot "$R" kutu-desktop
  gsh "$R" 20 'apt install htop > /tmp/hint.txt 2>&1; echo "apt rc=$?"; sed "s/^/apt-hint: /" /tmp/hint.txt; echo "apt link: $(readlink /usr/bin/apt)"'
  # FW-DIRLINK-01: the RTX 5060 (GB206) GSP firmware resolves in the installed system
  gsh "$R" 10 'echo "gb206 -> $(readlink /usr/lib/firmware/nvidia/gb206); $(ls /usr/lib/firmware/nvidia/gb206/gsp/ | tr "\n" " ")"; echo "alp owner: $(grep -l "nvidia/gb206" /var/lib/alp/db.json > /dev/null && echo recorded)"'
  gsh "$R" 30 'r21m-as-user alp install --yes nvidia-smi > /tmp/nv.txt 2>&1; echo "alp install nvidia-smi rc=$?"; sed "s/^/alp-nvidia: /" /tmp/nv.txt'
  gsh "$R" 1800 'r21m-as-user alp install --yes htop > /tmp/kutu-htop.log 2>&1; echo "alp install htop rc=$?"; tail -n 8 /tmp/kutu-htop.log'
  gsh "$R" 30 'r21m-as-user sh -lc "command -v htop; htop --version" 2>&1 | sed "s/^/htop: /"; r21m-as-user alp list 2>&1 | grep kutu | sed "s/^/alp list: /"; ls /home/testuser/.local/share/applications/ 2>&1 | sed "s/^/menu: /"'
  # A real sudo (env_reset, secure_path): a NOPASSWD rule for the test user in this test copy only
  gsh "$R" 900 'install -m 440 /dev/null /etc/sudoers.d/99-kutu-test; echo "testuser ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-kutu-test; r21m-as-user sudo -n alp install --yes cowsay > /tmp/kutu-cowsay.log 2>&1; echo "sudo alp install cowsay rc=$?"; tail -n 6 /tmp/kutu-cowsay.log; r21m-as-user sh -lc "cowsay alpbahOS" 2>&1 | tail -n 8 | sed "s/^/cowsay: /"; r21m-as-user sudo -n apt install htop 2>&1 | head -n 2 | sed "s/^/sudo apt: /"'
  gsh "$R" 15 'r21m-as-user --bg konsole -e sh -lc htop; echo started'
  sleep 15; q "$R" key shift; shot "$R" kutu-htop-konsole
  gsh "$R" 10 'pkill -u testuser konsole; sleep 2'
  gsh "$R" 300 'r21m-as-user alp remove --yes htop > /tmp/kutu-rm.log 2>&1; echo "alp remove htop rc=$?"; tail -n 3 /tmp/kutu-rm.log; r21m-as-user sh -lc "command -v htop || echo htop gone"; r21m-as-user alp list 2>&1 | grep kutu | sed "s/^/alp list after: /"'
  gsh "$R" 15 'echo "failed units: $(systemctl --failed --no-legend | wc -l)"; echo "coredumps: $(ls /var/lib/systemd/coredump 2> /dev/null | wc -l)"'
  vmquit "$R"; rm -f "$D/KUTU-disk.raw"; stamp "KUTU end (copy removed)"
}

cmd_nvidia() { # NVIDIA-PKG-01 (D165, round 42+): `sudo alp install nvidia` as the test user through a real sudo, with
  # alp's build sandbox (alpbuild + bubblewrap; a chroot cannot test it): NVIDIA's .run downloaded inside the guest,
  # the open modules built against linux-headers, files placed, triggers run. QEMU has no NVIDIA GPU: modprobe must
  # say "No such device"; after a reboot the desktop must still come up (nouveau is blacklisted, virtio-gpu is not
  # affected); then `alp remove nvidia`.
  local R=$D/NVIDIA; fresh "$D/NVIDIA-disk.raw" "$R"; cmd_mkcopy uefi NVIDIA-disk
  stamp "NVIDIA start"; NO_REBOOT=0 agent_start NVIDIA uefi NVIDIA-disk virtio 6G
  greeter_login "$R" nvidia; sleep 20; shot "$R" nvidia-desktop
  gsh "$R" 30 'install -m 440 /dev/null /etc/sudoers.d/99-nvidia-test; echo "testuser ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-nvidia-test; r21m-as-user alp install --dry-run --yes nvidia 2>&1 | tail -n 6 | sed "s/^/dry-run: /"'
  gsh "$R" 3600 'S=$(date +%s); r21m-as-user sudo -n alp install --yes nvidia > /tmp/nv.log 2>&1; echo "alp install nvidia rc=$? in $(( $(date +%s) - S )) s"; tail -n 4 /tmp/nv.log; grep -c "bwrap, uid" /var/log/alp/nvidia-620.70.06.build.log | sed "s/^/sandboxed steps: /"'
  gsh "$R" 60 'ls /usr/lib/modules/*/extra/nvidia/ | tr "\n" " "; echo; modinfo -F vermagic /usr/lib/modules/*/extra/nvidia/nvidia.ko; ldconfig -p | grep -c "libGLX_nvidia\|libEGL_nvidia\|libcuda" | sed "s/^/ldconfig nvidia libs: /"; modprobe nvidia 2>&1 | tail -n 1 | sed "s/^/modprobe: /"; ls -la /usr/lib/libGL.so.1 | sed "s/.* -> /libGL.so.1 -> /"; find /usr -xdev -perm -4000 -newer /usr/share/alp/index.json 2>/dev/null | sed "s/^/new setuid: /"; alp check 2>&1 | tail -n 1'
  gsh "$R" 0 'systemctl reboot'; local i
  for i in $(seq 1 150); do [ "$(grep -ac 'R21M begin' "$R/serial.log")" -ge 2 ] && break; sleep 2; done
  echo "boot lines in the serial log: $(grep -ac 'R21M begin' "$R/serial.log")"
  greeter_login "$R" nvidia2; sleep 20; shot "$R" nvidia-after-reboot
  gsh "$R" 30 'lsmod | grep -c "^nouveau\|^nvidia" | sed "s/^/nouveau or nvidia loaded: /"; echo "failed units: $(systemctl --failed --no-legend | wc -l)"'
  gsh "$R" 300 'r21m-as-user sudo -n alp remove --yes nvidia 2>&1 | tail -n 2; ls /usr/lib/modules/*/extra 2>&1 | tail -n 1; ldconfig -p | grep -c nvidia_ | sed "s/^/nvidia libs left: /"; alp check 2>&1 | tail -n 1; echo "coredumps: $(ls /var/lib/systemd/coredump 2> /dev/null | wc -l)"'
  vmquit "$R"; rm -f "$D/NVIDIA-disk.raw"; stamp "NVIDIA end (copy removed)"
}

cmd_fpgui() { # Flatpak install by the test shell (root), then the Calculator in the test user's Wayland session
  local R=$D/FPGUI i; fresh "$D/FPGUI-disk.raw" "$R"; cmd_mkcopy uefi FPGUI-disk
  stamp "FP-GUI start"; agent_start FPGUI uefi FPGUI-disk virtio 6G
  greeter_login "$R" fpgui; sleep 20; shot "$R" fpgui-desktop
  gsh "$R" 5 'nohup sh -c "flatpak install -y --noninteractive flathub org.gnome.Calculator > /root/fp.out 2>&1; echo rc=\$? > /root/fp.rc" > /dev/null 2>&1 &'
  for i in $(seq 1 120); do q "$R" key shift; gsh "$R" 8 'cat /root/fp.rc 2> /dev/null' | grep -q rc= && break; sleep 20; done
  gsh "$R" 10 'echo "flatpak install: $(cat /root/fp.rc); $(tail -n 1 /root/fp.out)"; echo "flatpak list: $(flatpak list --app --columns=application,installation | tr "\n" ";")"'
  gsh "$R" 15 'r21m-as-user --bg flatpak run org.gnome.Calculator; sleep 1; echo started'
  for i in 1 2 3; do sleep 15; q "$R" key shift; shot "$R" "fpgui-calc-$i"; done
  gsh "$R" 15 'echo "calculator processes: $(pgrep -u testuser -a -f gnome-calculator | tr "\n" ";")"; r21m-as-user sh -c "echo session env: \$XDG_RUNTIME_DIR \$WAYLAND_DISPLAY \$DBUS_SESSION_BUS_ADDRESS"; echo "failed units: $(systemctl --failed --no-legend | wc -l)"'
  vmquit "$R"; rm -f "$D/FPGUI-disk.raw"; stamp "FP-GUI end (copy removed)"
}

# --- manual steps for the live-session rows (REC, KF): one action per call, so each screen can be read first ----
cmd_type() { tq "$D/$1" "$2"; }
cmd_enter() { q "$D/$1" key ret; }
cmd_key() { local r=$D/$1; shift; q "$r" key "$@"; }
cmd_combo() { local r=$D/$1; shift; q "$r" combo "$@"; }
cmd_click() { q "$D/$1" click "$2" "$3"; }
cmd_shot() { shot "$D/$1" "$2"; }
cmd_quit() { vmquit "$D/$1"; }
run_live() { # run-name command wait shot-name: clear, type the command, Enter, wait, screenshot
  local R=$D/$1; tq "$R" "clear"; q "$R" key ret; sleep 1; tq "$R" "$2"; q "$R" key ret; sleep "$3"; shot "$R" "$4"; }
cmd_run() { run_live "$@"; }
open_konsole() { local R=$D/$1; q "$R" combo alt spc; sleep 3; tq "$R" konsole; sleep 2; q "$R" key ret; sleep 8; }

# --- REC1 / REC2: break a reflink copy, repair it from the live ISO, boot it alone ---------------------------------
cmd_recprep() { # bios|uefi name
  local SRC CP=$D/$2-broken.raw M=$D/mnt-$2 O=$D/$2-break.txt LO P p
  SRC=$([ "$1" = uefi ] && echo "$IMGU" || echo "$IMGB")
  fresh "$CP" "$M" "$O"; cp --reflink=always "$SRC" "$CP"
  LO=$(sudo losetup -f -P --show "$CP"); P=$(rootpart "$LO"); mkdir "$M"
  sudo mount "$P" "$M" || { sudo losetup -d "$LO"; rmdir "$M"; rm -f "$CP"; exit 1; }
  {
    echo "== break $CP (copy of $SRC) $(date -Is)"
    for p in "$LO"p*; do echo "partition ${p#"$LO"}: $(sudo blkid -o value -s TYPE "$p")"; done
    echo "-- before"; ls -la "$M/boot"; echo "grub.cfg: $(stat -c %s "$M/boot/grub/grub.cfg") bytes, menuentry lines $(grep -c '^menuentry' "$M/boot/grub/grub.cfg")"
    sudo rm -f "$M"/boot/initramfs-*.img; sudo truncate -s 0 "$M/boot/grub/grub.cfg"
    echo "-- after"; ls -la "$M/boot"; echo "grub.cfg: $(stat -c %s "$M/boot/grub/grub.cfg") bytes"
  } > "$O" 2>&1
  sudo umount "$M"; sudo losetup -d "$LO"; rmdir "$M"; cat "$O"
}
cmd_reclive() { # bios|uefi name "<recover arguments>"      live ISO first, broken copy as the virtio disk
  local FW=$1 N=$2 ARGS=$3 R=$D/$2 CP=$D/$2-broken.raw; fresh "$R"
  stamp "$N live start"; EXTRA_ARGS="-boot order=dc" ACCEL=kvm bash "$W/vm-start.sh" "$FW" "$ISO" "$R" "$CP" virtio 6G > /dev/null
  sleep 80; shot "$R" rec-0-live; open_konsole "$N"
  run_live "$N" 'echo $PATH; type alpbahos-recover; sudo -n true; echo rc=$?' 4 rec-1-path
  run_live "$N" 'lsblk -o NAME,SIZE,FSTYPE; pkexec /usr/local/sbin/alpbahos-recover; echo rc=$?' 8 rec-2-list
  run_live "$N" "pkexec /usr/local/sbin/alpbahos-recover $ARGS 2>&1 | tee rec.log" "${RECWAIT:-200}" rec-3-run-end
  run_live "$N" 'grep -n -e "== " -e "write error" -e "alpbahos-recover:" rec.log; grep -c "" rec.log' 4 rec-4-steps
  run_live "$N" 'grep SigIgn /proc/self/status; pkexec grep SigIgn /proc/self/status' 5 rec-5-sigign
  run_live "$N" 'pkexec dd if=/home/live/rec.log of=/dev/ttyS0' 6 rec-6-to-serial
  vmquit "$R"
  tr -d '\r' < "$R/serial.log" | awk '/^== root=/ {on=1; buf=""} on {buf = buf $0 "\n"} END {printf "%s", buf}' > "$D/$N-recover-output.txt"
  echo "recovery output from the serial log: $(wc -l < "$D/$N-recover-output.txt") lines"
  grep -n -e "^== " -e "write error" -e "alpbahos-recover:" "$D/$N-recover-output.txt"
  stamp "$N live end"
}
cmd_recboot() { # bios|uefi name: the repaired copy alone
  local FW=$1 N=$2 R=$D/$2-boot CP=$D/$2-broken.raw; fresh "$R"
  ACCEL=kvm bash "$W/vm-start.sh" "$FW" "" "$R" "$CP" virtio 4G > /dev/null
  sleep 60; shot "$R" rec-disk-greeter; q "$R" click 622 474; sleep 3; shot "$R" rec-disk-greeter-clicked
  vmquit "$R"; stamp "$N boot of the repaired copy done"
}

# --- KF: Turkish F chosen in the live session, GUI install to a new image, checks ----------------------------------
IMGK=${KF_IMG:-$B/images/inst-bios-kf-r21m.raw}   # KF_IMG, KF_PW: new names per round (refused if they exist)
KPW=${KF_PW:-$B/test-secrets/r21m-kf.pw}
cmd_kflive() { # live boot with the new target image, keyboard tool, choice 2 (Turkish F)
  local R=$D/KF; fresh "$R" "$IMGK" "$KPW"
  ( umask 077; printf '%s\n' "$(tr -dc 0-9 < /dev/urandom | head -c 10)" > "$KPW" ); truncate -s 30G "$IMGK"
  stamp "KF live start"; ACCEL=kvm bash "$W/vm-start.sh" bios "$ISO" "$R" "$IMGK" virtio 6G > /dev/null
  sleep 80; shot "$R" kf-00-live; open_konsole KF
  run_live KF 'cat .config/kxkbrc' 2 kf-01-kxkbrc-before
  tq "$R" "/usr/bin/alpbahos-keyboard"; q "$R" key ret; sleep 3; shot "$R" kf-02-menu
  q "$R" key 2; q "$R" key ret; sleep 3; shot "$R" kf-03-saved; q "$R" key ret; sleep 1
  run_live KF 'cat .config/kxkbrc' 2 kf-04-kxkbrc-after
  q "$R" key q; sleep 1; shot "$R" kf-05-live-key-q; q "$R" key backspace
}
clr() { q "$1" combo ctrl a; q "$1" key $(for i in $(seq 1 25); do echo -n "backspace "; done); }
cmd_kffill() { # installer up to the filled users page; the reviewer reads i-05 before kfgo
  local R=$D/KF n; tq "$R" exit; q "$R" key ret; sleep 3
  q "$R" click 58 40; sleep 1; q "$R" key ret; sleep 40; shot "$R" i-00
  for n in 1 2 3 4; do q "$R" click 1007 637; sleep 3; shot "$R" "i-0$n"; done
  # field positions of the round 33+ installer (same as install_run in r20-lanes.sh)
  q "$R" click 424 181; sleep 1; clr "$R"; tq "$R" "Test User"
  q "$R" click 424 245; sleep 1; clr "$R"; tq "$R" "testuser"
  q "$R" click 424 309; sleep 1; clr "$R"; tq "$R" "alpbahos-kf"
  q "$R" click 424 373; sleep 1; clr "$R"; q "$R" text "$(cat "$KPW")"
  q "$R" click 629 373; sleep 1; clr "$R"; q "$R" text "$(cat "$KPW")"
  sleep 2; shot "$R" i-05-users-filled
}
cmd_kfgo() { local R=$D/KF i
  if [ "${DRIVERS_PAGE:-0}" = 1 ]; then  # D166 (round 43+): the "Sürücüler" page between users and summary
    q "$R" click 1007 637; sleep 3; shot "$R" i-05b-drivers
    local NY; NY=$(python3 "$W/find-button-y.py" "$R/i-05b-drivers.png" 1007 2>/dev/null) || NY=637
    q "$R" click 1007 "$NY"; sleep 3; shot "$R" i-06-summary
  else
    q "$R" click 1007 637; sleep 3; shot "$R" i-06-summary
  fi
  # the Kur button is found in the summary screenshot (find-button-y.py, round 41); 709 is the old fallback
  local KY; KY=$(python3 "$W/find-button-y.py" "$R/i-06-summary.png" 1002 2>/dev/null) || KY=709
  echo "kfgo: Kur button y=$KY"
  q "$R" click 1002 "$KY"; sleep 4; shot "$R" i-07-confirm
  # INSTALLER-UI-01 (r40+): the confirm dialog button "Şimdi Kur" is at y 455 (470 hit its edge, rc01 I1)
  q "$R" click 748 455; sleep 5; shot "$R" i-08-running
  for i in $(seq 1 120); do grep -aq "unmounting filesystem" "$R/serial.log" 2> /dev/null && break; sleep 20; done
  sleep 20; shot "$R" i-09-done; vmquit "$R"; stamp "KF install ended (unmount line: $(grep -ac 'unmounting filesystem' "$R/serial.log"))"
}
kbfacts() { # mounted-root: the keyboard facts of an installed system
  local M=$1 f
  for f in etc/X11/xorg.conf.d/00-keyboard.conf etc/xdg/kxkbrc home/testuser/.config/kxkbrc etc/vconsole.conf var/log/alpbahos-layout-carry.log var/log/alpbahos-layout-apply.log; do
    echo "-- /$f"; sudo cat "$M/$f" 2>&1; done
  echo "-- /etc/sddm.conf GreeterEnvironment and sddm.conf.d"; sudo grep -h -n "GreeterEnvironment" "$M/etc/sddm.conf" "$M"/etc/sddm.conf.d/* 2>&1
}
cmd_rofacts() { # image name kind(kf|f1): read-only facts of an image -> facts-<name>.txt
  local IMG=$1 N=$2 KIND=$3 M=$D/mnt-facts-$2 O=$D/facts-$2.txt LO P OPT=ro
  fresh "$O" "$M"; LO=$(sudo losetup -r -f -P --show "$IMG"); P=$(rootpart "$LO"); mkdir "$M"
  if ! sudo mount -o ro "$P" "$M" 2> /dev/null; then OPT=ro,noload; sudo mount -o ro,noload "$P" "$M"; fi
  {
    echo "== read-only facts $N ($IMG, root $P, mount $OPT) $(date -Is)"
    echo "MBR boot code bytes that are not zero (first 440): $(sudo head -c 440 "$LO" | tr -d '\0' | wc -c)"
    echo "passwd uid>=1000: $(awk -F: '$3>=1000 && $3<60000 {print $1":"$3}' "$M/etc/passwd" | tr '\n' ' '); /home: $(ls "$M/home" | tr '\n' ' ')"
    echo "boot: $(ls "$M/boot" | tr '\n' ' '); grub.cfg: $(stat -c %s "$M/boot/grub/grub.cfg" 2>&1) bytes"
    echo "live-only paths present: [$(ls -d "$M/usr/lib/alpbahos" "$M/etc/calamares" "$M/usr/bin/alpbahos-install" "$M/home/live" "$M/etc/polkit-1/rules.d/49-alpbahos-live.rules" 2> /dev/null | sed "s#$M##" | tr '\n' ' ')]"
    echo "live in passwd: $(grep -c '^live:' "$M/etc/passwd")"
    [ "$KIND" = kf ] && kbfacts "$M"
  } > "$O" 2>&1
  sudo umount "$M"; sudo losetup -d "$LO"; rmdir "$M"; cat "$O"
}
cmd_kfdisk() { OUTD=$D bash "$WT/scripts/rebuild/r20/disk-check-r20.sh" "$IMGK" KF; cmd_rofacts "$IMGK" KF kf; }
cmd_kfboot() { # the KF install with -snapshot, greeter login with the digits password; GUI steps by hand afterwards
  local R=$D/${1:-KF-boot}; fresh "$R"
  EXTRA_ARGS="-snapshot" ACCEL=kvm bash "$W/vm-start.sh" bios "" "$R" "$IMGK" virtio 4G > /dev/null
  sleep 50; shot "$R" kf-greeter; q "$R" click 622 474; sleep 2; q "$R" text "$(cat "$KPW")"; q "$R" key ret; sleep 50; shot "$R" kf-desktop
}
cmd_kfagent() { # reflink copy of the KF install with the test shell; logs the test user in
  fresh "$D/KF-agent-disk.raw"; cmd_mkcopy bios KF-agent-disk "$IMGK"
  agent_start "${1:-KF-agent}" bios KF-agent-disk virtio 4G; greeter_login "$D/${1:-KF-agent}" kf "$KPW"; sleep 25; shot "$D/${1:-KF-agent}" kf-desktop
}

# --- F1: forced failure (lane3 of r20-lanes.sh) with new names ------------------------------------------------------
IMGF1=${F1_IMG:-$B/images/inst-bios-f1-r21m.raw}
cmd_f1() { fresh "$D/F1" "$D/F1-boot" "$IMGF1"; stamp "F1 start"
  ROUND=$MR OUTD=$D IMGF=$IMGF1 F1NAME=F1 NOCLOBBER=1 FAILSHOTS=${FAILSHOTS:-20} bash "$WT/scripts/rebuild/r20/r20-lanes.sh" "$ISO" lane3
  stamp "F1 end"; cmd_rofacts "$IMGF1" F1 f1; }

if [ "${MATRIX_LIB:-0}" != 1 ]; then
  c=${1:-}; shift || true
  case $c in
    sha|live|diag|mkcopy|agent|check|s1|r1|fpgui|apps|kutu|nvidia|type|enter|key|combo|click|shot|quit|run|recprep|reclive|recboot|kflive|kffill|kfgo|kfdisk|kfboot|kfagent|rofacts|f1|shutlines) "cmd_$c" "$@" ;;
    *) echo "usage: matrix-r21.sh sha|live|diag|mkcopy|agent|check|s1|r1|fpgui ..."; exit 2 ;;
  esac
fi
