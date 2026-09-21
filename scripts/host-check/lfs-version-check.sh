#!/usr/bin/env bash
set -uo pipefail

LC_ALL=C
export LC_ALL

minimum_kernel='5.10'
failures=0

version_check() {
    local label="$1"
    local command_name="$2"
    local minimum="$3"
    local found

    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'ERROR  %-12s missing (%s required)\n' "$label" "$minimum"
        failures=$((failures + 1))
        return
    fi

    found="$($command_name --version 2>&1 | grep -Eo '[0-9]+\.[0-9.]+[a-z]*' | head -n1)"
    if [ -z "$found" ]; then
        printf 'ERROR  %-12s version unavailable\n' "$label"
        failures=$((failures + 1))
        return
    fi

    if printf '%s\n%s\n' "$minimum" "$found" | sort --version-sort --check >/dev/null 2>&1; then
        printf 'OK     %-12s %s (>= %s)\n' "$label" "$found" "$minimum"
    else
        printf 'ERROR  %-12s %s (< %s)\n' "$label" "$found" "$minimum"
        failures=$((failures + 1))
    fi
}

if sort --version 2>&1 | grep -qi uutils; then
    version_check 'Coreutils' sort 0.8
else
    version_check 'Coreutils' sort 8.1
fi

version_check 'Bash' bash 3.2
version_check 'Binutils' ld 2.13.1
version_check 'Bison' bison 2.7
version_check 'Diffutils' diff 2.8.1
version_check 'Findutils' find 4.2.31
version_check 'Gawk' gawk 4.0.1
version_check 'GCC' gcc 5.4
version_check 'G++' g++ 5.4
version_check 'Grep' grep 2.5.1
version_check 'Gzip' gzip 1.3.12
version_check 'M4' m4 1.4.10
version_check 'Make' make 4.0
version_check 'Patch' patch 2.5.4
version_check 'Perl' perl 5.8.8
version_check 'Python' python3 3.4
version_check 'Sed' sed 4.1.5
version_check 'Tar' tar 1.22
version_check 'Texinfo' texi2any 5.0
version_check 'Xz' xz 5.0.0

kernel_version="$(uname -r | grep -Eo '^[0-9.]+' | head -n1)"
if [ -n "$kernel_version" ] && printf '%s\n%s\n' "$minimum_kernel" "$kernel_version" | sort --version-sort --check >/dev/null 2>&1; then
    printf 'OK     %-12s %s (>= %s)\n' 'Kernel' "$kernel_version" "$minimum_kernel"
else
    printf 'ERROR  %-12s %s (< %s)\n' 'Kernel' "${kernel_version:-unknown}" "$minimum_kernel"
    failures=$((failures + 1))
fi

if mount | grep -q 'devpts on /dev/pts' && [ -e /dev/ptmx ]; then
    printf 'OK     %-12s available\n' 'UNIX98 PTY'
else
    printf 'ERROR  %-12s unavailable\n' 'UNIX98 PTY'
    failures=$((failures + 1))
fi

for mapping in 'awk:GNU' 'yacc:Bison' 'sh:Bash'; do
    command_name="${mapping%%:*}"
    expected="${mapping##*:}"
    if command -v "$command_name" >/dev/null 2>&1 && "$command_name" --version 2>&1 | grep -qi "$expected"; then
        printf 'OK     alias %-6s -> %s\n' "$command_name" "$expected"
    else
        printf 'ERROR  alias %-6s is not %s\n' "$command_name" "$expected"
        failures=$((failures + 1))
    fi
done

compiler_test="$(mktemp -d)"
trap 'rm -rf -- "$compiler_test"' EXIT
if printf 'int main(){}\n' | g++ -x c++ - -o "$compiler_test/a.out" && "$compiler_test/a.out"; then
    printf 'OK     C++ compiler can build and run a program\n'
else
    printf 'ERROR  C++ compiler test failed\n'
    failures=$((failures + 1))
fi

printf '\nLogical processors: %s\n' "$(nproc 2>/dev/null || printf unknown)"
printf 'Failures: %s\n' "$failures"
exit "$failures"
