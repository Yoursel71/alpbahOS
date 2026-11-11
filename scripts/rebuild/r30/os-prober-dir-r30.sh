#!/bin/bash
# INSTALL-DUALBOOT-01 (round 30): os-prober keeps its label counter in /var/lib/os-prober (Debian's os-prober.dirs);
# without it every run printed "common.sh: line 42: /var/lib/os-prober/labels: No such file or directory" (round 29).
# alp records hold files, so the directory comes from systemd-tmpfiles at boot (live and installed). Record
# os-prober-dir-r30 adds /usr/lib/tmpfiles.d/os-prober.conf. Run as root on the host.
set -euo pipefail
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
ST=$SB/r30/stage-osprober-dir
rm -rf "$ST"; mkdir -p "$ST/usr/lib/tmpfiles.d"
printf '# alpbahOS: label counter directory of os-prober (round 30)\nd /var/lib/os-prober 0755 root root -\n' > "$ST/usr/lib/tmpfiles.d/os-prober.conf"
chmod 644 "$ST/usr/lib/tmpfiles.d/os-prober.conf"
cd "$WT"
bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py os-prober-dir-r30 1.85-alp2 "$ST" os-prober-dir-r30 1.85-alp2
