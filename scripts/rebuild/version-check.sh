#!/bin/bash
# REBUILD-R2: MLFS 13.1 host requirements check.
# Source: book chapter 2.2 "Host System Requirements" (version-check.sh) and
# prologue "About the Multilib Edition" (gcc -m32 test).
# Adapted: runs as a normal user, read-only (scratch files only in a mktemp dir,
# removed on exit), collects every result instead of stopping at the first error,
# and prints a PASS/FAIL/WARN summary.
# Exit status: 0 when there is no FAIL, 1 otherwise. WARN does not fail.

LC_ALL=C
PATH=/usr/bin:/bin
# Same yacc shim as config.sh (Fedora ships byacc as /usr/bin/yacc; see config.sh).
[ -x /home/yrslf/alpbahOS/scratch-lfs-bench/lfs13-hostshim/yacc ] && PATH=/home/yrslf/alpbahOS/scratch-lfs-bench/lfs13-hostshim:$PATH

tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT

PASS_N=0
FAIL_N=0
WARN_N=0

pass() { printf 'PASS  %s\n' "$*"; PASS_N=$((PASS_N + 1)); }
fail() { printf 'FAIL  %s\n' "$*"; FAIL_N=$((FAIL_N + 1)); }
warn() { printf 'WARN  %s\n' "$*"; WARN_N=$((WARN_N + 1)); }
info() { printf 'INFO  %s\n' "$*"; }

# version_ok MIN FOUND: success when FOUND >= MIN (version sort, as in the book)
version_ok() {
    printf '%s\n' "$1" "$2" | sort --version-sort --check >/dev/null 2>&1
}

# is_newer A B: success when A > B
is_newer() {
    [ "$1" != "$2" ] && version_ok "$2" "$1"
}

# ver_check NAME COMMAND MIN
ver_check() {
    local name=$1 cmd=$2 min=$3 v
    if ! command -v "$cmd" >/dev/null 2>&1; then
        fail "$name: '$cmd' not found (need >= $min)"
        return
    fi
    v=$("$cmd" --version 2>&1 | grep -E -o '[0-9]+\.[0-9.]*[a-z]*' | head -n1)
    if [ -z "$v" ]; then
        fail "$name: cannot read a version from '$cmd --version' (need >= $min)"
        return
    fi
    if version_ok "$min" "$v"; then
        pass "$name $v (>= $min)"
    else
        fail "$name $v is too old (>= $min required)"
    fi
}

# alias_check CMD WORD: the command must identify itself as WORD
alias_check() {
    if "$1" --version 2>&1 | grep -qi "$2"; then
        pass "$1 is $2"
    else
        fail "$1 is NOT $2 (book: $1 should link to $2)"
    fi
}

# 1. Tools the rest of the checks depend on
for t in grep sed sort; do
    if "$t" --version >/dev/null 2>&1 || "$t" '' /dev/null >/dev/null 2>&1; then
        pass "$t runs"
    else
        fail "$t does not run"
    fi
done

# 2. Coreutils (book requires --version-sort, so this comes first)
if sort --version 2>&1 | grep -q uutils; then
    ver_check "Uutils Coreutils" sort 0.8
else
    ver_check "GNU Coreutils" sort 8.1
fi

# 3. Book list (chapter 2.2)
ver_check Bash       bash     3.2
ver_check Binutils   ld       2.13.1
ver_check Bison      bison    2.7
ver_check Diffutils  diff     2.8.1
ver_check Findutils  find     4.2.31
ver_check Gawk       gawk     4.0.1
ver_check GCC        gcc      5.4
ver_check "GCC (C++)" g++     5.4
ver_check Grep       grep     2.5.1a
ver_check Gzip       gzip     1.3.12
ver_check M4         m4       1.4.10
ver_check Make       make     4.0
ver_check Patch      patch    2.5.4
ver_check Perl       perl     5.8.8
ver_check Python     python3  3.4
ver_check Sed        sed      4.1.5
ver_check Tar        tar      1.22
ver_check Texinfo    texi2any 5.0
ver_check Xz         xz       5.0.0

# 4. Upper bounds from the book warning (not tested above these versions)
gcc_v=$(gcc --version 2>/dev/null | grep -E -o '[0-9]+\.[0-9.]*' | head -n1)
if [ -n "$gcc_v" ] && is_newer "$gcc_v" 16.2.0; then
    warn "GCC $gcc_v is newer than the tested 16.2.0 (book: a newer GCC is likely to break the build)"
fi
ld_v=$(ld --version 2>/dev/null | grep -E -o '[0-9]+\.[0-9.]*' | head -n1)
if [ -n "$ld_v" ] && is_newer "$ld_v" 2.47; then
    warn "Binutils $ld_v is newer than the tested 2.47 (book: not tested)"
fi

# 5. Aliases (book: awk, yacc, sh)
alias_check awk GNU
alias_check yacc Bison
alias_check sh Bash

# 6. Kernel and PTY
kver=$(uname -r | grep -E -o '^[0-9.]+')
if [ -n "$kver" ] && version_ok 5.10 "$kver"; then
    pass "Linux kernel $kver (>= 5.10)"
else
    fail "Linux kernel ${kver:-unknown} is too old (5.10 or later required)"
fi
if [ -e /dev/ptmx ] && awk '$2 == "/dev/pts" && $3 == "devpts" { f = 1 } END { exit !f }' /proc/mounts; then
    pass "Kernel supports UNIX 98 PTY (devpts mounted on /dev/pts)"
else
    fail "UNIX 98 PTY not available (no devpts on /dev/pts)"
fi

# 7. Compilers actually work (book: g++ test; multilib: gcc -m32 test)
printf 'int main(){}\n' > "$tmp/t.cc"
if g++ -x c++ "$tmp/t.cc" -o "$tmp/t_cc" >/dev/null 2>&1 && "$tmp/t_cc"; then
    pass "g++ builds and runs a program"
else
    fail "g++ does NOT build a working program"
fi

printf 'int main(){}\n' > "$tmp/t32.c"
if gcc -m32 "$tmp/t32.c" -o "$tmp/t32" >/dev/null 2>&1 && "$tmp/t32"; then
    pass "gcc -m32 builds and runs a 32-bit program (multilib prerequisite)"
else
    fail "gcc -m32 does NOT build/run 32-bit programs (multilib needs 32-bit glibc/libgcc; not installed by this script)"
fi

# 8. Resources (book 2.2.1 recommendations, advisory only)
cores=$(nproc 2>/dev/null)
if [ -z "$cores" ]; then
    fail "nproc is not available"
elif [ "$cores" -ge 4 ]; then
    pass "nproc reports $cores logical cores (book recommends at least 4)"
else
    warn "nproc reports $cores logical cores (book recommends at least 4; builds will be slow)"
fi
mem_kb=$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)
mem_gib=$(( (mem_kb + 524288) / 1048576 ))
if [ "$mem_kb" -ge $((8 * 1048576 - 524288)) ]; then
    pass "RAM about ${mem_gib} GiB (book recommends at least 8 GB)"
else
    warn "RAM about ${mem_gib} GiB (book recommends at least 8 GB)"
fi

# 9. Optional
if command -v mkfs.fat >/dev/null 2>&1; then
    info "dosfstools present (mkfs.fat)"
else
    info "dosfstools not found (only needed to create a new ESP)"
fi

echo
echo "SUMMARY: $PASS_N PASS, $FAIL_N FAIL, $WARN_N WARN"
if [ "$FAIL_N" -eq 0 ]; then
    echo "RESULT: PASS"
    exit 0
fi
echo "RESULT: FAIL"
exit 1
