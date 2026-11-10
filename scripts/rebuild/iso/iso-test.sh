#!/bin/bash
# alpbahOS BETA ISO test: QEMU TCG (-cpu qemu64), serial to a file, QMP screendumps every 60 s and at the end.
# Runs as the build user (no root). UEFI uses a COPY of OVMF_VARS.fd per run (no host NVRAM). Display: virtio VGA.
# Usage: iso-test.sh <bios|uefi> <run-tag> <max-seconds> <iso-or-empty> [disk-image-or-empty]
#   iso given  -> the ISO is attached as CD-ROM (live boot test)
#   disk given -> the disk is attached as virtio (install target, or installed-system boot)
# Ends with QMP system_powerdown after max-seconds or when the STOP file exists in the run directory.
set -uo pipefail
FW=$1; TAG=$2; MAXT=$3; ISO=${4:-}; DISK=${5:-}
LOGDIR=/home/yrslf/alpbahOS/scratch-lfs-bench/lfs13-logs/boot/iso-beta
OVMF_DIR=/usr/share/edk2/ovmf
RUN=$LOGDIR/$TAG
SERIAL=$RUN/serial.log
QMP=$RUN/qmp.sock
rm -rf "$RUN"; mkdir -p "$RUN"

ARGS=(-cpu qemu64 -m 4G -smp 4 -vga virtio
      -device qemu-xhci -device usb-kbd -device usb-tablet
      -nic user,model=virtio-net-pci
      -serial "file:$SERIAL" -display none -no-reboot
      -qmp "unix:$QMP,server,nowait")
if [ "$FW" = uefi ]; then
    cp "$OVMF_DIR/OVMF_VARS.fd" "$RUN/OVMF_VARS.fd"
    ARGS=(-machine q35 -drive "if=pflash,format=raw,readonly=on,file=$OVMF_DIR/OVMF_CODE.fd"
          -drive "if=pflash,format=raw,file=$RUN/OVMF_VARS.fd" "${ARGS[@]}")
else
    ARGS=(-machine pc "${ARGS[@]}")
fi
# ACCEL=kvm: -enable-kvm with the same generic CPU model (-cpu qemu64). Default: TCG.
[ "${ACCEL:-tcg}" = kvm ] && ARGS+=(-enable-kvm)
[ -n "$ISO" ] && ARGS+=(-drive "file=$ISO,media=cdrom,readonly=on,if=ide,index=2")
# DISK_BUS: virtio (default), sata (ahci + ide-hd) or nvme. The same raw image in each case.
if [ -n "$DISK" ]; then
    case "${DISK_BUS:-virtio}" in
        virtio) ARGS+=(-drive "file=$DISK,format=raw,if=virtio,cache=unsafe") ;;
        sata)   ARGS+=(-drive "file=$DISK,format=raw,if=none,id=sata0,cache=unsafe" -device ahci,id=ahci0 -device ide-hd,drive=sata0,bus=ahci0.0) ;;
        nvme)   ARGS+=(-drive "file=$DISK,format=raw,if=none,id=nvme0,cache=unsafe" -device nvme,drive=nvme0,serial=alpnvme0) ;;
        *) echo "bad DISK_BUS" >&2; exit 2 ;;
    esac
fi
{
    echo "fw=$FW tcg qemu64 iso=${ISO:-none} disk=${DISK:-none} max_seconds=$MAXT"
    echo "cmd: qemu-system-x86_64 ${ARGS[*]}"
    date -Is
} > "$RUN/command.txt"

qmp() { printf '{"execute":"qmp_capabilities"}\n%s\n' "$1" | socat -t 10 - "UNIX-CONNECT:$QMP" > /dev/null 2>&1; }
shot() { qmp "{\"execute\":\"screendump\",\"arguments\":{\"filename\":\"$1\"}}"; }

nice -n 19 ionice -c3 timeout -k 20 $((MAXT + 900)) qemu-system-x86_64 "${ARGS[@]}" &
QPID=$!
START=$(date +%s); LAST=0; POWERED=0
while kill -0 "$QPID" 2>/dev/null; do
    sleep 15
    NOW=$(date +%s); EL=$((NOW - START))
    if [ -S "$QMP" ] && [ $((NOW - LAST)) -ge 60 ]; then
        shot "$RUN/latest.ppm"; echo "shot at ${EL}s" >> "$RUN/timeline.txt"; LAST=$NOW
    fi
    if grep -q "login:" "$SERIAL" 2>/dev/null && [ ! -f "$RUN/login-seen" ]; then
        touch "$RUN/login-seen"; echo "login prompt at ${EL}s" >> "$RUN/timeline.txt"
    fi
    if [ -f "$RUN/STOP" ] || [ "$EL" -ge "$MAXT" ]; then
        if [ "$POWERED" -eq 0 ] && [ -S "$QMP" ]; then
            shot "$RUN/screen.ppm"; echo "final shot at ${EL}s" >> "$RUN/timeline.txt"
            qmp '{"execute":"quit"}'; POWERED=1
        fi
    fi
done
wait "$QPID"; RC=$?
{
    echo "qemu_rc=$RC"
    echo "login_lines=$(grep -c 'login:' "$SERIAL" 2>/dev/null || true)"
    echo "FAILED_lines=$(grep -c 'FAILED' "$SERIAL" 2>/dev/null || true)"
} | tee "$RUN/summary.txt"
[ -f "$RUN/screen.ppm" ] && nice -n 19 convert "$RUN/screen.ppm" "$RUN/screen.png" 2>/dev/null
echo ISO_TEST_DONE
