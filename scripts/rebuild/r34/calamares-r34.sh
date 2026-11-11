#!/bin/bash
# INSTALLER-THEME-01 follow-up (round 34): Calamares 3.3.14 draws the partition legend text in a fixed black
# (PartitionLabelsView::drawLabel), unreadable on the dark installer (seen on the r30 summary page). Rebuilt with
# calamares-3.3.14-label-colour.patch (palette WindowText) and the options of scripts/rebuild/r4/deltas/369.replace.sh;
# record calamares-r34 3.3.14-alp1 takes every Calamares file over (REPLACE=1). CMAKE_PREFIX_PATH is /opt/qt6 only (a
# ";" would split the sh -c command line of build-pkg-r10.sh; /usr is searched by default). Run as root on the host.
set -euo pipefail
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
TAR=$SB/blfs-src-13.1/calamares-3.3.14.tar.gz
echo "f6ff212c975bb8dd30a280f5d0096880  $TAR" | md5sum -c -
cd "$WT"
PRE_PATCH=$WT/scripts/rebuild/r34/calamares-3.3.14-label-colour.patch BLD_NAME=calamares-3.3.14 \
  bash scripts/rebuild/r10/build-pkg-r10.sh calamares-r34 3.3.14 "$TAR" cmake - \
  -DCMAKE_INSTALL_SYSCONFDIR=/etc -DCMAKE_PREFIX_PATH=/opt/qt6 -DWITH_QT6=ON -DWITH_PYBIND11=ON \
  -DWITH_PYTHON=ON -DWITH_QML=ON -DBUILD_SCHEMA_TESTING=OFF -DBUILD_TESTING=OFF -DINSTALL_POLKIT=ON \
  -DINSTALL_CONFIG=OFF -DINSTALL_COMPLETION=OFF -Wno-dev
S=$SB/r10/calamares-r34/stage
find "$S" \( -type c -o -type b \) -delete
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py calamares-r34 3.3.14-alp1 "$S" \
    calamares-r34 3.3.14-alp1 usr/share/info/dir
tail -1 "$SB/r10/calamares-r34/audit-isa.txt"
