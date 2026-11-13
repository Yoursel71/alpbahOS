#!/bin/bash
# PRINT-02 two-guest row (round 48): does `lpinfo --include-schemes dnssd -v` list a network printer when the
# printer is on ANOTHER machine? The one-guest PRINT row runs ippeveprinter and lpinfo on the same guest and lpinfo
# stays empty (handoff 044: CUPS' dnssd backend may skip services of its own host). Here two reflink copies of the
# round 48 UEFI install share a private LAN (QEMU socket netdev on a multicast group, no DHCP, static 10.77.0.0/24
# plus IPv6 link-local), each keeping its own user-mode NIC. P2A runs ippeveprinter (the "network printer"); P2B is
# the alpbahOS user: avahi-browse, ippfind, lpinfo dnssd, cups-browsed's automatic queue, a manual IPP Everywhere
# queue and one printed PDF. On P2A the test opens tcp/8631 in the firewall (a real printer is its own box; the
# alpbahOS client needs only mDNS in and IPP out). The same lpinfo on P2A itself is the one-host comparison.
# Usage: print2-r48.sh   Evidence: scratch-lfs-bench/lfs13-logs/iso-beta-0.9/r48p/matrix/{P2A,P2B,print2.out}
set -u
B=/home/yrslf/alpbahOS/scratch-lfs-bench
export MATRIX_LIB=1 MROUND=r48p IMGU_PATH=$B/images/inst-uefi-gpt-r48.raw ISO_PATH=$B/images/alpbahos-beta-0.9-2026-11-09-r48.iso
[ -e "$B/test-secrets/r48p.pw" ] || (umask 077; cp "$B/test-secrets/r21.pw" "$B/test-secrets/r48p.pw")
. /home/yrslf/alpbahOS/wt-t2-kisayol/scripts/rebuild/r21/matrix-r21.sh
[ "$(pgrep -c qemu-system)" -eq 0 ] || { echo "another QEMU is running, not starting two guests"; exit 1; }
LAN="-netdev socket,id=lan,mcast=230.0.0.77:12377"
wait_shell() { local i; for i in $(seq 1 120); do grep -aq "R21M begin" "$1/serial.log" 2> /dev/null && return 0; sleep 2; done; echo "no test shell in $1"; return 1; }
lan_up() { # run-dir mac address
  gsh "$1" 40 "IF=\$(ip -o link | grep -i '$2' | cut -d: -f2 | tr -d ' '); echo \"lan if: \$IF\"; nmcli -w 20 con add type ethernet ifname \$IF con-name lan ipv4.method manual ipv4.addresses $3 ipv6.method link-local > /dev/null && nmcli -w 20 con up lan > /dev/null; sleep 3; ip -br addr show \$IF"; }
