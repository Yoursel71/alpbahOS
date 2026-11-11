#!/bin/bash
# Round 39x row SBX, run as root inside an instrumented COPY of an installed system (test shell, gsh.py).
# Expects the signed test catalog unpacked in /var/lib/alp-sbx-test (sbx-catalog-r39x.sh). The system catalog in
# /usr/share/alp is not touched. Parts: hello | escape | net | suid | user | final
set -u
X=/var/lib/alp-sbx-test
IDX=$X/index.json
L=/var/log/alp
run() { local label=$1; shift; local out r; out=$("$@" 2>&1); r=$?
  echo "== $label: rc=$r"; printf '%s\n' "$out" | tail -n "${TAILN:-8}" | sed 's/^/   | /'; return 0; }
logof() { echo "-- build log $1 (sandbox lines and the end)"; grep -n -E '^\$ |^# \[' "$L/$1-1.0.build.log" 2>&1 | sed 's/^/   L /'
  tail -n "${LOGN:-6}" "$L/$1-1.0.build.log" 2>&1 | sed 's/^/   T /'; }
case ${1:-hello} in
hello)
  echo "== catalog: $(ls -l $IDX $IDX.sig | awk '{print $1, $3":"$4, $NF}' | tr '\n' ';')"
  echo "== system catalog untouched: $(sha256sum /usr/share/alp/index.json | cut -c1-16)"
  echo "== toolchain: cc $(command -v cc) make $(command -v make); alpbuild: $(getent passwd alpbuild)"
  run "root: alp --index $IDX search sbx" alp --index "$IDX" search sbx
  run "root: alp --index $IDX install -y sbx-hello" alp --index "$IDX" install -y sbx-hello
  logof sbx-hello
  echo "== installed file: $(stat -c '%n %U:%G %a %s' /usr/bin/sbx-hello 2>&1)"
  run "root: /usr/bin/sbx-hello" /usr/bin/sbx-hello
  run "testuser: sbx-hello" su - testuser -c sbx-hello
  run "alp list | grep sbx" sh -c "alp list | grep sbx"
  run "alp check (with sbx-hello)" alp check
  run "root: alp remove -y sbx-hello" alp remove -y sbx-hello
  echo "== after remove: $(ls -l /usr/bin/sbx-hello 2>&1)"
  run "alp check (after remove)" alp check
  ;;
escape)
  run "root: alp --index $IDX install -y sbx-escape (make writes to /etc and \$HOME/..)" alp --index "$IDX" install -y sbx-escape
  LOGN=10 logof sbx-escape
  echo "== /etc/sbx-escape: $(ls -l /etc/sbx-escape 2>&1)"
  echo "== sbx-escape-home anywhere under /var/lib/alp, /var/log/alp, /tmp, /root: [$(find /var/lib/alp /var/log/alp /tmp /root -name 'sbx-escape*' ! -name '*.build.log' 2>/dev/null | tr '\n' ' ')]"
  echo "== /usr/bin/sbx-escape: $(ls -l /usr/bin/sbx-escape 2>&1); db: $(alp list | grep -c sbx-escape)"
  ;;
net)
  echo "== the guest itself has network: $(getent hosts kernel.org | head -n 1)"
  run "root: alp --index $IDX install -y sbx-net (make tries DNS and TCP)" alp --index "$IDX" install -y sbx-net
  LOGN=10 logof sbx-net
  ;;
suid)
  run "root: alp --index $IDX install -y sbx-suid (setuid file not in the recipe's list)" alp --index "$IDX" install -y sbx-suid
  logof sbx-suid
  echo "== /usr/bin/sbx-suid: $(ls -l /usr/bin/sbx-suid 2>&1); db: $(alp list | grep -c sbx-suid)"
  ;;
user)
  run "testuser: alp --index $IDX search sbx" su - testuser -c "alp --index $IDX search sbx"
  run "testuser: alp --index $IDX install -y sbx-hello" su - testuser -c "alp --index $IDX install -y sbx-hello"
  echo "== /usr/bin/sbx-hello after the testuser attempt: $(ls -l /usr/bin/sbx-hello 2>&1)"
  ;;
final)
  run "alp check (end)" alp check
  echo "== sbx in db: $(alp list | grep -c '^sbx-'); leftover build trees: [$(ls -d /var/lib/alp/cache/build-sbx* /var/lib/alp/cache/destdir-sbx* 2>/dev/null | tr '\n' ' ')]"
  echo "== failed units: $(systemctl --failed --no-legend | wc -l); coredumps: $(ls /var/lib/systemd/coredump 2>/dev/null | wc -l)"
  ;;
esac
