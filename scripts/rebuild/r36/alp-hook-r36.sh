#!/bin/bash
# Round 36 DIAG_HOOK (runs as root inside an installed copy, see diag-r21.sh): ALP-TRUST-01 rows on the booted system.
#   - alp list / check / search with the image's own signed catalog (rc and line counts);
#   - the same catalog with one byte changed and the original signature: alp must refuse it (rc != 0);
#   - key files: owner and mode; no secret key material under /usr/share/alp.
# Output lines are prefixed with the row name; the host reads them as "R21DIAG hook:" lines.
set -u
K=/usr/share/alp
row() { echo "$1 rc=$2 ${3:-}"; }
out=$(alp list 2>&1); row alp-list $? "lines=$(printf '%s\n' "$out" | wc -l)"
out=$(alp check 2>&1); row alp-check $? "$(printf '%s\n' "$out" | tail -1 | cut -c1-120)"
out=$(alp search bash 2>&1); row alp-search $? "lines=$(printf '%s\n' "$out" | wc -l)"
T=$(mktemp -d /var/tmp/alp-hook.XXXXXX)
cp "$K/index.json" "$K/index.json.sig" "$T/"
# change one character of the first "version" value; the signature stays the old one
sed -i '0,/"version": "/s//"version": "9/' "$T/index.json"
if cmp -s "$K/index.json" "$T/index.json"; then
    row alp-tamper-refused 99 "copy-not-changed"
else
    out=$(alp --index "$T/index.json" list 2>&1); rc=$?
    row alp-tamper-refused "$rc" "$(printf '%s\n' "$out" | tail -1 | cut -c1-120)"
fi
rm -rf "$T"
row alp-key-files 0 "$(stat -c '%U:%G %a %n' "$K"/keys/* "$K/index.json" "$K/index.json.sig" 2>&1 | tr '\n' ';')"
sec=$(grep -rlE 'PRIVATE KEY|SECRET KEY' "$K" 2>/dev/null | wc -l)
row alp-no-secret-key 0 "files-with-secret-markers=$sec"
