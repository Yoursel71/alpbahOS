#!/bin/bash
# PRINT-01 step 2 (round 44): network printers. Step 1 (print01-chain.sh) gave CUPS its filters; the image still had
# no Avahi, CUPS was built without DNS-SD and the firewall dropped mDNS, so network printers were never discovered.
# Records (pkg-url-r11.sh, rows 457-461):
#   libdaemon 0.14, avahi 0.9-rc5 (+ the book's patch): BLFS 13.1-systemd pages, book MD5 checked;
#   nss-mdns 0.15.1 (not in BLFS 13.1): upstream release, sha256 = Arch PKGBUILD, sha512 = Fedora `sources`;
#   cups-dnssd 2.4.19: BLFS 13.1 CUPS again with --with-dnssd=avahi, taking the files of the base `cups` record over
#     (KEEP_SHARED=0 REPLACE=1, like mesa-glvnd); refused when an /etc/cups file changed after the base record;
#   cups-browsed 2.1.1: BLFS 13.1 page.
# Then: the avahi user from the record's sysusers.d file (systemd-sysusers --root), record alpbahos-mdns-r44 (REPLACE=1:
# /etc/nsswitch.conf from glibc with mdns4_minimal on the hosts line; the firewall rule files of
# scripts/rebuild/r21/product-r21.py with the mDNS rule, D176) and avahi-daemon/cups-browsed enabled (state, no record).
# A read-only snapshot r4-snapshots/r4-before-print02 is taken first. Run as root. Env NICE (default 15), JOBS (10).
# Usage: print02-chain.sh [NAME ...] (default: all; names: libdaemon avahi nss-mdns cups browsed mdns enable)
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=$SB/r4-root
A=$WT/scripts/rebuild/print02/chroot
SRC=$SB/apps01-src
export NICE=${NICE:-15} JOBS=${JOBS:-10} DROP_SRC=1
mkdir -p "$SB/r10/dl" "$SB/r4-snapshots"
[ -e "$SB/r4-snapshots/r4-before-print02" ] || btrfs subvolume snapshot -r "$R4" "$SB/r4-snapshots/r4-before-print02" > /dev/null
link() { local d=$SB/r10/dl/$(basename "$1"); [ -e "$d" ] || ln "$1" "$d"; cmp -s "$1" "$d" || { echo "$d differs from $1"; exit 1; }; }
md5() { [ "$(md5sum < "$1" | cut -c1-32)" = "$2" ] || { echo "MD5 mismatch: $1"; exit 1; }; }
sha() { [ "$(sha"$1"sum < "$2" | cut -d' ' -f1)" = "$3" ] || { echo "sha$1 mismatch: $2"; exit 1; }; }
ARGS=("$@")
w() { [ ${#ARGS[@]} -eq 0 ] && return 0; local x; for x in "${ARGS[@]}"; do [ "$x" = "$1" ] && return 0; done; return 1; }
step() {  # NAME VER URL TARBALL_PATH NN NOTE SCRIPT [extra files...]
    local n=$1 v=$2 u=$3 t=$4 nn=$5 note=$6 s=$7; shift 7
    link "$t"
    echo "== $n-$v ($(date +%T))"
    EXTRA_FILES="$s $*" CUSTOM_CMD="sh ../$(basename "$s")" \
      bash "$WT/scripts/rebuild/r11/pkg-url-r11.sh" "$n" "$v" "$u" "$(basename "$t")" custom - "$nn" "$note"
}
B=https://www.linuxfromscratch.org/blfs/view/13.1-systemd
G=https://github.com/OpenPrinting

if w libdaemon; then
  md5 "$SRC/libdaemon-0.14.tar.gz" 509dc27107c21bcd9fbf2f95f5669563
  step libdaemon 0.14 https://0pointer.de/lennart/projects/libdaemon/libdaemon-0.14.tar.gz "$SRC/libdaemon-0.14.tar.gz" 457 \
    "PRINT-01: BLFS 13.1-systemd general/libdaemon.html: 0.14, book MD5 509dc27107c21bcd9fbf2f95f5669563 matches" "$A/libdaemon.sh"
fi
if w avahi; then
  md5 "$SRC/avahi-0.9-rc5.tar.gz" d2b4bd13a4dba40a7b56c3da8bf50fd2
  sha 256 "$SRC/avahi-0.9-rc5-ipv6_race_condition_fix-1.patch" 218c909581d0ca2c86c8145bb0797050d987a6b0ae3417949dbe2a6d55c49360
  step avahi 0.9-rc5 https://github.com/lathiat/avahi/archive/v0.9-rc5/avahi-0.9-rc5.tar.gz "$SRC/avahi-0.9-rc5.tar.gz" 458 \
    "PRINT-01: BLFS 13.1-systemd basicnet/avahi.html: 0.9-rc5, book MD5 d2b4bd13a4dba40a7b56c3da8bf50fd2 matches; patch ipv6_race_condition_fix-1 sha256 218c9095..." \
    "$A/avahi.sh" "$SRC/avahi-0.9-rc5-ipv6_race_condition_fix-1.patch"
  [ -f "$R4/usr/lib/sysusers.d/avahi.conf" ] || { echo "avahi.conf not in r4-root"; exit 1; }
  grep -q '^avahi:' "$R4/etc/passwd" || systemd-sysusers --root="$R4" avahi.conf
  [ "$(awk -F: '$1=="avahi"{print $3":"$4}' "$R4/etc/passwd")" = 84:84 ] || { echo "avahi user is not 84:84"; exit 1; }
  grep -q '^avahi:!' "$R4/etc/shadow" || { echo "avahi password is not locked"; exit 1; }
fi
if w nss-mdns; then
  T=$SRC/print02/nss-mdns-0.15.1.tar.gz
  sha 256 "$T" ddf71453d7a7cdc5921fe53ef387b24fd0c3c49f4dcf94a2a437498596761a21
  sha 512 "$T" 11a82ae9f209326b4501c7e6d33c9932b370c4dcacb64d6783140e25688ad6391bbd113e51ee470fd8be12669124eac331593cfd02a040383b4f964ed6ec6154
  step nss-mdns 0.15.1 https://github.com/avahi/nss-mdns/releases/download/v0.15.1/nss-mdns-0.15.1.tar.gz "$T" 459 \
    "PRINT-01: upstream release v0.15.1 (not in BLFS 13.1); sha256 ddf71453... = Arch PKGBUILD, sha512 11a82ae9... = Fedora sources" "$A/nss-mdns.sh"
fi
if w cups; then
  T=$SB/blfs-src-13.1/cups-2.4.19-source.tar.gz
  md5 "$T" 06b7a3921812988cdb3198ff74ae381d
  # The base record's /etc/cups files must be unchanged since it was captured (no config hashes in base records, so
  # by mtime); the rebuild installs the defaults again. Diff against the snapshot afterwards: print02 log.
  python3 - "$R4" << 'EOF'
import json, os, sys
from datetime import datetime
root = sys.argv[1]
p = json.load(open(f"{root}/var/lib/alp/db.json"))["packages"]["cups"]
cap = datetime.fromisoformat(p["ownership"]["captured_at"]).timestamp()
bad = [f for f in p["files"] if f.startswith("etc/cups/") and os.path.isfile(f"{root}/{f}")
       and os.lstat(f"{root}/{f}").st_mtime > cap + 60]
print("cups config files changed since the base record:", bad or "none")
sys.exit(1 if bad else 0)
EOF
  export KEEP_SHARED=0 REPLACE=1
  step cups-dnssd 2.4.19 https://github.com/OpenPrinting/cups/releases/download/v2.4.19/cups-2.4.19-source.tar.gz "$T" 460 \
    "PRINT-01: BLFS 13.1-systemd pst/cups.html: 2.4.19, book MD5 06b7a3921812988cdb3198ff74ae381d matches; --with-dnssd=avahi, takes the base cups files over" "$A/cups.sh"
  unset KEEP_SHARED REPLACE
  for f in cupsd.conf cups-files.conf snmp.conf; do
    diff -u "$SB/r4-snapshots/r4-before-print02/etc/cups/$f" "$R4/etc/cups/$f" && echo "unchanged: /etc/cups/$f" || true
  done
fi
if w browsed; then
  md5 "$SRC/cups-browsed-2.1.1.tar.xz" 293948973ebfc7ef4d5d8242d5733181
  step cups-browsed 2.1.1 $G/cups-browsed/releases/download/2.1.1/cups-browsed-2.1.1.tar.xz "$SRC/cups-browsed-2.1.1.tar.xz" 461 \
    "PRINT-01: BLFS 13.1-systemd pst/cups-browsed.html: 2.1.1, book MD5 293948973ebfc7ef4d5d8242d5733181 matches" "$A/cups-browsed.sh"
fi
if w mdns; then
  ST=$SB/print02/stage-mdns; rm -rf "$ST" "$SB/print02/product-r21-tree"; mkdir -p "$ST/etc/alpbahos/firewall"
  python3 "$WT/scripts/rebuild/r21/product-r21.py" "$SB/print02/product-r21-tree" > /dev/null
  for f in rules.v4 rules.v6; do install -m 644 "$SB/print02/product-r21-tree/etc/alpbahos/firewall/$f" "$ST/etc/alpbahos/firewall/$f"; done
  rm -rf "$SB/print02/product-r21-tree"
  grep -q -- '-d 224.0.0.251 --dport 5353 -j ACCEPT' "$ST/etc/alpbahos/firewall/rules.v4"
  grep -q -- '-d ff02::fb --dport 5353 -j ACCEPT' "$ST/etc/alpbahos/firewall/rules.v6"
  grep -q '^hosts: mymachines resolve \[!UNAVAIL=return\] files myhostname dns$' "$R4/etc/nsswitch.conf" \
    || grep -q '^hosts: mymachines mdns4_minimal \[NOTFOUND=return\] resolve' "$R4/etc/nsswitch.conf" \
    || { echo "unexpected hosts line in nsswitch.conf"; exit 1; }
  sed 's/^hosts: mymachines resolve /hosts: mymachines mdns4_minimal [NOTFOUND=return] resolve /' "$R4/etc/nsswitch.conf" > "$ST/etc/nsswitch.conf"
  chmod 644 "$ST/etc/nsswitch.conf"
  grep '^hosts:' "$ST/etc/nsswitch.conf"
  cd "$WT"
  REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-mdns-r44 0.9-r44 "$ST" alpbahos-mdns-r44 0.9-r44
fi
if w enable; then
  chroot "$R4" /usr/bin/systemctl enable avahi-daemon.service cups-browsed.service 2>&1 | grep -v 'not mounted\|Proceeding anyway\|mileage' || true
  for u in multi-user.target.wants/avahi-daemon.service sockets.target.wants/avahi-daemon.socket multi-user.target.wants/cups-browsed.service; do
    [ -L "$R4/etc/systemd/system/$u" ] || { echo "not enabled: $u"; exit 1; }
  done
  echo "enabled: avahi-daemon (+socket), cups-browsed"
fi
echo "print02 done $(date +%T)"
