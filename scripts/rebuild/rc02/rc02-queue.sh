#!/bin/bash
# BETA-RC-02 matrix queue on ISO rc02: one guest of this queue at a time, each behind the gate.
# KUTU first (needs the UEFI install, so lane2 = L1 + I2 runs before it), then the short regression:
# U1, ALP, APPS on the UEFI install; lane1 (I1) and B1, S1, PLY (10 boots), KF on the BIOS install.
# Usage: rc02-queue.sh [from-step]    steps: lane2 kutu uefi lane1 bios ply kf
cd /home/yrslf/alpbahOS/scratch-lfs-bench/lfs13-logs/iso-beta-0.9/rc02/matrix || exit 1
. /home/yrslf/alpbahOS/wt-rc02/scripts/rebuild/rc02/env-rc02.sh
RBD=$MATRIX_WT/scripts/rebuild
MM=$M
LANES=$RBD/r20/r20-lanes.sh
log() { echo "[$(date +%T)] $*" >> queue.log; }
run() { local n=$1 min=$2; shift 2; gate "$min" >> "run-$n.out" 2>&1 || { log "$n gate timeout"; return 1; }
  log "$n start"; "$@" >> "run-$n.out" 2>&1; log "$n end rc=$?"; }
FROM=${1:-lane2}; go=0
want() { [ "$1" = "$FROM" ] && go=1; [ "$go" = 1 ]; }

if want lane2; then
  run lane2 40 env ROUND=rc02 NOCLOBBER=1 bash "$LANES" "$ISO_PATH" lane2
fi
if want kutu; then
  run KUTU 25 bash -c '
    . '"$RBD"'/rc02/env-rc02.sh; RBD='"$RBD"'; MM=$M; MATRIX_LIB=1 . "$MM"; gs() { python3 "$RBD/r21/gsh.py" "$D/KUTU" "$@"; }
    bash "$MM" mkcopy uefi KUTU-disk
    LO=$(sudo losetup -f -P --show "$D/KUTU-disk.raw"); P=$(rootpart "$LO"); MT=$(mktemp -d /tmp/rc02-k.XXXX)
    sudo mount "$P" "$MT" && { sudo install -m 600 "$DIAG_PWF" "$MT/root/.kutu-pw"; sudo umount "$MT"; }; sudo losetup -d "$LO"; rmdir "$MT"
    agent_start KUTU uefi KUTU-disk virtio 6G; greeter_login "$D/KUTU" kutu
    G64=$(base64 -w0 < "$RBD/rc02/kutu-guest-rc02.sh")
    gs 30 "echo $G64 | base64 -d > /root/kutu.sh && echo staged"
    gs 60 "bash /root/kutu.sh pre" > KUTU-pre.txt 2>&1
    gs 1200 "bash /root/kutu.sh create" > KUTU-create.txt 2>&1
    gs 1500 "bash /root/kutu.sh sudo" > KUTU-sudo.txt 2>&1
    gs 300 "bash /root/kutu.sh plain" > KUTU-plain.txt 2>&1
    gs 30 "bash /root/kutu.sh end" > KUTU-end.txt 2>&1
    cat KUTU-*.txt; shot "$D/KUTU" kutu-end; vmquit "$D/KUTU" && rm -f "$D/KUTU-disk.raw"'
