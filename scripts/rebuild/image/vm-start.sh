#!/bin/bash
# Starts one QEMU guest in the background for the install and installed-system tests (no reader on the serial
# console: -serial file:). Usage: vm-start.sh <uefi|bios> <iso-or-empty> <run-dir> <disk-raw-or-empty> <virtio|sata|nvme> [mem]
# The guest keeps running until qmpctl.py <run-dir> quit (or powerdown). Accelerator: TCG (-cpu qemu64) unless ACCEL=kvm.
set -u
FW=$1; ISO=$2; RUN=$3; DISK=$4; BUS=${5:-virtio}; MEM=${6:-6G}
OVMF=/usr/share/edk2/ovmf
mkdir -p "$RUN"
rm -f "$RUN/qmp.sock"
ARGS=(-cpu qemu64 -m "$MEM" -smp 4 -no-reboot -display none -vga virtio
      -device qemu-xhci -device usb-kbd -device usb-tablet
      -nic user,model=virtio-net-pci
      -serial "file:$RUN/serial.log" -qmp "unix:$RUN/qmp.sock,server,nowait")
[ "${ACCEL:-tcg}" = kvm ] && ARGS+=(-enable-kvm)
if [ "$FW" = uefi ]; then
    cp "$OVMF/OVMF_VARS.fd" "$RUN/OVMF_VARS.fd"
    ARGS=(-machine q35 -drive "if=pflash,format=raw,readonly=on,file=$OVMF/OVMF_CODE.fd"
          -drive "if=pflash,format=raw,file=$RUN/OVMF_VARS.fd" "${ARGS[@]}")
else
    ARGS=(-machine pc "${ARGS[@]}")
fi
[ -n "$ISO" ] && ARGS+=(-drive "file=$ISO,media=cdrom,readonly=on,if=ide,index=2")
if [ -n "$DISK" ]; then
    case "$BUS" in
        virtio) ARGS+=(-drive "file=$DISK,format=raw,if=virtio,cache=unsafe") ;;
        sata)   ARGS+=(-drive "file=$DISK,format=raw,if=none,id=sata0,cache=unsafe" -device ahci,id=ahci0 -device ide-hd,drive=sata0,bus=ahci0.0) ;;
        nvme)   ARGS+=(-drive "file=$DISK,format=raw,if=none,id=nvme0,cache=unsafe" -device nvme,drive=nvme0,serial=alpnvme0,bootindex=1) ;;
        *) echo "bad bus $BUS" >&2; exit 2 ;;
    esac
fi
printf '%s\n' "fw=$FW iso=${ISO:-none} disk=${DISK:-none} bus=$BUS mem=$MEM accel=${ACCEL:-tcg}" "cmd: qemu-system-x86_64 ${ARGS[*]}" > "$RUN/command.txt"
[ -n "${EXTRA_ARGS:-}" ] && ARGS+=(${EXTRA_ARGS})
# KERNEL, INITRD, APPEND (round 20): QEMU direct kernel boot, e.g. the ISO's live kernel with an extra test argument.
[ -n "${KERNEL:-}" ] && ARGS+=(-kernel "$KERNEL" -initrd "$INITRD" -append "$APPEND")
nohup setsid nice -n 19 ionice -c3 qemu-system-x86_64 "${ARGS[@]}" > "$RUN/qemu.out" 2>&1 &
echo "started $RUN"
