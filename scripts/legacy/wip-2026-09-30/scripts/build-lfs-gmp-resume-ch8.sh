#!/usr/bin/env bash
set -Eeuo pipefail

# Continue the exact D34 GMP snapshot after configure completed with portable
# x86_64 CFLAGS and --enable-fat. No source/configuration is regenerated here.
readonly GMP_ROOT=/sources/gmp-6.3.0-ch8-20260929T230657Z/gmp-6.3.0

cd "$GMP_ROOT"
printf 'GMP continuation root: %s\n' "$GMP_ROOT"
grep '^CFLAGS[[:space:]]*=' Makefile
grep -Fq -- '-march=x86-64 -mtune=generic' Makefile
if grep -Fq -- '-march=znver3' Makefile; then
    printf 'ERROR: GMP Makefile contains host-specific znver3 flags.\n' >&2
    exit 1
fi
[[ "$(readlink gmp-mparam.h)" == mpn/x86_64/fat/gmp-mparam.h ]]

make
make html
set -o pipefail
make check 2>&1 | tee gmp-check-log
passed=$(awk '/# PASS:/{total += $3} END {print total + 0}' gmp-check-log)
printf 'GMP_TEST_PASS_COUNT=%s\n' "$passed"
test "$passed" -ge 199
make install
make install-html
test -e /usr/lib/libgmp.so
test -e /usr/lib/libgmpxx.so
test -d /usr/share/doc/gmp-6.3.0
printf 'Installed portable GMP 6.3.0; critical check passed with %s PASS tests.\n' "$passed"
