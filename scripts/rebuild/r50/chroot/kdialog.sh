#!/bin/bash
# MIRAZPARTED-02 needs kdialog (not in the image). KDE Gear 26.08.3, same release as kpmcore/partitionmanager; kde/ark.html pattern.
set -e
mkdir build && cd build
cmake -D CMAKE_INSTALL_PREFIX=/usr -D CMAKE_PREFIX_PATH=/opt/qt6 -D CMAKE_BUILD_TYPE=Release -D BUILD_TESTING=OFF -W no-author ..
make
make DESTDIR="$STAGE" install
