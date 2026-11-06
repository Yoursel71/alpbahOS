#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly work_root=/sources/attr-2.5.2-ch8-20260929T232033139985754Z/attr-2.5.2
readonly test_log="$work_root/test-suite.log"

[[ -d "$work_root" && -f "$work_root/Makefile" ]] || { echo 'Attr configured build tree is missing.' >&2; exit 1; }
[[ -f "$test_log" ]] || { echo 'Attr test-suite.log is missing.' >&2; exit 1; }
grep -Fxq '# TOTAL: 2' "$test_log"
grep -Fxq '# PASS:  1' "$test_log"
grep -Fxq '# FAIL:  1' "$test_log"
grep -Fxq '# ERROR: 0' "$test_log"
grep -Fq 'FAIL: test/root/getfattr' "$test_log"
grep -Fq 'security.selinux="unconfined_u:object_r:unlabeled_t:s0"' "$test_log"
if grep -Fq 'FAIL: test/' "$test_log" && [[ "$(grep -Fc 'FAIL: test/' "$test_log")" -ne 1 ]]; then
    echo 'Attr test log contains an unreviewed additional failing test.' >&2
    exit 1
fi

cd "$work_root"
make install
test -x /usr/bin/attr
test -x /usr/bin/getfattr
test -x /usr/bin/setfattr
test -e /usr/lib/libattr.so
test ! -e /usr/lib/libattr.a
test -s /usr/include/attr/libattr.h
test -d /usr/share/doc/attr-2.5.2

printf 'Installed Attr 2.5.2. Test summary: 1 PASS, 1 known SELinux-label FAIL; the failed test log is retained.\n'
