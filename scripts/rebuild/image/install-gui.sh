#!/bin/bash
# AlpbahOS 0.9 Beta: Calamares install driven through QEMU QMP (keyboard, mouse, screendumps). Run from the build host.
# Used for the install matrix (docs/verification/iso-beta-0.9-2026-11-09.md, section 4). Coordinates are for the
# guest screen 1280x800 with the installer window as it opens (see the screendumps in the run directory).
#
# Usage: install-gui.sh <run-dir> <disk-mode: msdos|gpt> <user> <password> <hostname>
#   The guest must already be running (vm-start.sh), at the live desktop. The live desktop icon "Install AlpbahOS"
#   is at (58,40): one click selects it, then Enter starts the installer (the double click does not work with qmpctl).
#   The partition page is taken as shown (erase disk on the only disk, vda). msdos = BIOS guest, gpt = UEFI guest
#   (the partition page then shows GPT; the erase option is the first radio button).
# Screendumps: <run-dir>/i-*.png after each step, to check the page before the next click.
set -u
RUN=$1; MODE=$2; USER_NAME=$3; PASS=$4; HOST=$5
Q=/home/yrslf/alpbahOS/wt-t2-kisayol/scripts/rebuild/image/qmpctl.py
q() { python3 "$Q" "$RUN" "$@"; }
NEXT_X=1007; NEXT_Y=637   # "Sonraki"/"Next" button on the welcome, locale, keyboard, partition and users pages
INSTALL_Y=${INSTALL_Y:-652}             # "Kur" button on the summary page
CONFIRM_X=749; CONFIRM_Y=${CONFIRM_Y:-428}  # "Şimdi Kur" in the confirmation dialog

q click 58 40; sleep 1; q key ret; sleep 40; q shot i-00-installer
q click $NEXT_X $NEXT_Y; sleep 2; q shot i-01-locale          # welcome -> locale (Türkçe, tr_TR)
q click $NEXT_X $NEXT_Y; sleep 2; q shot i-02-keyboard       # locale -> keyboard (Turkish, Ontanımlı = Turkish-Q)
q click $NEXT_X $NEXT_Y; sleep 2; q shot i-03-partition      # keyboard -> partition (erase vda)
q click $NEXT_X $NEXT_Y; sleep 2; q shot i-04-users          # partition -> users
q click 404 180; q text "Test User"
q click 404 236; q key $(for i in $(seq 1 30); do echo -n "backspace "; done); q text "$USER_NAME"
q click 404 292; q key end $(for i in $(seq 1 40); do echo -n "backspace "; done); q text "$HOST"
q click 404 348; q text "$PASS"
q click 610 348; q text "$PASS"
sleep 1; q shot i-05-users-filled
q click $NEXT_X $NEXT_Y; sleep 3; q shot i-06-summary        # users -> summary (overview)
q click $NEXT_X $INSTALL_Y; sleep 3; q shot i-07-confirm     # summary -> confirmation dialog
q click $CONFIRM_X $CONFIRM_Y; sleep 5; q shot i-08-running  # confirm: the installation starts
echo "installer started: poll i-* screens and the serial log for the Calamares finished page"
