#!/bin/bash
# REBUILD-R2 image phase: headless QEMU boot of the image, BIOS or UEFI (OVMF), serial to a log file.
# Runs as the build user (no root). UEFI uses a fresh COPY of OVMF_VARS per run, so host NVRAM is untouched.
# Ends with an ACPI power-down (QEMU monitor) once the login prompt appears, or is killed at the timeout.
#
# Usage: boot-test.sh bios|uefi tcg|kvm <run-tag>
#   tcg: no accelerator, -cpu qemu64.   kvm: -enable-kvm -cpu qemu64 (generic CPU model, no host passthrough).
set -uo pipefail

MODE=$1
ACCEL=$2
TAG=$3
IMG=/home/yrslf/alpbahOS/scratch-lfs-bench/images/alpbahos-r2-ch11-2026-11-07.raw
LOGDIR=/home/yrslf/alpbahOS/scratch-lfs-bench/lfs13-logs/boot
OVMF_DIR=/usr/share/edk2/ovmf
TIMEOUT=300

RUN=$LOGDIR/$TAG
rm -rf "$RUN"
mkdir -p "$RUN"
SERIAL=$RUN/serial.log
MON=$RUN/mon.sock

ARGS=(-m 4G -smp 4 -cpu qemu64
      -drive "file=$IMG,format=raw,if=virtio"
      -nic user,model=virtio-net-pci
      -serial "file:$SERIAL" -display none -no-reboot
      -monitor "unix:$MON,server,nowait")
[ "$ACCEL" = kvm ] && ARGS+=(-enable-kvm)

if [ "$MODE" = uefi ]; then
    cp "$OVMF_DIR/OVMF_VARS.fd" "$RUN/OVMF_VARS.fd"
    ARGS=(-machine q35
          -drive "if=pflash,format=raw,readonly=on,file=$OVMF_DIR/OVMF_CODE.fd"
          -drive "if=pflash,format=raw,file=$RUN/OVMF_VARS.fd"
          "${ARGS[@]}")
fi

# Power down after the login prompt shows (plus a grace period), so systemd finishes its boot jobs.
(
    for _ in $(seq 1 $TIMEOUT); do
        grep -q 'alpbahos login:' "$SERIAL" 2>/dev/null && break
        sleep 1
    done
    sleep 15
    [ -S "$MON" ] && printf 'system_powerdown\n' | socat - "UNIX-CONNECT:$MON" >/dev/null 2>&1
) &
WATCH=$!

{
    echo "mode=$MODE accel=$ACCEL cpu=qemu64 image=$IMG"
    echo "cmd: qemu-system-x86_64 ${ARGS[*]}"
    date -Is
} > "$RUN/command.txt"

timeout -k 10 $TIMEOUT qemu-system-x86_64 "${ARGS[@]}"
RC=$?
kill "$WATCH" 2>/dev/null
wait "$WATCH" 2>/dev/null

LOGIN=$(grep -c 'alpbahos login:' "$SERIAL" 2>/dev/null || true)
FAILED=$(grep -c 'FAILED' "$SERIAL" 2>/dev/null || true)
{
    echo "qemu_rc=$RC (124 = killed by timeout)"
    echo "login_lines=$LOGIN"
    echo "FAILED_lines=$FAILED"
    grep -m1 'alpbahos login:' "$SERIAL" 2>/dev/null
} | tee "$RUN/summary.txt"