stamp "PRINT2 start"
for n in P2A P2B; do cmd_mkcopy uefi "$n-disk" > /dev/null; done
EXTRA_ARGS="$LAN -device virtio-net-pci,netdev=lan,mac=52:54:00:77:00:0a" agent_start P2A uefi P2A-disk virtio 4G
EXTRA_ARGS="$LAN -device virtio-net-pci,netdev=lan,mac=52:54:00:77:00:0b" agent_start P2B uefi P2B-disk virtio 4G
A=$D/P2A; C=$D/P2B
wait_shell "$A" && wait_shell "$C" || { vmquit "$A"; vmquit "$C"; exit 1; }
sleep 30
echo "== P2A (printer)"; lan_up "$A" 52:54:00:77:00:0a 10.77.0.1/24
echo "== P2B (client)"; lan_up "$C" 52:54:00:77:00:0b 10.77.0.2/24
gsh "$C" 15 'echo "ping printer: $(ping -c 2 -W 2 10.77.0.1 > /dev/null && echo ok || echo no)"; for u in avahi-daemon cups cups-browsed alpbahos-firewall; do echo "$u: $(systemctl is-active $u)"; done'
gsh "$A" 20 'hostnamectl set-hostname alpbah-printer; systemctl restart avahi-daemon; sleep 3; echo "printer hostname: $(hostname)"'
gsh "$A" 25 'iptables -I INPUT -p tcp --dport 8631 -j ACCEPT; ip6tables -I INPUT -p tcp --dport 8631 -j ACCEPT; mkdir -p /root/ipp && nohup ippeveprinter -d /root/ipp -k -p 8631 -f application/pdf,image/pwg-raster "alpbah LAN Printer" > /root/ipp-eve.log 2>&1 & sleep 12; echo "ippeveprinter: $(pgrep -c -x ippeveprinter)"'
sleep 20
echo "== P2B discovery"
gsh "$C" 90 'echo "avahi-browse: $(avahi-browse -rtp _ipp._tcp 2>/dev/null | grep "^=" | cut -d";" -f2-8 | tr "\n" " ")"; echo "ippfind: $(timeout 25 ippfind -T 15 _ipp._tcp 2>/dev/null | tr "\n" " ")"; echo "getent printer host: $(getent hosts "$(avahi-browse -rtp _ipp._tcp 2>/dev/null | grep "^=" | head -n 1 | cut -d";" -f7)" | head -n 1)"; echo "lpinfo dnssd (P2B):"; timeout 60 lpinfo --include-schemes dnssd -v 2>&1 | head -n 5'
echo "== P2B what print dialogs see (CUPS temporary queues) and the _printer record"
gsh "$C" 60 'echo "lpstat -e: $(timeout 30 lpstat -e 2>&1 | tr "\n" " ")"; echo "lpstat -l -e:"; timeout 30 lpstat -l -e 2>&1 | head -n 4; echo "_printer._tcp: $(avahi-browse -rtp _printer._tcp 2>/dev/null | grep "^=" | cut -d";" -f4,8,9 | tr "\n" " ")"; echo "lpinfo -l dnssd:"; timeout 60 lpinfo -l --include-schemes dnssd -v 2>&1 | head -n 8'
echo "== P2A one-host comparison"
gsh "$A" 75 'echo "lpinfo dnssd (P2A, same host as the printer):"; timeout 60 lpinfo --include-schemes dnssd -v 2>&1 | head -n 5'
echo "== P2B cups-browsed automatic queue (after 90 s)"; sleep 90
gsh "$C" 20 'lpstat -v 2>&1 | head -n 5; echo "--- cups-browsed journal:"; journalctl -b -u cups-browsed --no-pager -q | tail -n 12; grep -vE "^[[:space:]]*(#|\$)" /etc/cups/cups-browsed.conf'
echo "== P2B manual queue from the dnssd URI, one PDF"
gsh "$C" 150 'U=$(timeout 60 lpinfo --include-schemes dnssd -v 2>/dev/null | awk "/alpbah.*_ipp/ {print \$2; exit}"); [ -n "$U" ] || U=ipp://10.77.0.1:8631/ipp/print; echo "uri: $U"; gs -q -sDEVICE=pdfwrite -o /root/t.pdf -c "/Helvetica findfont 24 scalefont setfont 72 700 moveto (alpbahOS PRINT-02 LAN) show showpage" && lpadmin -p lanprinter -E -v "$U" -m everywhere && echo "queue: $(lpstat -p lanprinter | head -n 1)"; lp -d lanprinter /root/t.pdf; sleep 40; echo "completed jobs: $(lpstat -W completed -o lanprinter | wc -l)"'
echo "== P2B print to the CUPS temporary queue (what an application's print dialog uses), no lpadmin"
gsh "$C" 90 'T=$(timeout 30 lpstat -e 2>/dev/null | grep -i alpbah | head -n 1); echo "temporary queue: $T"; [ -n "$T" ] && lp -d "$T" /root/t.pdf; sleep 40; echo "completed jobs on $T: $(lpstat -W completed -o "$T" 2>/dev/null | wc -l)"'
gsh "$A" 15 'echo "received by the printer: $(find /root/ipp -type f | sed "s|/root/ipp/||" | tr "\n" " ")"; tail -n 3 /root/ipp-eve.log'
for r in "$A" "$C"; do gsh "$r" 15 'echo "$(hostname): failed units: $(systemctl --failed --no-legend | tr -s " " | tr "\n" ";"), coredumps $(ls /var/lib/systemd/coredump 2>/dev/null | wc -l)"'; done
vmquit "$A"; vmquit "$C"; rm -f "$D/P2A-disk.raw" "$D/P2B-disk.raw"
stamp "PRINT2 end (copies removed)"
