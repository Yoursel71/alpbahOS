#!/usr/bin/env bash
set -euo pipefail
umask 022
export LC_ALL=C PATH=/usr/bin:/bin
# LFS 12.4 requirements, fail on every unsupported lower/upper version.
check() {
    local tool=$1 minimum=$2 maximum=${3:-} v
    command -v "$tool" >/dev/null
    v=$("$tool" --version 2>&1)
    v=$(python3 -c 'import re,sys; m=re.search(r"[0-9]+\.[0-9]+(?:\.[0-9]+)*[a-z]*",sys.stdin.read()); print(m.group() if m else "")' <<< "$v")
    [[ -n $v ]] || { echo "Cannot parse $tool"; exit 1; }
    [[ $(printf '%s\n%s\n' "$minimum" "$v" | sort -V | head -1) == "$minimum" ]]
    [[ -z $maximum || $(printf '%s\n%s\n' "$maximum" "$v" | sort -V | tail -1) == "$maximum" ]]
    printf '%-12s %s OK\n' "$tool" "$v"
}
check bash 3.2; check ld 2.13.1 2.45; check bison 2.7; check sort 8.1
check diff 2.8.1; check find 4.2.31; check gawk 4.0.1
check gcc 5.4 15.2.0; check g++ 5.4 15.2.0; check grep 2.5.1a
check gzip 1.3.12; check m4 1.4.10; check make 4.0; check patch 2.5.4
check perl 5.8.8; check python3 3.4; check sed 4.1.5; check tar 1.22
check texi2any 5.0; check xz 5.0.0
kernel=$(uname -r | sed 's/-.*//')
[[ $(printf '5.4\n%s\n' "$kernel" | sort -V | head -1) == 5.4 ]]
[[ -e /dev/ptmx ]]; findmnt /dev/pts >/dev/null
awk --version | sed -n 1p | grep -q GNU
yacc --version | sed -n 1p | grep -q Bison
sh --version | sed -n 1p | grep -q bash
testdir=$(mktemp -d /srv/lfs/build/version-check.XXXXXX)
trap 'rm -rf -- "$testdir"' EXIT
printf 'int main(){}\n' | g++ -x c++ - -o "$testdir/a.out"
"$testdir/a.out"
printf 'compiler, PTY, aliases and kernel %s OK; nproc=%s\n' "$kernel" "$(nproc)"
