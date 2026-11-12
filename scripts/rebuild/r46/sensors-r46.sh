#!/bin/bash
# SENSORS-01 (round 46): iio-sensor-proxy 3.9 for 2-in-1 laptops and tablets: KDE (KScreen) rotates the screen from the
# accelerometer and PowerDevil can use the ambient light sensor through it. Not in BLFS 13.1; upstream tag archive from
# gitlab.freedesktop.org/hadess/iio-sensor-proxy, sha512 = Fedora's iio-sensor-proxy 3.9 `sources`. Meson defaults
# (no tests, no GTK test apps, no docs; Qualcomm SSC off without libssc). The service is started by its udev rule only
# when a sensor exists. Row 465. Run as root. Env NICE (15), JOBS (8).
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
T=$SB/apps01-src/sensors/iio-sensor-proxy-3.9.tar.bz2
export NICE=${NICE:-15} JOBS=${JOBS:-8}
[ "$(sha512sum < "$T" | cut -c1-128)" = 397f8a6cf6757d18e6a1d1744abf88617636566a302c189e13d3079ccbed470899d1963378eb50483c585b3aabbe67691cfe5580b030337781c7e3dbf3f69695 ] \
    || { echo "sha512 != Fedora"; exit 1; }
d=$SB/r10/dl/$(basename "$T"); [ -e "$d" ] || ln "$T" "$d"; cmp -s "$T" "$d" || { echo "$d differs"; exit 1; }
bash "$WT/scripts/rebuild/r11/pkg-url-r11.sh" iio-sensor-proxy 3.9 \
    https://gitlab.freedesktop.org/hadess/iio-sensor-proxy/-/archive/3.9/iio-sensor-proxy-3.9.tar.bz2 \
    iio-sensor-proxy-3.9.tar.bz2 meson - 465 \
    "SENSORS-01: upstream tag 3.9 archive (not in BLFS 13.1); sha512 397f8a6c... = Fedora sources"
grep -E 'unallowed' "$SB/r10/iio-sensor-proxy/audit-isa.txt" | tail -1
ls "$SB/r4-root/usr/lib/udev/rules.d/" | grep -i iio
echo "sensors done $(date +%T)"
