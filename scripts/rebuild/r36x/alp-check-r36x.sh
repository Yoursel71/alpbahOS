#!/bin/bash
# Round 36x row ALP, run as root inside an instrumented COPY of an installed system (test shell, gsh.py).
# Part "good": alp list/check/search as root and as the test user, versions, key files, build user, bubblewrap.
# Part "tamper": changes one byte of the catalog and then removes its signature, IN THE COPY ONLY, and reruns alp.
# Usage (in the guest): alp-check-r36x.sh good|tamper
set -u
U=testuser
asuser() { su - "$U" -c "$1"; }
rc() { local label=$1; shift; local out; out=$("$@" 2>&1); local r=$?
  echo "== $label: rc=$r, $(printf '%s\n' "$out" | wc -l) lines"; printf '%s\n' "$out" | head -n "${HEADN:-4}" | sed 's/^/   | /'
  [ "$r" = 0 ] || printf '%s\n' "$out" | grep -i -E "imza|katalog|hata|error" | tail -n 3 | sed 's/^/   ! /'; }
IDX=/usr/share/alp/index.json
case ${1:-good} in
good)
  echo "== alp: $(command -v alp) -> $(readlink -f "$(command -v alp)")"
  head -n 3 "$(readlink -f "$(command -v alp)")" | sed 's/^/   | /'
  PY=$(grep -o '/[^ "]*alp\.py' "$(readlink -f "$(command -v alp)")" | head -n 1); [ -n "$PY" ] || PY=$(readlink -f "$(command -v alp)")
  echo "== alp.py: $PY, sha256 $(sha256sum "$PY" | cut -c1-16)..., ALP_VERSION: $(grep -m1 '^ALP_VERSION' "$PY")"
  echo "== signature code present: SYSTEM_KEYRING $(grep -c '^SYSTEM_KEYRING' "$PY"), CatalogTrustError $(grep -c 'class CatalogTrustError' "$PY"), _prepare_sandbox $(grep -c 'def _prepare_sandbox' "$PY")"
  echo "== catalog: $(ls -l "$IDX" "$IDX.sig" 2>&1 | awk '{print $1, $3":"$4, $5, $NF}' | tr '\n' ';')"
  python3 -c 'import json; d=json.load(open("/usr/share/alp/index.json")); print("== catalog fields:", {k: d.get(k) for k in ("schema_version","catalog_version","valid_until","updated_at")}, "packages:", len(d.get("packages", {})))' 2>&1
  echo "== keys dir: $(stat -c '%n %U:%G %a' /usr/share/alp/keys)"
  for f in /usr/share/alp/keys/*; do echo "   $(stat -c '%n %U:%G %a %s' "$f")"; done
  echo "== secret key material under /usr/share/alp and /etc: $(grep -rl -E 'PRIVATE KEY|BEGIN PGP PRIVATE' /usr/share/alp /etc 2>/dev/null | wc -l)"
  gpg --show-keys --with-colons /usr/share/alp/keys/alpbahos-catalog.gpg 2>/dev/null | grep -E '^(pub|sec|ssb|fpr)' | cut -d: -f1,5,10 | head -n 4 | sed 's/^/   key: /'
  echo "   (sec/ssb lines above would mean secret keys; pub/fpr only = public)"
  echo "== allowed.txt:"; sed 's/^/   | /' /usr/share/alp/keys/allowed.txt
  rc "root: alp list" alp list
  rc "root: alp check" alp check
  rc "root: alp search bash" alp search bash
  rc "testuser: alp list" asuser "alp list"
  rc "testuser: alp check" asuser "alp check"
  rc "testuser: alp search bash" asuser "alp search bash"
  echo "== build user: $(getent passwd alpbuild) | group: $(getent group alpbuild)"
  echo "== bwrap: $(ls -l /usr/bin/bwrap 2>&1 | awk '{print $1, $3, $NF}'); $(bwrap --version 2>&1)"
  echo "== kernel: unprivileged_userns_clone $(cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null || echo n/a), max_user_namespaces $(cat /proc/sys/user/max_user_namespaces)"
  rc "root: bwrap --unshare-all --ro-bind / / /usr/bin/true" bwrap --unshare-all --ro-bind / / /usr/bin/true
  rc "root: bwrap ... id; network inside" bwrap --unshare-all --ro-bind / / --proc /proc --dev /dev sh -c 'id; ls /sys/class/net 2>/dev/null | tr "\n" " "; cat /proc/net/dev | tail -n +3 | cut -d: -f1 | tr "\n" " "'
  rc "testuser: bwrap --unshare-all --ro-bind / / /usr/bin/true" asuser "bwrap --unshare-all --ro-bind / / /usr/bin/true"
  HEADN=8 rc "root: alp _prepare_sandbox (the engine's own probe: drop to alpbuild, then bwrap /usr/bin/true)" \
    python3 -c "import sys; sys.path.insert(0, '$(dirname "$PY")'); import importlib.util as u; s=u.spec_from_file_location('alpmod', '$PY'); m=u.module_from_spec(s); sys.modules['alpmod']=m; s.loader.exec_module(m); b=m._prepare_sandbox(m.Paths.resolve(None)); print('sandbox:', b)"
  HEADN=8 rc "testuser: alp _prepare_sandbox" asuser "python3 -c \"import sys, importlib.util as u; s=u.spec_from_file_location('alpmod', '$PY'); m=u.module_from_spec(s); sys.modules['alpmod']=m; s.loader.exec_module(m); print('sandbox:', m._prepare_sandbox(m.Paths.resolve(None)))\""
  ;;
tamper)
  cp -a "$IDX" /root/index.json.orig; cp -a "$IDX.sig" /root/index.json.sig.orig
  python3 - << 'PY'
p = "/usr/share/alp/index.json"
b = bytearray(open(p, "rb").read())
i = b.find(b'"packages"')
j = i + 1  # the letter p of "packages" -> P: one byte, still valid JSON text structure aside from the key name
old = b[j]; b[j] = ord("P") if old == ord("p") else ord("p")
open(p, "wb").write(bytes(b))
print(f"== tamper: byte {j} changed {chr(old)!r} -> {chr(b[j])!r}")
PY
  cmp -l /root/index.json.orig "$IDX" | head -n 3 | sed 's/^/   cmp: /'
  HEADN=3 rc "root: alp list (one byte changed)" alp list
  HEADN=3 rc "root: alp check (one byte changed)" alp check
  HEADN=3 rc "testuser: alp list (one byte changed)" asuser "alp list"
  cp -a /root/index.json.orig "$IDX"; rm -f "$IDX.sig"
  echo "== catalog restored, signature removed: $(ls "$IDX.sig" 2>&1)"
  HEADN=3 rc "root: alp list (no signature)" alp list
  HEADN=3 rc "root: alp check (no signature)" alp check
  cp -a /root/index.json.sig.orig "$IDX.sig"
  rc "root: alp list (both restored)" alp list
  ;;
esac
