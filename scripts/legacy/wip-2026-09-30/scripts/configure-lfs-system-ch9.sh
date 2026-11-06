#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="$LOG_DIR/system-config-ch9-$STAMP.log"
readonly STATUS="$LOG_DIR/system-config-ch9-$STAMP.status"
readonly STAGE="$DATA/staging/system-config-ch9-$STAMP"
readonly MANIFEST="$DATA/staging/system-config-ch9-$STAMP.files.list0"
readonly PREEXISTING="$DATA/backups/system-config-ch9-before-$STAMP/files.list0"
readonly BACKUP="$DATA/backups/system-config-ch9-before-$STAMP/files.tar"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" ]] || fail 'The LFS target or HDD build directory is missing.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on ext4."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
[[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'

mkdir -p "$LOG_DIR" "$DATA/locks" "$(dirname "$PREEXISTING")" "$STAGE/etc/systemd/network"
exec 9>"$DATA/locks/lfs-build-writer.lock"
flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOG") 2>&1

record_result() {
    local result=$?
    if (( result == 0 )); then
        printf 'LFS_SYSTEM_CONFIG_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else
        printf 'LFS_SYSTEM_CONFIG_RESULT=FAIL exit=%s\nLOG=%s\n' "$result" "$LOG" > "$STATUS"
    fi
}
trap record_result EXIT

printf 'Configuring standard LFS Chapter 9 first-boot defaults.\n'
printf 'Turkish Q, tr_TR.UTF-8, Europe/Istanbul, generic wired DHCP.\nStarted: %s\n\n' \
    "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

cat > "$STAGE/etc/hostname" <<'EOF'
alpbahos
EOF
cat > "$STAGE/etc/hosts" <<'EOF'
# Begin /etc/hosts
127.0.0.1 localhost alpbahos.localdomain alpbahos
::1       localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters
# End /etc/hosts
EOF
cat > "$STAGE/etc/locale.conf" <<'EOF'
LANG=tr_TR.UTF-8
EOF
cat > "$STAGE/etc/profile" <<'EOF'
# Begin /etc/profile

for i in $(locale); do
  unset ${i%=*}
done

if [[ "$TERM" = linux ]]; then
  export LANG=C.UTF-8
else
  source /etc/locale.conf

  for i in $(locale); do
    key=${i%=*}
    if [[ -v $key ]]; then
      export $key
    fi
  done
fi

# End /etc/profile
EOF
cat > "$STAGE/etc/vconsole.conf" <<'EOF'
KEYMAP=trq
FONT=Lat2-Terminus16
EOF
cat > "$STAGE/etc/adjtime" <<'EOF'
0.0 0 0.0
0
UTC
EOF
cat > "$STAGE/etc/inputrc" <<'EOF'
# Begin /etc/inputrc

set horizontal-scroll-mode Off
set meta-flag On
set input-meta On
set convert-meta Off
set output-meta On
set bell-style none

"\eOd": backward-word
"\eOc": forward-word
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": beginning-of-history
"\e[6~": end-of-history
"\e[3~": delete-char
"\e[2~": quoted-insert
"\eOH": beginning-of-line
"\eOF": end-of-line
"\e[H": beginning-of-line
"\e[F": end-of-line

# End /etc/inputrc
EOF
cat > "$STAGE/etc/shells" <<'EOF'
# Begin /etc/shells
/bin/sh
/bin/bash
# End /etc/shells
EOF
cat > "$STAGE/etc/systemd/network/10-ethernet-dhcp.network" <<'EOF'
[Match]
Name=en* eth*

[Network]
DHCP=yes
EOF

find "$STAGE" -type f -printf '%P\0' | sort -z > "$MANIFEST"
python3 - "$LFS" "$MANIFEST" "$PREEXISTING" <<'PY'
import os
import sys

root, staged_path, output_path = sys.argv[1:]
with open(staged_path, "rb") as stream:
    staged = [path for path in stream.read().split(b"\0") if path]
existing = []
for path in staged:
    relative = os.fsdecode(path)
    target = os.path.join(root, relative)
    if os.path.lexists(target):
        existing.append(path)
with open(output_path, "wb") as stream:
    for path in existing:
        stream.write(path + b"\0")
print(f"Configuration files staged: {len(staged)}; prior paths to archive: {len(existing)}")
PY

if [[ -s "$PREEXISTING" ]]; then
    sudo -n tar --create --file="$BACKUP" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$PREEXISTING"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP"
    tar --list --file="$BACKUP" > "${BACKUP%.tar}.list"
    printf 'Existing config backup: %s bytes\n' "$(stat -c '%s' "$BACKUP")"
else
    printf 'No replaced configuration paths required a backup.\n'
fi

while IFS= read -r -d '' relative; do
    sudo -n install -D -o 0 -g 0 -m 0644 "$STAGE/$relative" "$LFS/$relative"
done < "$MANIFEST"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -s <<'VERIFY'
set -Eeuo pipefail
[[ "$(cat /etc/hostname)" == alpbahos ]]
grep -Fxq '127.0.0.1 localhost alpbahos.localdomain alpbahos' /etc/hosts
grep -Fxq 'LANG=tr_TR.UTF-8' /etc/locale.conf
[[ "$(LC_ALL=tr_TR.utf8 locale charmap)" == UTF-8 ]]
[[ "$(LC_ALL=tr_TR.utf8 locale language)" == Turkish ]]
for term in xterm linux; do
  value=$(TERM="$term" /usr/bin/env -i HOME=/root TERM="$term" PATH=/usr/bin:/usr/sbin /bin/bash --login -c 'printf "%s" "$LANG"')
  if [[ "$term" == linux ]]; then [[ "$value" == C.UTF-8 ]]; else [[ "$value" == tr_TR.UTF-8 ]]; fi
done
[[ -L /etc/localtime && /etc/localtime -ef /usr/share/zoneinfo/Europe/Istanbul ]]
grep -Fxq 'KEYMAP=trq' /etc/vconsole.conf
grep -Fxq 'FONT=Lat2-Terminus16' /etc/vconsole.conf
[[ -f /usr/share/keymaps/i386/qwerty/trq.map.gz ]]
[[ -f /usr/share/consolefonts/Lat2-Terminus16.psfu.gz ]]
grep -Fxq 'UTC' /etc/adjtime
grep -Fxq '/bin/sh' /etc/shells
grep -Fxq '/bin/bash' /etc/shells
grep -Fxq 'Name=en* eth*' /etc/systemd/network/10-ethernet-dhcp.network
grep -Fxq 'DHCP=yes' /etc/systemd/network/10-ethernet-dhcp.network
[[ -L /etc/systemd/system/multi-user.target.wants/systemd-networkd.service ]]
[[ -L /etc/systemd/system/sysinit.target.wants/systemd-resolved.service ]]
printf 'LFS_SYSTEM_CONFIG=PASS\nLOCALE=tr_TR.UTF-8\nCONSOLE_KEYMAP=trq\nTIMEZONE=Europe/Istanbul\nBOOT_NETWORK=systemd-networkd_DHCP\n'
VERIFY

printf '\nConfiguration files: %s\n' "$STAGE"
printf 'Pre-change backup manifest: %s\n' "$PREEXISTING"
printf 'Status: %s\nFinished: %s\n' "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
