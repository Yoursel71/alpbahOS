#!/bin/bash
# Round 21 matrix, test copies only: prints one line per boot on ttyS0 and gives the host a root shell on ttyS1
# (QEMU -serial unix:<run-dir>/ser1.sock; host side scripts/rebuild/r21/gsh.py). Never part of a product image.
echo "R21M begin boot_id=$(cat /proc/sys/kernel/random/boot_id) $(date -Is) epoch=$(date +%s)" > /dev/ttyS0
stty -F /dev/ttyS1 115200 raw -echo
exec bash --norc --noprofile < /dev/ttyS1 > /dev/ttyS1 2>&1
