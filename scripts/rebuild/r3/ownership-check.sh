#!/bin/bash
# REBUILD-R3: ownership check for a build root.
# Usage: ownership-check.sh ROOT OWNED_LIST [BASE_GENERATED_LIST]
#   OWNED_LIST: root-relative paths (no leading slash), one per line, as recorded by the alp
#               manifests (owned.txt). A path listed twice is a conflict.
#   BASE_GENERATED_LIST: exact root-relative paths written by build hooks (ldconfig, install-info)
#               and documented in the verification note. They are counted separately, not as unowned.
# Excluded trees are runtime, build scratch, test logs and the alp database (EXCL below).
# Exit 0 only when unowned = 0 and conflicts = 0.
set -euo pipefail
export LC_ALL=C
ROOT=$1
OWNED=$2
GEN=${3:-/dev/null}
EXCL='^(proc|sys|dev|run|tmp|var/log|var/cache|var/tmp|sources|root|home|var/lib/alp|lost\+found)(/|$)'
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
( cd "$ROOT" && find . -xdev \( -type f -o -type l \) -printf '%P\n' ) | sort > "$work/all"
grep -Ev "$EXCL" "$work/all" > "$work/scan"
grep -vE '^(#|$)' "$GEN" | sort -u > "$work/gen" || true
comm -23 "$work/scan" "$work/gen" > "$work/base"
sort "$OWNED" | uniq -d > "$work/conflicts"
sort -u "$OWNED" > "$work/owned"
comm -23 "$work/base" "$work/owned" > "$work/unowned"
echo "files scanned: $(wc -l < "$work/base")"
echo "excluded by base-generated list: $(comm -12 "$work/scan" "$work/gen" | wc -l)"
echo "owned paths: $(wc -l < "$work/owned")"
echo "unowned: $(wc -l < "$work/unowned")"
echo "conflicts: $(wc -l < "$work/conflicts")"
head -40 "$work/unowned"
[ "$(wc -l < "$work/unowned")" -eq 0 ] && [ "$(wc -l < "$work/conflicts")" -eq 0 ]
