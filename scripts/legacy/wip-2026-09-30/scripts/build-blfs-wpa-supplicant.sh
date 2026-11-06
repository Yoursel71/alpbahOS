#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
readonly VERSION=2.11
readonly ARCHIVE="wpa_supplicant-$VERSION.tar.gz"
readonly URL="https://w1.fi/releases/$ARCHIVE"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/wpa_supplicant-$VERSION-alpbahOS-$STAMP"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/wpa_supplicant-$VERSION-$STAMP.log"
readonly STATUS="$LOG_DIR/wpa_supplicant-$VERSION-$STAMP.status"
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run the host orchestrator as the regular Fedora user.'
[[ -d "$LFS" ]] || fail 'The LFS target is missing.'
lfs_validate_target "$LFS" "$DATA"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "meson" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -c \
    '[[ -x /usr/bin/make && -f /usr/include/dbus-1.0/dbus/dbus.h && -f /usr/include/libnl3/netlink/netlink.h && -f /usr/include/openssl/ssl.h && ! -e /usr/sbin/wpa_supplicant ]]' \
    || fail 'D-Bus/libnl/OpenSSL prerequisites are missing or WPA Supplicant is already installed.'
sudo -n test -r "$LFS/sources/$ARCHIVE" || fail "Missing cached source: $LFS/sources/$ARCHIVE"
mkdir -p "$LOG_DIR" "$DATA/locks"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result() { local rc=$?; if (( rc == 0 )); then printf 'BLFS_WPA_SUPPLICANT_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'BLFS_WPA_SUPPLICANT_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT
printf 'BLFS 12.4 WPA Supplicant %s (D-Bus enabled); no upstream test suite or checksum requested.\n' "$VERSION"
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$ARCHIVE" "$WORK" <<'WPA_BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"
[[ "$(id nobody)" == 'uid=65534(nobody) gid=65534(nogroup) groups=65534(nogroup)' ]]
[[ ! -e "$work" ]] || { printf 'Refusing to overwrite prior work tree: %s\n' "$work" >&2; exit 1; }
install -d -o nobody -g nogroup "$work"
tar -xf "/sources/$archive" -C "$work"
source="$work/wpa_supplicant-2.11"
cd "$source"
printf '%s\n' \
    'CONFIG_BACKEND=file' 'CONFIG_CTRL_IFACE=y' 'CONFIG_DEBUG_FILE=y' \
    'CONFIG_DEBUG_SYSLOG=y' 'CONFIG_DEBUG_SYSLOG_FACILITY=LOG_DAEMON' \
    'CONFIG_DRIVER_NL80211=y' 'CONFIG_DRIVER_WEXT=y' 'CONFIG_DRIVER_WIRED=y' \
    'CONFIG_EAP_GTC=y' 'CONFIG_EAP_LEAP=y' 'CONFIG_EAP_MD5=y' 'CONFIG_EAP_MSCHAPV2=y' \
    'CONFIG_EAP_OTP=y' 'CONFIG_EAP_PEAP=y' 'CONFIG_EAP_TLS=y' 'CONFIG_EAP_TTLS=y' \
    'CONFIG_IEEE8021X_EAPOL=y' 'CONFIG_IPV6=y' 'CONFIG_LIBNL32=y' 'CONFIG_PEERKEY=y' \
    'CONFIG_PKCS12=y' 'CONFIG_READLINE=y' 'CONFIG_SMARTCARD=y' 'CONFIG_WPS=y' \
    'CONFIG_CTRL_IFACE_DBUS=y' 'CONFIG_CTRL_IFACE_DBUS_NEW=y' 'CONFIG_CTRL_IFACE_DBUS_INTRO=y' \
    'CFLAGS += -I/usr/include/libnl3' > wpa_supplicant/.config
chown -R nobody:nogroup "$work"
su -s /bin/bash nobody -c "cd '$source' && make -C wpa_supplicant BINDIR=/usr/sbin LIBDIR=/usr/lib" > "$work/build.log" 2>&1 \
    || { tail -n 100 "$work/build.log"; exit 1; }
cd "$source/wpa_supplicant"
install -v -m755 wpa_cli wpa_passphrase wpa_supplicant /usr/sbin/
install -v -d -m755 /usr/lib/systemd/system /usr/share/dbus-1/system-services /etc/dbus-1/system.d
install -v -m644 systemd/*.service /usr/lib/systemd/system/
install -v -m644 dbus/fi.w1.wpa_supplicant1.service /usr/share/dbus-1/system-services/
install -v -m644 dbus/dbus-wpa_supplicant.conf /etc/dbus-1/system.d/wpa_supplicant.conf
[[ "$(/usr/sbin/wpa_supplicant -v 2>&1 | head -n 1)" == 'wpa_supplicant v2.11' ]]
[[ -x /usr/sbin/wpa_cli && -x /usr/sbin/wpa_passphrase ]]
[[ -f /usr/lib/systemd/system/wpa_supplicant@.service ]]
[[ -f /usr/share/dbus-1/system-services/fi.w1.wpa_supplicant1.service ]]
[[ -f /etc/dbus-1/system.d/wpa_supplicant.conf ]]
printf 'WPA_SUPPLICANT_BUILD_INSTALL=PASS\nWPA_SUPPLICANT_VERSION=2.11\nDBUS_CONTROL=enabled\n'
WPA_BUILD
printf 'BLFS WPA Supplicant %s installed; log: %s\n' "$VERSION" "$LOG"
