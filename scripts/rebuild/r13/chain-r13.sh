#!/bin/bash
# REBUILD-R13: GnuPG for the Flatpak remote verification (BLFS 13.1 stable: npth 1.8, libksba 1.8.0, gnupg 2.5.21).
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
L=$SB/r13/logs
cd "$WT" || exit 1
step() { local name=$1; echo "== $name $(date +%T)" >> "$L/summary.txt"
  if sudo nice -n 19 ionice -c3 bash scripts/rebuild/r11/pkg-url-r11.sh "$@" > "$L/$name.log" 2>&1; then echo "OK $name" >> "$L/summary.txt"; else echo "FAIL $name rc=$? (log $L/$name.log)" >> "$L/summary.txt"; fi; }
step npth 1.8 https://gnupg.org/ftp/gcrypt/npth/npth-1.8.tar.bz2 npth-1.8.tar.bz2 configure - 394 "BLFS 13.1 stable: npth 1.8 (gnupg dependency)"
step libksba 1.8.0 https://gnupg.org/ftp/gcrypt/libksba/libksba-1.8.0.tar.bz2 libksba-1.8.0.tar.bz2 configure - 395 "BLFS 13.1 stable: libksba 1.8.0 (gnupg dependency)"
step gnupg 2.5.21 https://gnupg.org/ftp/gcrypt/gnupg/gnupg-2.5.21.tar.bz2 gnupg-2.5.21.tar.bz2 configure - 396 "BLFS 13.1 stable postlfs/gnupg.html: gnupg 2.5.21" --disable-ldap --disable-tests --disable-gnutls --disable-card-support --disable-dirmngr
echo "DONE $(date +%T)" >> "$L/summary.txt"
