#!/bin/bash
# INSTALLER-UI-01 (round 40, real-PC test 2026-11-11: installer text sizes). Calamares 3.3.14 rebuilt with
# calamares-3.3.14-alpbahos-r40.patch: the round 34 legend colour fix, plus sidebar items at the default size + 1 (was +4),
# summary page margins 16/8 px and semibold 1.5x headings (was light 2x), and two Turkish strings ("üzerinde ile",
# "MBbölüm"). Options as scripts/rebuild/r4/deltas/369.replace.sh;
# record calamares-r40 3.3.14-alp2 takes every Calamares file over (REPLACE=1). CMAKE_PREFIX_PATH is /opt/qt6 only (a
# ";" would split the sh -c command line of build-pkg-r10.sh; /usr is searched by default). Run as root on the host.
set -euo pipefail
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
TAR=$SB/blfs-src-13.1/calamares-3.3.14.tar.gz
echo "f6ff212c975bb8dd30a280f5d0096880  $TAR" | md5sum -c -
cd "$WT"
PRE_PATCH=$WT/scripts/rebuild/r40/calamares-3.3.14-alpbahos-r40.patch BLD_NAME=calamares-3.3.14 \
  bash scripts/rebuild/r10/build-pkg-r10.sh calamares-r40 3.3.14 "$TAR" cmake - \
  -DCMAKE_INSTALL_SYSCONFDIR=/etc -DCMAKE_PREFIX_PATH=/opt/qt6 -DWITH_QT6=ON -DWITH_PYBIND11=ON \
  -DWITH_PYTHON=ON -DWITH_QML=ON -DBUILD_SCHEMA_TESTING=OFF -DBUILD_TESTING=OFF -DINSTALL_POLKIT=ON \
  -DINSTALL_CONFIG=OFF -DINSTALL_COMPLETION=OFF -Wno-dev
S=$SB/r10/calamares-r40/stage
find "$S" \( -type c -o -type b \) -delete
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py calamares-r40 3.3.14-alp2 "$S" \
    calamares-r40 3.3.14-alp2 usr/share/info/dir
tail -1 "$SB/r10/calamares-r40/audit-isa.txt"
