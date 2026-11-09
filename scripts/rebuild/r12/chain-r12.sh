#!/bin/bash
# REBUILD-R12: the remaining Flatpak chain packages (one package per call of pkg-url-r11.sh: build, audit, record, row).
# Packages already recorded in this round (json-glib, libxmlb, nghttp2, libsoup3, glib-networking, gpgme, ostree) are not repeated.
# A failing package is logged in SB/r12/logs/summary.txt and the run goes on. Run as yrslf (sudo inside).
set -u
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
L=$SB/r12/logs
mkdir -p "$L"
cd "$WT" || exit 1
echo "== run $(date +%T)" >> "$L/summary.txt"
step() {
  local name=$1
  echo "== $name $(date +%T)" >> "$L/summary.txt"
  if sudo nice -n 19 ionice -c3 bash scripts/rebuild/r11/pkg-url-r11.sh "$@" > "$L/$name.log" 2>&1; then
    echo "OK $name" >> "$L/summary.txt"
  else
    echo "FAIL $name rc=$? (log $L/$name.log)" >> "$L/summary.txt"
  fi
}
# libsecret: its files are recorded under kwallet 6.29.0 in this root (not a libsecret record). The new record takes the
# files over (KEEP_SHARED=0 REPLACE=1; alp transfer moves the ownership from kwallet).
echo "== libsecret $(date +%T) (takeover of kwallet-owned files)" >> "$L/summary.txt"
if sudo env KEEP_SHARED=0 REPLACE=1 nice -n 19 ionice -c3 bash scripts/rebuild/r11/pkg-url-r11.sh libsecret 0.21.7 https://download.gnome.org/sources/libsecret/0.21/libsecret-0.21.7.tar.xz libsecret-0.21.7.tar.xz meson - 383 "BLFS 13.1 gnome/libsecret.html: 0.21.7; files taken over from kwallet 6.29.0" -Dintrospection=false -Dvapi=false -Dgtk_doc=false -Dmanpage=false > "$L/libsecret.log" 2>&1; then
  echo "OK libsecret" >> "$L/summary.txt"
else
  echo "FAIL libsecret rc=$? (log $L/libsecret.log)" >> "$L/summary.txt"
fi
step libfyaml 0.9.6 https://github.com/pantoniou/libfyaml/releases/download/v0.9.6/libfyaml-0.9.6.tar.gz libfyaml-0.9.6.tar.gz configure - 389 "BLFS 13.1 general/libfyaml.html: 0.9.6 (dependency of appstream, built first)"
step appstream 1.1.6https://www.freedesktop.org/software/appstream/releases/AppStream-1.1.6.tar.xz AppStream-1.1.6.tar.xz meson - 385 "BLFS 13.1 general/appstream.html: AppStream 1.1.6 (curl --tlsv1.2 needed)" -Dapidocs=false -Dgir=false -Dvapi=false -Dqt=false -Dstemming=false -Dsystemd=false -Dtests=false -Dcompose=false -Dapt-support=false -Ddocs=false
step flatpak 1.18.4 https://github.com/flatpak/flatpak/releases/download/1.18.4/flatpak-1.18.4.tar.xz flatpak-1.18.4.tar.xz meson - 387 "upstream newest stable (not in BLFS 13.1 index): 1.18.4" -Dsystem_bubblewrap=/usr/bin/bwrap -Dsystem_dbus_proxy=/usr/bin/xdg-dbus-proxy -Dsystemd=disabled -Ddocbook_docs=disabled -Dman=disabled -Dtests=false -Dsystem_helper=enabled -Dsystem_install_dir=/var/lib/flatpak
echo "DONE $(date +%T)" >> "$L/summary.txt"
