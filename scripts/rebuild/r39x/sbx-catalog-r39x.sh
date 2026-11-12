#!/bin/bash
# Round 39x row SBX: builds a separate, signed TEST catalog with four small local recipes (no network):
#   sbx-hello   configure / make / make install of a C hello program (must build in the sandbox and install)
#   sbx-escape  its make step writes to /etc and to $HOME/.. (must fail; nothing may appear outside the build tree)
#   sbx-net     its make step tries the network (getent hosts, /dev/tcp) and fails if any of them works
#   sbx-suid    installs a setuid binary that is not in the recipe's 'setuid' list (the merge must refuse it)
# The catalog is stamped with alp_catalog_tool.py and signed with the temporary primary catalog key in
# scratch-lfs-bench/alp-signing/primary (the installed systems' allowed.txt lists it). The key stays there; only
# index.json, index.json.sig, the recipes and the source archives are written to <out-dir>.
# Usage: sbx-catalog-r39x.sh <out-dir>     (refuses an existing <out-dir>)
set -eu
OUT=$1
WT=$(cd "$(dirname "$0")/../../.." && pwd)
TOOL=$WT/docs/handoffs/ai/alp-prototype/alp_catalog_tool.py
GH=/home/yrslf/alpbahOS/scratch-lfs-bench/alp-signing/primary
[ ! -e "$OUT" ] || { echo "REFUSED: $OUT exists"; exit 2; }
mkdir -p "$OUT/src" "$OUT/recipes"
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT

mkpkg() { # name make-body install-body
  local n=$1 d=$W/$1-1.0
  mkdir -p "$d"
  cat > "$d/hello.c" << 'C'
#include <stdio.h>
int main(void) { puts("alpbahOS sandbox build: hello"); return 0; }
C
  cat > "$d/configure" << 'SH'
#!/bin/sh
# tiny configure: records the prefix
prefix=/usr
for a in "$@"; do case $a in --prefix=*) prefix=${a#--prefix=} ;; esac; done
echo "PREFIX=$prefix" > config.mk
echo "configure: prefix $prefix, cc $(command -v cc), id $(id -u):$(id -g)"
SH
  chmod 755 "$d/configure"
  printf 'include config.mk\nall:\n%s\ninstall:\n%s\n' "$2" "$3" > "$d/Makefile"
  tar -C "$W" --owner=0 --group=0 --numeric-owner --mtime=@315532800 -czf "$OUT/src/$n-1.0.tar.gz" "$n-1.0"
  local sum; sum=$(sha256sum "$OUT/src/$n-1.0.tar.gz" | cut -d' ' -f1)
  python3 - "$OUT/recipes/$n.recipe.json" "$n" "$sum" "${4:-}" << 'PY'
import json, sys
path, name, sha, extra = sys.argv[1:5]
r = {"name": name, "version": "1.0", "source_url": f"src/{name}-1.0.tar.gz", "sha256": sha,
     "build": {"configure": ["./configure", "--prefix=@PREFIX@"], "make": ["make"], "make_install": ["make", "install"]}}
if extra:
    r.update(json.loads(extra))
open(path, "w").write(json.dumps(r, indent=2) + "\n")
PY
}
T=$(printf '\t')
mkpkg sbx-hello \
  "${T}cc -O2 -o hello hello.c${T}" \
  "${T}install -D -m 755 hello \$(DESTDIR)\$(PREFIX)/bin/sbx-hello"
mkpkg sbx-escape \
  "${T}cc -O2 -o hello hello.c
${T}-touch /etc/sbx-escape
${T}-touch \$\$HOME/../sbx-escape-home
${T}if test -e /etc/sbx-escape || test -e \$\$HOME/../sbx-escape-home; then echo ESCAPE-WRITE-OK; else echo writes-outside-blocked; fi; exit 1" \
  "${T}install -D -m 755 hello \$(DESTDIR)\$(PREFIX)/bin/sbx-escape"
mkpkg sbx-net \
  "${T}if getent hosts kernel.org; then echo NET-DNS-OK; exit 1; else echo net-dns-blocked; fi
${T}if bash -c 'exec 3<>/dev/tcp/10.0.2.2/80'; then echo NET-TCP-OK; exit 1; else echo net-tcp-blocked; fi
${T}if bash -c 'exec 3<>/dev/tcp/151.101.1.91/443'; then echo NET-TCP-PUBLIC-OK; exit 1; else echo net-tcp-public-blocked; fi
${T}echo sandbox-network-blocked; exit 1" \
  "${T}true"
mkpkg sbx-suid \
  "${T}cc -O2 -o hello hello.c" \
  "${T}install -D -m 4755 hello \$(DESTDIR)\$(PREFIX)/bin/sbx-suid"

python3 - "$OUT/index.json" << 'PY'
import json, sys
names = ["sbx-hello", "sbx-escape", "sbx-net", "sbx-suid"]
idx = {"schema_version": 1, "entries": {n: {"method": "recipe", "recipe": f"recipes/{n}.recipe.json"} for n in names}}
open(sys.argv[1], "w").write(json.dumps(idx, indent=2) + "\n")
PY
python3 "$TOOL" stamp "$OUT/index.json" --catalog-version 1 --keyring-version 1 --valid-days 30
FPR=$(gpg --homedir "$GH" --batch --with-colons --list-secret-keys 2>/dev/null | awk -F: '$1=="fpr" {print $10; exit}')
grep -q "^$FPR$" "$WT/configs/alp/allowed.txt" 2>/dev/null || grep -rq "$FPR" /home/yrslf/alpbahOS/scratch-lfs-bench/alp-signing/allowed.txt
echo "signing key: $FPR"
python3 "$TOOL" sign "$OUT/index.json" --homedir "$GH" --local-user "$FPR"
gpgv --keyring /home/yrslf/alpbahOS/scratch-lfs-bench/alp-signing/alpbahos-catalog.gpg "$OUT/index.json.sig" "$OUT/index.json" 2>&1 | grep -E "Good|BAD|imza" | head -2
find "$OUT" -type f -printf '%M %s %p\n' | sort -k3
