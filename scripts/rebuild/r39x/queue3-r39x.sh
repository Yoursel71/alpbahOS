#!/bin/bash
# r39x queue 3: replaces queue 2 after its harness fault (queue 2 sourced matrix-r21.sh, which reset S, so its
# guest commands never ran). KF live and kffill were done by hand before this; the KF guest is running.
# Order: KF install and checks (image deleted right after), SBX + ALP on one copy, F1 (new install, >= 40 GiB free),
# then the TCG live rows.
cd /home/yrslf/alpbahOS/scratch-lfs-bench/lfs13-logs/iso-beta-0.9/r39x && . ./env.sh
RBD=$MATRIX_WT/scripts/rebuild   # not S: sourcing matrix-r21.sh sets its own S
MM=$M
log() { echo "[$(date +%T)] $*" >> queue3.log; }
MATRIX_LIB=1 . "$MM"   # library mode: agent_start, greeter_login, shot, q, vmquit
gs() { python3 "$RBD/r21/gsh.py" "$@"; }

# ---- KF: install, disk check, installed session ----------------------------------------------------------
log "KF install start"
{ bash "$MM" kfgo && bash "$MM" kfdisk; } >> run-KF.out 2>&1
log "KF install end"
if gate 20 >> run-KF.out 2>&1; then
  {
    bash "$MM" kfagent KF-agent
    R=$D/KF-agent
    gs "$R" 40 'r21m-as-user busctl --user call org.kde.keyboard /Layouts org.kde.KeyboardLayouts getLayoutsList; r21m-as-user busctl --user call org.kde.keyboard /Layouts org.kde.KeyboardLayouts getLayout; localectl status; tr "\0" "\n" < /proc/$(pgrep -u testuser -x kwin_wayland | head -1)/environ | grep -i xkb; r21m-as-user --bg konsole; sleep 7; pgrep -u testuser -a konsole'
    q "$R" key q; sleep 1; q "$R" key q; sleep 1; shot "$R" kf-key-q
    gs "$R" 20 'r21m-as-user --bg konsole -e /usr/bin/alpbahos-keyboard --check; sleep 8; pgrep -u testuser -af alpbahos-keyboard'
    shot "$R" kf-check-0; q "$R" key q; sleep 2; shot "$R" kf-check-1-read; q "$R" key d; sleep 2; shot "$R" kf-check-2-answer-e
    vmquit "$R" && rm -f "$D/KF-agent-disk.raw"
  } >> run-KF.out 2>&1
fi
pgrep -f -- "-qmp unix:$D/KF" > /dev/null || rm -f "$KF_IMG" "$KF_PW"
log "KF end (image removed: $([ -e "$KF_IMG" ] && echo no || echo yes))"

# ---- SBX + ALP ------------------------------------------------------------------------------------------
if gate 20 >> run-SBX2.out 2>&1; then
  log "SBX start"
  {
    bash "$MM" mkcopy uefi SBX2-disk
    agent_start SBX2 uefi SBX2-disk virtio 6G
    greeter_login "$D/SBX2" sbx
    T64=$(tar -C sbx-catalog -czf - . | base64 -w0)
    G64=$(base64 -w0 < "$RBD/r39x/sbx-guest-r39x.sh")
    A64=$(base64 -w0 < "$RBD/r36x/alp-check-r36x.sh")
    gs "$D/SBX2" 60 "mkdir -p /var/lib/alp-sbx-test && echo $T64 | base64 -d | tar -xzf - -C /var/lib/alp-sbx-test && chown -R root:root /var/lib/alp-sbx-test && chmod -R go-w /var/lib/alp-sbx-test && echo $G64 | base64 -d > /root/sbx.sh && echo $A64 | base64 -d > /root/alp-check.sh && ls -lR /var/lib/alp-sbx-test | head -20"
    for p in hello escape net suid user final; do gs "$D/SBX2" 900 "bash /root/sbx.sh $p" > "SBX2-$p.txt" 2>&1; cat "SBX2-$p.txt"; done
    gs "$D/SBX2" 60 "tar -C /var/log/alp -czf - . | base64 -w0" | tr -d '\n' | base64 -d > SBX2-alp-logs.tgz 2>/dev/null; tar -tzf SBX2-alp-logs.tgz | head
    gs "$D/SBX2" 300 "bash /root/alp-check.sh good" > ALP-good.txt 2>&1
    gs "$D/SBX2" 300 "bash /root/alp-check.sh tamper" > ALP-tamper.txt 2>&1
    gs "$D/SBX2" 30 "rm -f /root/sbx.sh /root/alp-check.sh; echo failed units: \$(systemctl --failed --no-legend | wc -l)"
    shot "$D/SBX2" sbx-end
    vmquit "$D/SBX2" && rm -f "$D/SBX2-disk.raw" && echo "SBX2 copy removed"
  } >> run-SBX2.out 2>&1
  log "SBX end"
else log "SBX gate timeout"; fi

# ---- F1 (new install, forced failure) -------------------------------------------------------------------
if gate 40 >> run-F1.out 2>&1; then
  log "F1 start"
  FAILSHOTS=12 bash "$MM" f1 >> run-F1.out 2>&1
  { echo "== F1 target grub dir"; LO=$(sudo losetup -r -f -P --show "$F1_IMG"); TM=$(mktemp -d /tmp/r39x-f1.XXXX)
    sudo mount -o ro,noload "${LO}p1" "$TM" && { sudo ls "$TM/boot/grub"; sudo head -c 400 "$TM/boot/grub/grub.cfg"; echo; sudo umount "$TM"; }
    sudo losetup -d "$LO"; rmdir "$TM"; } > F1-grub.txt 2>&1
  pgrep -f -- "-qmp unix:$D/F1" > /dev/null || rm -f "$F1_IMG"
  log "F1 end (image removed: $([ -e "$F1_IMG" ] && echo no || echo yes))"
else log "F1 gate timeout (free space)"; fi

# ---- TCG live rows, last and alone ----------------------------------------------------------------------
for r in "L2 uefi" "L4 bios"; do set -- $r
  if gate 20 >> "run-$1.out" 2>&1; then log "$1 start (TCG)"; bash "$MM" live "$1" "$2" tcg 1200 >> "run-$1.out" 2>&1; log "$1 end"
  else log "$1 gate timeout"; fi
done
log "QUEUE3 DONE"
