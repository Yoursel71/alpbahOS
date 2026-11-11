#!/bin/bash
# ALP-TRUST-01: run the repo alp.py from the HOST against a build root (`--root ROOT`), with that root's own catalog
# keys when it has them.
#
# Usage: alp-host.sh <ALP_PY> [alp options and command]    (the arguments must contain --root ROOT or --root=ROOT)
#
# Why: alp takes its trust anchors (keyring, allowed.txt) from the system that runs it, never from --root
# (design/trust-model.md, D173). Run from the host against an integrated build root, `alp.py --root R list` reads
# R/usr/share/alp/index.json (signed with R's keys) but looks for /usr/share/alp/keys on the HOST and is refused.
# This wrapper adds `--keyring R/usr/share/alp/keys/alpbahos-catalog.gpg --allowed-keys R/usr/share/alp/keys/allowed.txt`
#   - only when both files exist in R, and
#   - only when ALP_PY knows --allowed-keys (an older alp.py: nothing added, as before).
# A root that was never integrated (no keys and no `alp-keyring` record in its alp database) has an unsigned catalog
# by definition. For such a root, when this runs as root and ALP_PY knows the option, `--allow-unsigned` is added, so
# the signed-catalog alp.py reads an old root exactly as the old alp.py did (alp prints its unsigned-catalog warning on
# every run). An integrated root never gets it, and a half-integrated one (record without key files) gets nothing and
# is refused by alp.
# Nothing else changes: same arguments, same exit status, stdout and stderr not touched (exec).
# Use it only for build roots this project made (r4-root and its snapshots). It trusts the keys inside that root,
# which is the point for a build root and would be wrong for a root of unknown origin. When alp runs as root it
# still refuses key files that are not root-owned or that group/other can write.
set -euo pipefail
ALP_PY=${1:?usage: alp-host.sh <ALP_PY> [alp args...] (with --root ROOT)}
shift
ROOT=""
prev=""
for a in "$@"; do
    [ "$prev" = --root ] && ROOT=$a
    case $a in --root=*) ROOT=${a#--root=} ;; esac
    prev=$a
done
[ -n "$ROOT" ] || { echo "alp-host: --root ROOT missing" >&2; exit 2; }
K=$ROOT/usr/share/alp/keys
EXTRA=()
if [ -f "$K/alpbahos-catalog.gpg" ] && [ -f "$K/allowed.txt" ]; then
    if grep -q -- '--allowed-keys' "$ALP_PY"; then
        EXTRA=(--keyring "$K/alpbahos-catalog.gpg" --allowed-keys "$K/allowed.txt")
    fi
elif [ ! -e "$K/alpbahos-catalog.gpg" ] && [ ! -e "$K/allowed.txt" ] && [ "$(id -u)" -eq 0 ] \
        && grep -q -- '--allow-unsigned' "$ALP_PY" \
        && ! grep -q '"alp-keyring"' "$ROOT/var/lib/alp/db.json" 2> /dev/null; then
    EXTRA=(--allow-unsigned)
fi
exec python3 "$ALP_PY" "${EXTRA[@]}" "$@"
