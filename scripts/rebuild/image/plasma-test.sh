#!/bin/bash
# REBUILD-R5 Plasma test: UEFI boot of the R5 image with a virtio display (-vga virtio), TCG -cpu qemu64.
# sddm autologins the test user into the plasma (Wayland) session. The screen is captured with the
# QMP screendump command: every 5 minutes into latest.ppm, and once more into screen.ppm when the
# operator creates the STOP file in the run directory. Then the VM is powered down with ACPI.
# The host is not touched: UEFI NVRAM is a copy of OVMF_VARS.fd, the display is -display none.
# Runs as the build user (no root). The image is checked afterwards by journal-check.sh (read-only).
#
# Usage: plasma-test.sh <run-tag> [max-seconds]
set -uo pipefail

TAG=$1
MAXT=${2:-3000}
IMG=${BOOT_IMG:-/home/yrslf/alpbahOS/scratch-lfs-bench/images/alpbahos-r5-2026-11-08.raw}
LOGDIR=/home/yrslf/alpbahOS/scratch-lfs-bench/lfs13-logs/boot
OVMF_DIR=/usr/share/edk2/ovmf
RUN=$LOGDIR/$TAG
SERIAL=$RUN/serial.log
QMP=$RUN/qmp.sock

rm -rf "$RUN"
mkdir -p "$RUN"
cp "$OVMF_DIR/OVMF_VARS.fd" "$RUN/OVMF_VARS.fd"

ARGS=(-machine q35 -cpu qemu64 -m 6G -smp 4
      -drive "if=pflash,format=raw,readonly=on,file=$OVMF_DIR/OVMF_CODE.fd"
      -drive "if=pflash,format=raw,file=$RUN/OVMF_VARS.fd"
      -drive "file=$IMG,format=raw,if=virtio"
      -nic user,model=virtio-net-pci
      -vga virtio
      -device qemu-xhci -device usb-kbd -device usb-tablet
      -serial "file:$SERIAL" -display none -no-reboot
      -qmp "unix:$QMP,server,nowait")

{
    echo "mode=uefi accel=tcg cpu=qemu64 display=virtio-vga image=$IMG max_seconds=$MAXT"
    echo "cmd: qemu-system-x86_64 ${ARGS[*]}"
    date -Is
} > "$RUN/command.txt"

qmp() {
    printf "{\"execute\":\"qmp_capabilities\"}\n%s\n" "$1" | socat -t 10 - "UNIX-CONNECT:$QMP" > /dev/null 2>&1
}
shot() {
    qmp "{\"execute\":\"screendump\",\"arguments\":{\"filename\":\"$1\"}}"
}

timeout -k 20 $((MAXT + 900)) qemu-system-x86_64 "${ARGS[@]}" &
QPID=$!
START=$(date +%s)
LAST_SHOT=0
POWERED=0
while kill -0 "$QPID" 2>/dev/null; do
    sleep 20
    NOW=$(date +%s)
    EL=$((NOW - START))
    if [ ! -f "$RUN/login-seen" ] && grep -q "alpbahos login:" "$SERIAL" 2>/dev/null; then
        touch "$RUN/login-seen"
        echo "login prompt seen at ${EL}s" >> "$RUN/timeline.txt"
    fi
    if [ $((NOW - LAST_SHOT)) -ge 300 ] && [ -S "$QMP" ]; then
        shot "$RUN/latest.ppm"
        echo "latest shot at ${EL}s" >> "$RUN/timeline.txt"
        LAST_SHOT=$NOW
    fi
    if [ -f "$RUN/STOP" ] || [ "$EL" -ge "$MAXT" ]; then
        if [ "$POWERED" -eq 0 ] && [ -S "$QMP" ]; then
            shot "$RUN/screen.ppm"
            echo "final shot at ${EL}s (STOP file or max time)" >> "$RUN/timeline.txt"
            qmp "{\"execute\":\"system_powerdown\"}"
            POWERED=1
        fi
    fi
done
wait "$QPID"
RC=$?
LOGIN=$(grep -c "alpbahos login:" "$SERIAL" 2>/dev/null || true)
FAILED=$(grep -c "FAILED" "$SERIAL" 2>/dev/null || true)
{
    echo "qemu_rc=$RC (124 = killed by timeout)"
    echo "login_lines=$LOGIN"
    echo "FAILED_lines=$FAILED"
    echo "screen_ppm=$([ -f "$RUN/screen.ppm" ] && echo yes || echo no)"
} | tee "$RUN/summary.txt"
if [ -f "$RUN/screen.ppm" ]; then
    convert "$RUN/screen.ppm" "$RUN/screen.png" && echo "png=$RUN/screen.png" >> "$RUN/summary.txt"
fi
echo PLASMA_TEST_DONE
