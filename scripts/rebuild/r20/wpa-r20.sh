#!/bin/bash
# REBUILD-R20 (NET-FW-01): wpa_supplicant 2.12 for NetworkManager Wi-Fi, BLFS 13.1-systemd basicnet/wpa_supplicant.html.
# Run as root on the host; the build runs in a chroot of r4-root with generic x86-64 flags (D146).
# Source: https://w1.fi/releases/wpa_supplicant-2.12.tar.gz, MD5 3f1af56655ebca941d2035358331bbc9 (book page).
#   The upstream signature (.asc, DSA key EC4AA0A991A5F2464582D52D2B6EF432EFC895FA) could not be checked: the key was
#   not available from keys.openpgp.org or keyserver.ubuntu.com on 2026-11-10. The book MD5 matches.
# Build config: the book's .config plus its NetworkManager D-Bus block. Deviation from the book (recorded in the
#   evidence note): CONFIG_SAE=y and CONFIG_OWE=y, so WPA3-Personal and Enhanced Open networks work; the
#   per-interface wpa_supplicant-*.conf setup is skipped (the book says to skip it when NetworkManager is used).
# Usage: wpa-r20.sh <tarball>
set -euo pipefail
export LC_ALL=C
TAR=$1
MD5=3f1af56655ebca941d2035358331bbc9
NAME=wpa_supplicant; VER=2.12
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=$SB/r4-root
W=$SB/r10/$NAME
[ -d "$R4/usr/lib" ] || { echo "r4-root missing"; exit 1; }
echo "$MD5  $TAR" | md5sum -c - || { echo "md5 mismatch"; exit 1; }
echo "tarball sha256 $(sha256sum "$TAR" | cut -d' ' -f1)"
[ ! -e "$R4/usr/sbin/wpa_supplicant" ] || { echo "wpa_supplicant already in r4-root"; exit 1; }

BLD=/tmp/build-$NAME
STG=/tmp/stage-$NAME
rm -rf "$W" "$R4$BLD" "$R4$STG"
mkdir -p "$W" "$R4$BLD"
tar xf "$TAR" -C "$R4$BLD" --strip-components=1
cat > "$R4$BLD/wpa_supplicant/.config" << "EOF"
CONFIG_BACKEND=file
CONFIG_CTRL_IFACE=y
CONFIG_DEBUG_FILE=y
CONFIG_DEBUG_SYSLOG=y
CONFIG_DEBUG_SYSLOG_FACILITY=LOG_DAEMON
CONFIG_DRIVER_NL80211=y
CONFIG_DRIVER_WEXT=y
CONFIG_DRIVER_WIRED=y
CONFIG_EAP_GTC=y
CONFIG_EAP_LEAP=y
CONFIG_EAP_MD5=y
CONFIG_EAP_MSCHAPV2=y
CONFIG_EAP_OTP=y
CONFIG_EAP_PEAP=y
CONFIG_EAP_TLS=y
CONFIG_EAP_TTLS=y
CONFIG_IEEE8021X_EAPOL=y
CONFIG_IPV6=y
CONFIG_LIBNL32=y
CONFIG_PEERKEY=y
CONFIG_PKCS12=y
CONFIG_READLINE=y
CONFIG_SMARTCARD=y
CONFIG_WPS=y
CFLAGS += -I/usr/include/libnl3
CONFIG_CTRL_IFACE_DBUS=y
CONFIG_CTRL_IFACE_DBUS_NEW=y
CONFIG_CTRL_IFACE_DBUS_INTRO=y
# alpbahOS deviation from the book: WPA3-Personal (SAE) and Enhanced Open (OWE).
CONFIG_SAE=y
CONFIG_OWE=y
EOF
mount --bind /dev "$R4/dev"; mount -t proc proc "$R4/proc"
cleanup() { umount "$R4/proc" "$R4/dev" 2>/dev/null || true; rm -rf "$R4$BLD" "$R4$STG"; }
trap cleanup EXIT
CMD="cd $BLD/wpa_supplicant && make -j16 V=1 BINDIR=/usr/sbin LIBDIR=/usr/lib EXTRA_CFLAGS='-O2 -march=x86-64 -mtune=generic' \
 && install -d $STG/usr/sbin $STG/usr/share/man/man5 $STG/usr/share/man/man8 $STG/usr/lib/systemd/system \
      $STG/usr/share/dbus-1/system-services $STG/etc/dbus-1/system.d \
 && install -v -m755 wpa_cli wpa_passphrase wpa_supplicant $STG/usr/sbin/ \
 && install -v -m644 doc/docbook/wpa_supplicant.conf.5 $STG/usr/share/man/man5/ \
 && install -v -m644 doc/docbook/wpa_cli.8 doc/docbook/wpa_passphrase.8 doc/docbook/wpa_supplicant.8 $STG/usr/share/man/man8/ \
 && install -v -m644 systemd/*.service $STG/usr/lib/systemd/system/ \
 && install -v -m644 dbus/fi.w1.wpa_supplicant1.service $STG/usr/share/dbus-1/system-services/ \
 && install -v -m644 dbus/dbus-wpa_supplicant.conf $STG/etc/dbus-1/system.d/wpa_supplicant.conf"
set +e
chroot "$R4" /usr/bin/env PATH=/usr/bin:/usr/sbin sh -c "set -e; $CMD" > "$W/build.log" 2>&1
RC=$?
set -e
echo "chroot build rc=$RC (log $W/build.log)"
[ "$RC" = 0 ] || exit 1
grep -q 'march=x86-64' "$W/build.log" || { echo "generic flags not seen in the build log"; exit 1; }
rm -rf "$W/stage" && cp -a "$R4$STG" "$W/stage"
echo "staged files: $(find "$W/stage" -type f -o -type l | wc -l)"
set +e
"$WT/scripts/lfs-blfs/cpu-baseline/audit-isa.sh" "$W/stage" > "$W/audit-isa.txt" 2>&1
ARC=$?
set -e
echo "audit-isa rc=$ARC: $(tail -1 "$W/audit-isa.txt")"
[ "$ARC" = 0 ] || exit 1
cd "$WT"
bash scripts/rebuild/r7/apply-r7.sh "$WT/scripts/rebuild/r8/stage-record-r8.py" "$NAME" "$VER" "$W/stage" "$NAME" "$VER"
