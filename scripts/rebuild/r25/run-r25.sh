#!/bin/bash
# Round 25: every row of review section D on one ISO, run one after the other as the build user (sudo only inside the
# called scripts for loop mounts). Evidence: scratch-lfs-bench/lfs13-logs/iso-beta-0.9/r25/. Each step writes its own
# log; a failed step is logged and the next one runs (the reviewer reads the results; this script judges nothing).
# Usage: run-r25.sh <iso> [steps...]   steps: installs grub splash live timing welcome (default: all, in this order)
set -u
ISO=$(realpath "$1"); shift
STEPS=${*:-installs grub splash live timing welcome}
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
B=/home/yrslf/alpbahOS/scratch-lfs-bench
L=$B/lfs13-logs/iso-beta-0.9/r25
IMGB=$B/images/inst-bios-msdos-r25.raw
IMGU=$B/images/inst-uefi-gpt-r25.raw
Q() { python3 "$WT/scripts/rebuild/image/qmpctl.py" "$@" > /dev/null 2>&1; }
G() { bash "$WT/scripts/rebuild/r24/vm-gui.sh" "$@"; }
log() { echo "[$(date +%T)] $*" | tee -a "$L/run.log"; }
mkdir -p "$L"
cd "$WT"
for step in $STEPS; do
case $step in
installs)
    log "installs (I1 BIOS, L1 live UEFI, I2 UEFI)"
    ROUND=r25 bash scripts/rebuild/r20/r20-lanes.sh "$ISO" installs > "$L/lanes.out" 2>&1 ;;
grub)
    log "GRUB rows"
    for fw in bios uefi; do
        img=$IMGB; [ $fw = uefi ] && img=$IMGU
        ROUND=r25 bash scripts/rebuild/d1/d1-grub-tests.sh menu $fw "$img" G-$fw-menu > "$L/G-$fw-menu.out" 2>&1
        for m in 1280x720 1920x1080; do
            ROUND=r25 bash scripts/rebuild/d1/d1-grub-tests.sh mode $fw "$img" G-$fw-$m $m > "$L/G-$fw-$m.out" 2>&1
        done
    done ;;
splash)
    log "splash rows (boot and shutdown)"
    for fw in bios uefi; do
        img=$IMGB; [ $fw = uefi ] && img=$IMGU
        ROUND=r25 bash scripts/rebuild/r23/d2-splash-tests.sh splash $fw "$img" P-$fw-boot > "$L/P-$fw-boot.out" 2>&1
        R=$L/P-$fw-shutdown; mkdir -p "$R"
        EXTRA_ARGS="-snapshot" ACCEL=kvm bash scripts/rebuild/image/vm-start.sh $fw "" "$R" "$img" virtio 6G > /dev/null
        sleep 60; python3 scripts/rebuild/r24/qmp-burst.py "$R" 60 > "$R/burst.out" 2>&1
        python3 -c "
import glob
from PIL import Image
for f in sorted(glob.glob('$R/burst-*.ppm')): Image.open(f).save(f[:-4] + '.png')"
    done ;;
live)
    log "live GRUB menu rows"
    ROUND=r25 bash scripts/rebuild/r23/d2-splash-tests.sh livemenu bios "$ISO" LM-bios > "$L/LM-bios.out" 2>&1
    ROUND=r25 bash scripts/rebuild/r23/d2-splash-tests.sh livemenu uefi "$ISO" LM-uefi > "$L/LM-uefi.out" 2>&1 ;;
timing)
    log "B1/U1 diagnostics with the boot timing hook"
    DIAG_HOOK=$WT/scripts/rebuild/r23/hook-boot-r23.sh OUTD=$L bash scripts/rebuild/r21/diag-r21.sh bios "$IMGB" B1D > "$L/diag-B1D.log" 2>&1
    FLATPAK=1 DIAG_HOOK=$WT/scripts/rebuild/r23/hook-boot-r23.sh OUTD=$L bash scripts/rebuild/r21/diag-r21.sh uefi "$IMGU" U1D > "$L/diag-U1D.log" 2>&1 ;;
welcome)
    log "Welcome app rows (BIOS copy)"
    R=$L/W1
    G start bios "$IMGB" "$R"
    G login "$R"; sleep 50; Q "$R" shot w01-first-login
    pos=$(python3 scripts/rebuild/r25/find-window.py "$R/w01-first-login.png")
    echo "window at: ${pos:-not found}" >> "$L/run.log"
    if [ -n "$pos" ]; then
        set -- $pos; X=$1; Y=$2
        # keyboard: Tab moves the focus ring (first card -> second card)
        Q "$R" key tab; sleep 1; Q "$R" shot w02-tab-focus
        # Atatürk, Glass (disabled: no click effect), Ortada, then "Uygula ve başla"
        Q "$R" click $((X + 743)) $((Y + 197)); sleep 1
        Q "$R" click $((X + 743)) $((Y + 331)); sleep 1
        Q "$R" click $((X + 743)) $((Y + 465)); sleep 1
        Q "$R" shot w03-choices-ataturk-orta
        Q "$R" click $((X + 836)) $((Y + 662)); sleep 20
        Q "$R" shot w04-desktop-ataturk-orta
        # open again from the run dialog, choose alpbahOS and Solda
        Q "$R" combo alt f2; sleep 3; G type "$R" "alpbah-hosgeldin"; Q "$R" key ret; sleep 12
        Q "$R" shot w05-reopened
        pos2=$(python3 scripts/rebuild/r25/find-window.py "$R/w05-reopened.png")
        echo "window again at: ${pos2:-not found}" >> "$L/run.log"
        if [ -n "$pos2" ]; then
            set -- $pos2; X=$1; Y=$2
            Q "$R" click $((X + 382)) $((Y + 197)); sleep 1
            Q "$R" click $((X + 382)) $((Y + 465)); sleep 1
            Q "$R" shot w06-choices-alpbahos-sol
            Q "$R" click $((X + 836)) $((Y + 662)); sleep 20
            Q "$R" shot w07-desktop-alpbahos-sol
        fi
    fi
    # second login: power off the copy, boot it again, log in, the app must not open
    Q "$R" powerdown; sleep 25; Q "$R" quit; sleep 3
    G boot bios "$R" second
    G login "$R/second"; sleep 50; Q "$R/second" shot w08-second-login
    G stop "$R" ;;
esac
done
log "done: $STEPS"