fi
if want uefi; then
  run U1 20 env OUTD=$D BUS=virtio MEM=6G FLATPAK=1 bash "$RBD/r21/diag-r21.sh" uefi "$IMGU_PATH" U1
  [ -e sbx-catalog ] || cp -a /home/yrslf/alpbahOS/scratch-lfs-bench/lfs13-logs/iso-beta-0.9/r39x/sbx-catalog sbx-catalog
  run ALP 20 bash -c '
    . '"$RBD"'/rc02/env-rc02.sh; RBD='"$RBD"'; MM=$M; MATRIX_LIB=1 . "$MM"; gs() { python3 "$RBD/r21/gsh.py" "$D/ALP" "$@"; }
    bash "$MM" mkcopy uefi ALP-disk; agent_start ALP uefi ALP-disk virtio 6G; greeter_login "$D/ALP" alp
    T64=$(tar -C sbx-catalog -czf - . | base64 -w0); G64=$(base64 -w0 < "$RBD/r39x/sbx-guest-r39x.sh"); A64=$(base64 -w0 < "$RBD/r36x/alp-check-r36x.sh")
    gs 60 "mkdir -p /var/lib/alp-sbx-test && echo $T64 | base64 -d | tar -xzf - -C /var/lib/alp-sbx-test && chown -R root:root /var/lib/alp-sbx-test && chmod -R go-w /var/lib/alp-sbx-test && echo $G64 | base64 -d > /root/sbx.sh && echo $A64 | base64 -d > /root/alp-check.sh && echo staged"
    gs 900 "bash /root/sbx.sh user" > ALP-user.txt 2>&1
    gs 300 "bash /root/alp-check.sh good" > ALP-good.txt 2>&1
    gs 300 "bash /root/alp-check.sh tamper" > ALP-tamper.txt 2>&1
    gs 30 "echo \"failed units: \$(systemctl --failed --no-legend | wc -l), coredumps: \$(ls /var/lib/systemd/coredump | wc -l)\"" > ALP-units.txt 2>&1
    cat ALP-*.txt; shot "$D/ALP" alp-end; vmquit "$D/ALP" && rm -f "$D/ALP-disk.raw"'
  run APPS 20 bash "$MM" apps
fi
if want lane1; then
  run lane1 40 env ROUND=rc02 NOCLOBBER=1 bash "$LANES" "$ISO_PATH" lane1
fi
if want bios; then
  run B1 20 env OUTD=$D BUS=virtio MEM=6G bash "$RBD/r21/diag-r21.sh" bios "$IMGB_PATH" B1
  run S1 20 bash "$MM" s1
fi
if want ply; then
  [ -e env.sh ] || cp "$RBD/rc02/env-rc02.sh" env.sh
  run PLY 20 env MAXCYC=10 MAXMIN=40 bash "$RBD/r39y/ply-loop-r39y.sh"
fi
if want kf; then
  run KF 40 bash -c ". $RBD/rc02/env-rc02.sh; bash \$M kflive && bash \$M kffill && bash \$M kfgo && bash \$M kfdisk"
  run KF-agent 20 bash -c '
    . '"$RBD"'/rc02/env-rc02.sh; RBD='"$RBD"'; MM=$M; MATRIX_LIB=1 . "$MM"
    bash "$MM" kfagent KF-agent; R=$D/KF-agent; gs() { python3 "$RBD/r21/gsh.py" "$@"; }
    gs "$R" 40 "r21m-as-user busctl --user call org.kde.keyboard /Layouts org.kde.KeyboardLayouts getLayoutsList; localectl status; tr \"\\0\" \"\\n\" < /proc/\$(pgrep -u testuser -x kwin_wayland | head -1)/environ | grep -i xkb; r21m-as-user --bg konsole; sleep 7; pgrep -u testuser -a konsole"
    q "$R" key q; sleep 1; q "$R" key q; sleep 1; shot "$R" kf-key-q
    gs "$R" 20 "r21m-as-user --bg konsole -e /usr/bin/alpbahos-keyboard --check; sleep 8; pgrep -u testuser -af alpbahos-keyboard"
    shot "$R" kf-check-0; q "$R" key q; sleep 2; shot "$R" kf-check-1-read; q "$R" key d; sleep 2; shot "$R" kf-check-2-answer-e
    vmquit "$R" && rm -f "$D/KF-agent-disk.raw"'
  [ -z "$(pgrep -f -- "-qmp unix:$D/KF")" ] && rm -f "$KF_IMG" "$KF_PW" && log "KF image removed"
fi
log "QUEUE DONE"
