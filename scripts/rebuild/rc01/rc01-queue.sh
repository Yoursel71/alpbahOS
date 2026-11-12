#!/bin/bash
# BETA-RC-01 matrix queue on ISO rc01: one guest of this queue at a time, each behind the gate.
# Order keeps /home above 20 GiB: BIOS install and its rows, KF and F1 (each a new install, deleted right after its
# checks) while only the BIOS install exists, then the UEFI install and its rows, the PLY loop, L3 and the TCG rows.
# Usage: rc01-queue.sh [from-step]    steps: lane1 bios kf f1 lane2 uefi ply live tcg
cd /home/yrslf/alpbahOS/scratch-lfs-bench/lfs13-logs/iso-beta-0.9/rc01/matrix || exit 1
. /home/yrslf/alpbahOS/wt-rc01/scripts/rebuild/rc01/env-rc01.sh
RBD=$MATRIX_WT/scripts/rebuild
MM=$M
LANES=$RBD/r20/r20-lanes.sh
log() { echo "[$(date +%T)] $*" >> queue.log; }
run() { local n=$1 min=$2; shift 2; gate "$min" >> "run-$n.out" 2>&1 || { log "$n gate timeout"; return 1; }
  log "$n start"; "$@" >> "run-$n.out" 2>&1; log "$n end rc=$?"; }
FROM=${1:-lane1}; go=0
want() { [ "$1" = "$FROM" ] && go=1; [ "$go" = 1 ]; }

if want lane1; then
  run lane1 40 env ROUND=rc01 NOCLOBBER=1 bash "$LANES" "$ISO_PATH" lane1
fi
if want bios; then
  run B1 20 env OUTD=$D BUS=virtio MEM=6G bash "$RBD/r21/diag-r21.sh" bios "$IMGB_PATH" B1
  run B2 20 bash "$MM" diag B2
  run S1 20 bash "$MM" s1
  run R1 20 bash "$MM" r1
fi
if want kf; then
  run KF 40 bash -c ". $RBD/rc01/env-rc01.sh; bash \$M kflive && bash \$M kffill && bash \$M kfgo && bash \$M kfdisk"
  run KF-agent 20 bash -c '
    . '"$RBD"'/rc01/env-rc01.sh; RBD='"$RBD"'; MM=$M; MATRIX_LIB=1 . "$MM"
    bash "$MM" kfagent KF-agent; R=$D/KF-agent; gs() { python3 "$RBD/r21/gsh.py" "$@"; }
    gs "$R" 40 "r21m-as-user busctl --user call org.kde.keyboard /Layouts org.kde.KeyboardLayouts getLayoutsList; localectl status; tr \"\\0\" \"\\n\" < /proc/\$(pgrep -u testuser -x kwin_wayland | head -1)/environ | grep -i xkb; r21m-as-user --bg konsole; sleep 7; pgrep -u testuser -a konsole"
    q "$R" key q; sleep 1; q "$R" key q; sleep 1; shot "$R" kf-key-q
    gs "$R" 20 "r21m-as-user --bg konsole -e /usr/bin/alpbahos-keyboard --check; sleep 8; pgrep -u testuser -af alpbahos-keyboard"
    shot "$R" kf-check-0; q "$R" key q; sleep 2; shot "$R" kf-check-1-read; q "$R" key d; sleep 2; shot "$R" kf-check-2-answer-e
    vmquit "$R" && rm -f "$D/KF-agent-disk.raw"'
  [ -z "$(pgrep -f -- "-qmp unix:$D/KF")" ] && rm -f "$KF_IMG" "$KF_PW" && log "KF image removed"
fi
if want f1; then
  run F1 40 env FAILSHOTS=12 bash "$MM" f1
  { LO=$(sudo losetup -r -f -P --show "$F1_IMG"); TM=$(mktemp -d /tmp/rc01-f1.XXXX)
    sudo mount -o ro,noload "${LO}p1" "$TM" && { echo "== F1 target /boot/grub"; sudo ls "$TM/boot/grub"; sudo head -c 300 "$TM/boot/grub/grub.cfg"; echo; sudo umount "$TM"; }
    sudo losetup -d "$LO"; rmdir "$TM"; } > F1-grub.txt 2>&1
  [ -z "$(pgrep -f -- "-qmp unix:$D/F1")" ] && rm -f "$F1_IMG" && log "F1 image removed"
fi
if want lane2; then
  run lane2 40 env ROUND=rc01 NOCLOBBER=1 bash "$LANES" "$ISO_PATH" lane2
fi
if want uefi; then
  run U1 20 env OUTD=$D BUS=virtio MEM=6G FLATPAK=1 bash "$RBD/r21/diag-r21.sh" uefi "$IMGU_PATH" U1
  run APPS 20 bash "$MM" apps
  [ -e sbx-catalog ] || cp -a /home/yrslf/alpbahOS/scratch-lfs-bench/lfs13-logs/iso-beta-0.9/r39x/sbx-catalog sbx-catalog
  run SBX 20 bash -c '
    . '"$RBD"'/rc01/env-rc01.sh; RBD='"$RBD"'; MM=$M; MATRIX_LIB=1 . "$MM"; gs() { python3 "$RBD/r21/gsh.py" "$D/SBX" "$@"; }
    bash "$MM" mkcopy uefi SBX-disk; agent_start SBX uefi SBX-disk virtio 6G; greeter_login "$D/SBX" sbx
    T64=$(tar -C sbx-catalog -czf - . | base64 -w0); G64=$(base64 -w0 < "$RBD/r39x/sbx-guest-r39x.sh"); A64=$(base64 -w0 < "$RBD/r36x/alp-check-r36x.sh")
    gs 60 "mkdir -p /var/lib/alp-sbx-test && echo $T64 | base64 -d | tar -xzf - -C /var/lib/alp-sbx-test && chown -R root:root /var/lib/alp-sbx-test && chmod -R go-w /var/lib/alp-sbx-test && echo $G64 | base64 -d > /root/sbx.sh && echo $A64 | base64 -d > /root/alp-check.sh && echo staged"
    for p in hello escape user final; do gs 900 "bash /root/sbx.sh $p" > "SBX-$p.txt" 2>&1; cat "SBX-$p.txt"; done
    gs 300 "bash /root/alp-check.sh good" > ALP-good.txt 2>&1
    gs 300 "bash /root/alp-check.sh tamper" > ALP-tamper.txt 2>&1
    gs 60 "su - testuser -c \"alp install -y htop\"; echo rc=\$?" > ALP-testuser-install.txt 2>&1
    gs 30 "echo failed units: \$(systemctl --failed --no-legend | wc -l); coredumps \$(ls /var/lib/systemd/coredump | wc -l)" > SBX-units.txt 2>&1
    shot "$D/SBX" sbx-end; vmquit "$D/SBX" && rm -f "$D/SBX-disk.raw"'
fi
if want ply; then
  [ -e env.sh ] || cp "$RBD/rc01/env-rc01.sh" env.sh
  run PLY 20 env MAXCYC=20 MAXMIN=60 bash "$RBD/r39y/ply-loop-r39y.sh"
fi
if want live; then
  run L3 20 bash "$MM" live L3 bios kvm 150
fi
if want tcg; then
  for r in "L2a uefi" "L2b uefi" "L4a bios" "L4b bios"; do set -- $r; run "$1" 20 bash "$MM" live "$1" "$2" tcg 600; done
fi
log "QUEUE DONE"
