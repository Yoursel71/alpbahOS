#!/bin/bash
# BETA-RC-02 KUTU row, guest side: runs as root in a test copy of the rc02 install while testuser's session is up
# (r21m-as-user runs a command as testuser with the session environment). /root/.kutu-pw (mode 600) is put into the
# copy offline by the host; it is never printed and is removed at the end.
# Usage: kutu-guest-rc02.sh pre|create|sudo|plain|end
U() { r21m-as-user "$@"; }
case "$1" in
  pre)
    ls -l /usr/libexec/podman
    /usr/libexec/podman/netavark --version; /usr/libexec/podman/aardvark-dns --version
    alp list 2>/dev/null | grep -E "^(netavark|aardvark|protobuf|podman|distrobox|passt)" ;;
  create)
    U distrobox create -i docker.io/library/debian:13 --name deb --yes > /tmp/k-create.log 2>&1
    echo "testuser distrobox create -i docker.io/library/debian:13 --name deb: rc=$?"; tail -n 6 /tmp/k-create.log
    U distrobox enter deb -- true; echo "testuser distrobox enter deb -- true: rc=$?"
    U distrobox enter deb -- sh -c 'head -n 1 /etc/os-release; id -un' 2>&1 | tail -n 3
    U podman info --format 'network backend: {{.Host.NetworkBackend}} {{.Host.NetworkBackendInfo.Version}}' 2>&1 | tail -n 2
    U podman ps -a --format '{{.Names}} {{.Image}} {{.Status}}' ;;
  sudo)
    install -m 600 -o testuser -g testuser /root/.kutu-pw /home/testuser/.kutu-pw
    U sh -c 'sudo -S -p "" alp install -y htop < "$HOME/.kutu-pw"' > /tmp/k-sudo.log 2>&1
    echo "testuser: sudo alp install -y htop: rc=$?"
    rm -f /home/testuser/.kutu-pw
    tail -n 30 /tmp/k-sudo.log
    echo "-- htop for testuser after the install"
    U sh -c 'ls -l "$HOME/.local/bin/htop"; "$HOME/.local/bin/htop" --version; echo "htop --version rc=$?"' 2>&1
    U sh -c 'TERM=xterm-256color timeout 5 script -qec "$HOME/.local/bin/htop -d 10" /dev/null > /tmp/k-htop-run.out 2>&1; echo "htop run (5 s, killed by timeout): rc=$?, $(wc -c < /tmp/k-htop-run.out) bytes of screen output, CPU line: $(grep -ac "Mem\[" /tmp/k-htop-run.out)"' 2>&1
    U sh -c 'cat "$HOME/.local/share/alp/kutu.json"'
    U podman ps -a --format '{{.Names}} {{.Image}} {{.Status}}'
    echo "-- base system untouched: /usr/bin/htop $(ls /usr/bin/htop 2>&1 | tail -n 1); alp db htop: $(alp list 2>/dev/null | grep -c '^htop')" ;;
  plain)
    U alp install -y htop > /tmp/k-plain.log 2>&1; echo "testuser (no sudo): alp install -y htop: rc=$?"; tail -n 15 /tmp/k-plain.log ;;
  end)
    rm -f /root/.kutu-pw
    echo "failed units: $(systemctl --failed --no-legend | wc -l), coredumps: $(ls /var/lib/systemd/coredump 2>/dev/null | wc -l)"
    systemctl --failed --no-legend ;;
  *) echo "usage: kutu-guest-rc02.sh pre|create|sudo|plain|end"; exit 2 ;;
esac
