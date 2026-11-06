#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$(id -u)" == 0 ]] || fail 'Chapter 7 setup must run as root inside chroot.'
[[ ! -e /usr/lib64 && ! -L /usr/lib64 ]] || fail '/usr/lib64 must not exist in LFS.'

mkdir -pv /{boot,home,mnt,opt,srv}
mkdir -pv /etc/{opt,sysconfig}
mkdir -pv /lib/firmware
mkdir -pv /media/{floppy,cdrom}
mkdir -pv /usr/{,local/}{include,src}
mkdir -pv /usr/lib/locale
mkdir -pv /usr/local/{bin,lib,sbin}
mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
mkdir -pv /usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -pv /usr/{,local/}share/man/man{1..8}
mkdir -pv /var/{cache,local,log,mail,opt,spool}
mkdir -pv /var/lib/{color,misc,locate}

for pair in '/var/run:/run' '/var/lock:/run/lock'; do
    path="${pair%%:*}"
    target="${pair#*:}"
    if [[ -e "$path" || -L "$path" ]]; then
        [[ -L "$path" && "$(readlink "$path")" == "$target" ]] || fail "Refusing to replace unexpected path $path"
    else
        ln -sv "$target" "$path"
    fi
done

install -dv -m 0750 /root
install -dv -m 1777 /tmp /var/tmp

if [[ -e /etc/mtab || -L /etc/mtab ]]; then
    [[ -L /etc/mtab && "$(readlink /etc/mtab)" == /proc/self/mounts ]] || fail 'Refusing to replace unexpected /etc/mtab.'
else
    ln -sv /proc/self/mounts /etc/mtab
fi

if [[ ! -e /etc/hosts ]]; then
    cat > /etc/hosts <<'EOF'
127.0.0.1  localhost alpbahos
::1        localhost
EOF
fi

if [[ ! -e /etc/passwd ]]; then
    cat > /etc/passwd <<'EOF'
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/usr/bin/false
daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/usr/bin/false
systemd-journal-gateway:x:73:73:systemd Journal Gateway:/:/usr/bin/false
systemd-journal-remote:x:74:74:systemd Journal Remote:/:/usr/bin/false
systemd-journal-upload:x:75:75:systemd Journal Upload:/:/usr/bin/false
systemd-network:x:76:76:systemd Network Management:/:/usr/bin/false
systemd-resolve:x:77:77:systemd Resolver:/:/usr/bin/false
systemd-timesync:x:78:78:systemd Time Synchronization:/:/usr/bin/false
systemd-coredump:x:79:79:systemd Core Dumper:/:/usr/bin/false
uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/usr/bin/false
systemd-oom:x:81:81:systemd Out Of Memory Daemon:/:/usr/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
tester:x:101:101::/home/tester:/bin/bash
EOF
fi

if [[ ! -e /etc/group ]]; then
    cat > /etc/group <<'EOF'
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
systemd-journal:x:23:
input:x:24:
mail:x:34:
kvm:x:61:
systemd-journal-gateway:x:73:
systemd-journal-remote:x:74:
systemd-journal-upload:x:75:
systemd-network:x:76:
systemd-resolve:x:77:
systemd-timesync:x:78:
systemd-coredump:x:79:
uuidd:x:80:
systemd-oom:x:81:
wheel:x:97:
users:x:999:
nogroup:x:65534:
tester:x:101:
EOF
fi

getent passwd tester >/dev/null || fail 'The LFS tester account is missing.'
getent group utmp >/dev/null || fail 'The LFS utmp group is missing.'
install -o tester -d /home/tester

touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp utmp /var/log/lastlog
chmod 664 /var/log/lastlog
chmod 600 /var/log/btmp

printf 'Created LFS Chapter 7 directory tree and essential files.\n'
