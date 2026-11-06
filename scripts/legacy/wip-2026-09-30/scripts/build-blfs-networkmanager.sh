#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
readonly VERSION=1.54.0
readonly ARCHIVE="NetworkManager-$VERSION.tar.xz"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/NetworkManager-$VERSION-alpbahOS-$STAMP"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/NetworkManager-$VERSION-$STAMP.log"
readonly STATUS="$LOG_DIR/NetworkManager-$VERSION-$STAMP.status"
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run the host orchestrator as the regular Fedora user.'
[[ -d "$LFS" ]] || fail 'The LFS target is missing.'
lfs_validate_target "$LFS" "$DATA"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "meson" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -c \
    '[[ -x /usr/bin/meson && -x /usr/bin/ninja && -f /usr/include/ndp.h && -f /usr/include/nss/nss.h && -f /usr/lib/pkgconfig/nss.pc && ! -e /usr/lib/libnm.so ]]' \
    || fail 'Build tools/network/TLS prerequisites are missing or NetworkManager is already installed.'
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -c \
    '[[ -f /usr/share/dbus-1/system-services/fi.w1.wpa_supplicant1.service && -f /usr/lib/systemd/system/wpa_supplicant@.service && -f /usr/lib/pkcs11/p11-kit-trust.so ]]' \
    || fail 'WPA Supplicant or p11-kit trust prerequisites are missing.'
sudo -n test -r "$LFS/sources/$ARCHIVE" || fail "Missing cached source: $LFS/sources/$ARCHIVE"
mkdir -p "$LOG_DIR" "$DATA/locks"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result() { local rc=$?; if (( rc == 0 )); then printf 'BLFS_NETWORKMANAGER_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'BLFS_NETWORKMANAGER_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT
printf 'BLFS 12.4 NetworkManager %s; NSS crypto, tests/docs disabled, nmtui disabled (newt not included), no checksum.\n' "$VERSION"
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$ARCHIVE" "$WORK" <<'NM_BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"
[[ "$(id nobody)" == 'uid=65534(nobody) gid=65534(nogroup) groups=65534(nogroup)' ]]
[[ ! -e "$work" ]] || { printf 'Refusing to overwrite prior work tree: %s\n' "$work" >&2; exit 1; }
install -d -o nobody -g nogroup "$work"
tar -xf "/sources/$archive" -C "$work"
source="$work/NetworkManager-1.54.0"
chown -R nobody:nogroup "$work"
su -s /bin/bash nobody -c "env HOME=/tmp TERM=dumb PATH=/usr/bin:/usr/sbin NM_WORK='$work' /bin/bash -s" <<'UNPRIVILEGED_BUILD'
set -Eeuo pipefail
cd "$NM_WORK/NetworkManager-1.54.0"
grep -rl '^#!.*python$' | xargs -r sed -i '1s/python/&3/'
meson setup build . \
  --prefix=/usr --libdir=lib --sysconfdir=/etc --localstatedir=/var --buildtype=release \
  -D crypto=nss -D docs=false -D introspection=false -D libaudit=no -D nmtui=false \
  -D ovs=false -D ppp=false -D nbft=false -D selinux=false -D qt=false \
  -D session_tracking=systemd -D nm_cloud_setup=false -D modem_manager=false \
  -D system_ca_path=/etc/ssl/certs -D tests=no > "$NM_WORK/meson-setup.log" 2>&1 \
  || { tail -n 100 "$NM_WORK/meson-setup.log"; exit 1; }
ninja -C build -j4 > "$NM_WORK/ninja-build.log" 2>&1 \
  || { tail -n 120 "$NM_WORK/ninja-build.log"; exit 1; }
DESTDIR="$NM_WORK/stage" ninja -C build install > "$NM_WORK/ninja-install.log" 2>&1 \
  || { tail -n 100 "$NM_WORK/ninja-install.log"; exit 1; }
UNPRIVILEGED_BUILD
chown -R 0:0 "$work/stage"
cp -a "$work/stage"/. /
install -v -d -m755 /etc/NetworkManager/conf.d /etc/polkit-1/rules.d /usr/share/man/man5 /usr/share/man/man8
cat > /etc/NetworkManager/NetworkManager.conf <<'NMCONF'
[main]
plugins=keyfile
NMCONF
cat > /etc/NetworkManager/conf.d/polkit.conf <<'POLKITCONF'
[main]
auth-polkit=true
POLKITCONF
if ! getent group netdev >/dev/null; then groupadd -fg 86 netdev; fi
cat > /etc/polkit-1/rules.d/50-networkmanager-netdev.rules <<'POLKITRULE'
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.freedesktop.NetworkManager.") === 0 && subject.isInGroup("netdev")) {
        return polkit.Result.YES;
    }
});
POLKITRULE
cd "$source"
for file in man/*.[1578]; do [[ -f "$file" ]] || continue; section="${file##*.}"; install -m644 "$file" "/usr/share/man/man$section/"; done
ldconfig
[[ "$(NetworkManager --version)" == 1.54.0 ]]
[[ "$(nmcli --version)" == 'nmcli tool, version 1.54.0' ]]
[[ -f /usr/lib/systemd/system/NetworkManager.service && -f /usr/lib/systemd/system/NetworkManager-wait-online.service ]]
[[ -f /usr/lib/NetworkManager/1.54.0/libnm-device-plugin-wifi.so ]]
[[ -f /etc/NetworkManager/NetworkManager.conf && -f /etc/NetworkManager/conf.d/polkit.conf ]]
systemctl --root=/ enable NetworkManager.service
printf 'BLFS_NETWORKMANAGER_BUILD_INSTALL=PASS\nNETWORKMANAGER_VERSION=1.54.0\nCRYPTO=NSS\nWIFI_BACKEND=wpa_supplicant-dbus\n'
NM_BUILD
printf 'BLFS NetworkManager %s installed; log: %s\n' "$VERSION" "$LOG"
