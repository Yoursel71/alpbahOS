#!/bin/bash
# KUTU diagnosis: why distrobox init fails ("Installing basic packages... Error") in a test copy of the rc02 UEFI install
cd /home/yrslf/alpbahOS/scratch-lfs-bench/lfs13-logs/iso-beta-0.9/rc02/matrix || exit 1
. /home/yrslf/alpbahOS/wt-rc02/scripts/rebuild/rc02/env-rc02.sh; RBD=$MATRIX_WT/scripts/rebuild; MM=$M; MATRIX_LIB=1 . "$MM"
gs() { python3 "$RBD/r21/gsh.py" "$D/KUTUD" "$@"; }
gate 20 || exit 1
bash "$MM" mkcopy uefi KUTUD-disk
agent_start KUTUD uefi KUTUD-disk virtio 6G; greeter_login "$D/KUTUD" kutud
{
gs 900 'r21m-as-user distrobox create -i docker.io/library/debian:13 --name deb --yes > /tmp/c.log 2>&1; echo create rc=$?; r21m-as-user distrobox enter deb -- true > /tmp/e.log 2>&1; echo enter rc=$?; tail -n 5 /tmp/e.log'
gs 60 'r21m-as-user podman logs deb 2>&1 | tail -n 80'
gs 60 'r21m-as-user podman inspect deb --format "{{.State.ExitCode}} {{.State.Error}} net={{.HostConfig.NetworkMode}} userns={{.HostConfig.UsernsMode}}"; r21m-as-user podman info 2>&1 | grep -iE "rootless|networkBackend|pasta|slirp|cgroup|ociRuntime|name: crun|idMappings" | head -20; grep testuser /etc/subuid /etc/subgid; ls -l /usr/bin/newuidmap /usr/bin/newgidmap'
gs 120 'r21m-as-user podman run --rm docker.io/library/debian:13 sh -c "id; apt-get update 2>&1 | tail -n 3" 2>&1 | tail -n 8; echo run rc=$?'
gs 30 'journalctl -b --no-pager -p warning | tail -n 30'
} > KUTUD-diag.txt 2>&1
shot "$D/KUTUD" kutud-end; vmquit "$D/KUTUD" && rm -f "$D/KUTUD-disk.raw"
echo KUTUD-DONE >> KUTUD-diag.txt
