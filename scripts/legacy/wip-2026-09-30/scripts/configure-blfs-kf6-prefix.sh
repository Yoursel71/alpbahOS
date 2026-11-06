#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/kf6-prefix-$STAMP.log"
readonly STATUS="$LOG_DIR/kf6-prefix-$STAMP.status"
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" ]] || fail 'The LFS target or HDD build directory is missing.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on ext4."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
sudo -n true || fail 'Non-interactive sudo is unavailable.'
for path in "$LFS/opt/kf6" "$LFS/etc/profile.d/kf6.sh" "$LFS/etc/ld.so.conf.d/kf6.conf"; do
    [[ ! -e "$path" && ! -L "$path" ]] || fail "Refusing to replace an existing KF6 path: $path"
done
[[ -f "$LFS/etc/profile.d/qt6.sh" ]] || fail 'Qt6 profile setup is missing.'

mkdir -p "$LOG_DIR" "$DATA/locks"
exec 9>"$DATA/locks/lfs-build-writer.lock"
flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOG") 2>&1
record_result() {
    local result=$?
    if (( result == 0 )); then
        printf 'BLFS_KF6_PREFIX_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else
        printf 'BLFS_KF6_PREFIX_RESULT=FAIL exit=%s\nLOG=%s\n' "$result" "$LOG" > "$STATUS"
    fi
}
trap record_result EXIT

printf 'Preparing the isolated /opt/kf6 prefix for BLFS 12.4 KDE Frameworks 6.17.0.\n'
printf 'The prefix and its profile/loader files do not already exist.\n'
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -e <<'CHROOT'
install -v -dm755 /opt/kf6/{etc,share,lib}
ln -sfv /etc/dbus-1 /opt/kf6/etc
ln -sfv /usr/share/dbus-1 /opt/kf6/share
ln -sfv /usr/share/polkit-1 /opt/kf6/share
ln -sfv /usr/lib/systemd /opt/kf6/lib
cat > /etc/profile.d/kf6.sh <<'EOF'
# Begin /etc/profile.d/kf6.sh
export KF6_PREFIX=/opt/kf6
PATH="$KF6_PREFIX/bin:$PATH"
PKG_CONFIG_PATH="$KF6_PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
XDG_CONFIG_DIRS="$KF6_PREFIX/etc/xdg${XDG_CONFIG_DIRS:+:$XDG_CONFIG_DIRS}"
XDG_DATA_DIRS="$KF6_PREFIX/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
QT_PLUGIN_PATH="$KF6_PREFIX/lib/plugins:$KF6_PREFIX/lib/plugins/kcms:/opt/qt6/plugins:/usr/lib/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
QML2_IMPORT_PATH="$KF6_PREFIX/lib/qml:/opt/qt6/qml${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
PYTHONPATH="$KF6_PREFIX/lib/python3.13/site-packages${PYTHONPATH:+:$PYTHONPATH}"
CPLUS_INCLUDE_PATH="$KF6_PREFIX/include${CPLUS_INCLUDE_PATH:+:$CPLUS_INCLUDE_PATH}"
GTK_PATH="$KF6_PREFIX/lib/gtk-3.0${GTK_PATH:+:$GTK_PATH}"
export PATH PKG_CONFIG_PATH XDG_CONFIG_DIRS XDG_DATA_DIRS
export QT_PLUGIN_PATH QML2_IMPORT_PATH PYTHONPATH CPLUS_INCLUDE_PATH GTK_PATH
# End /etc/profile.d/kf6.sh
EOF
install -v -d -m755 /etc/ld.so.conf.d
cat > /etc/ld.so.conf.d/kf6.conf <<'EOF'
/opt/kf6/lib
EOF
ldconfig
[[ -d /opt/kf6/etc && -d /opt/kf6/share && -d /opt/kf6/lib ]]
[[ -L /opt/kf6/etc/dbus-1 && -L /opt/kf6/share/dbus-1 && -L /opt/kf6/share/polkit-1 ]]
[[ -L /opt/kf6/lib/systemd ]]
[[ -f /etc/profile.d/kf6.sh && -f /etc/ld.so.conf.d/kf6.conf ]]
printf 'KF6_PREFIX_SETUP=PASS\n'
CHROOT
printf 'KF6 prefix environment and system integration paths are prepared.\n'
printf 'Host log: %s\nStatus: %s\nFinished: %s\n' "$LOG" "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
