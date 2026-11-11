#!/bin/bash
# ALP-TRUST-01 gate for image builds (run as root): no ISO from a root whose alp catalog is not signed and accepted.
#
# Usage: iso-gate.sh [--auto] <ROOT>      exit 0 = build may go on, anything else = do not build
#
# Without --auto the gate is always strict. With --auto (what build-iso.sh uses) the root decides, from its own
# files, never from an environment variable:
#   - strict when ALP-TRUST-01 has been applied to the root: the alp database has an `alp-keyring` record, OR the
#     installed alp.py is the signed-catalog version (such an alp refuses an unsigned catalog, so an image with it
#     and without a signed catalog would ship a broken package manager);
#   - otherwise warning only: prints "ALP-TRUST-01 henüz uygulanmadı: katalog imzasız" and exits 0, so images of a
#     root that was never integrated keep building as before.
# Once scripts/rebuild/trust/integrate-trust.sh has run on the root, --auto is strict by itself.
# Checks, with the tools of ROOT itself (its python3, gpgv and installed alp, in a chroot):
#   - the installed alp.py is the signed-catalog version;
#   - keyring, allowed.txt, index.json and index.json.sig exist, root:root, not group/other-writable;
#   - no secret key material under /usr/share/alp;
#   - the build user `alpbuild` exists with a locked password;
#   - `alp list` exits 0 (signature good, key allowed, catalog_version not below the stored one) and does not
#     warn that the catalog has expired;
#   - with one byte of index.json changed (in a private copy), the same alp refuses it.
# Mounts proc and dev in ROOT only if they are not mounted, and undoes exactly what it mounted.
set -euo pipefail
export LC_ALL=C
[ "$(id -u)" -eq 0 ] || { echo "iso-gate: run as root" >&2; exit 1; }
AUTO=0
[ "${1:-}" = --auto ] && { AUTO=1; shift; }
ROOT=$(realpath "${1:?usage: iso-gate.sh [--auto] <ROOT>}")
fail() { echo "iso-gate: FAIL: $*" >&2; exit 1; }
K=usr/share/alp/keys
if [ "$AUTO" = 1 ]; then
    [ -f "$ROOT/var/lib/alp/db.json" ] || fail "$ROOT has no alp database"
    HAS_KEYRING=$(python3 -c 'import json,sys; print(int("alp-keyring" in json.load(open(sys.argv[1]))["packages"]))' "$ROOT/var/lib/alp/db.json") \
        || fail "cannot read $ROOT/var/lib/alp/db.json"
    NEW_ALP=0
    grep -q verify_catalog_signature "$ROOT/usr/lib/alp/alp.py" 2> /dev/null && NEW_ALP=1
    if [ "$HAS_KEYRING" = 0 ] && [ "$NEW_ALP" = 0 ]; then
        echo "iso-gate: UYARI: ALP-TRUST-01 henüz uygulanmadı: katalog imzasız (kökte alp-keyring kaydı yok, kurulu alp.py eski sürüm). ISO derlemesi sürüyor; imzalı katalog için önce scripts/rebuild/trust/integrate-trust.sh çalıştırın."
        exit 0
    fi
    echo "iso-gate: ALP-TRUST-01 applied to $ROOT (alp-keyring record: $HAS_KEYRING, signed-catalog alp.py: $NEW_ALP): strict check"
fi
grep -q verify_catalog_signature "$ROOT/usr/lib/alp/alp.py" 2> /dev/null || fail "installed alp.py has no signature check"
for f in $K/alpbahos-catalog.gpg $K/allowed.txt usr/share/alp/index.json usr/share/alp/index.json.sig usr/lib/alp/alp.py; do
    [ -f "$ROOT/$f" ] && [ ! -L "$ROOT/$f" ] || fail "$f missing or not a regular file"
    [ "$(stat -c '%u:%g' "$ROOT/$f")" = 0:0 ] || fail "$f is not root:root"
    [ $(( 0$(stat -c '%a' "$ROOT/$f") & 022 )) -eq 0 ] || fail "$f is group/other-writable"
done
if find "$ROOT/usr/share/alp" \( -name 'private-keys-v1.d' -o -name 'secring.gpg' -o -name '*.key' \) | grep -q .; then
    fail "secret key material under /usr/share/alp"
fi
grep -q '^alpbuild:' "$ROOT/etc/passwd" || fail "no alpbuild user"
grep -q '^alpbuild:!' "$ROOT/etc/shadow" || fail "alpbuild password is not locked"

MOUNTED=()
T=$(mktemp -d "$ROOT/var/tmp/alp-gate.XXXXXX")
cleanup() {
    set +e
    rm -rf "$T"
    for m in "${MOUNTED[@]}"; do umount "$m"; done
}
trap cleanup EXIT
if ! mountpoint -q "$ROOT/proc"; then mount -t proc proc "$ROOT/proc"; MOUNTED+=("$ROOT/proc"); fi
if ! mountpoint -q "$ROOT/dev"; then mount --bind /dev "$ROOT/dev"; MOUNTED=("$ROOT/dev" "${MOUNTED[@]}"); fi
IN=(chroot "$ROOT" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=C /usr/bin/alp)
"${IN[@]}" list > "$T/list.out" 2> "$T/list.err" || fail "alp list refused the catalog: $(head -1 "$T/list.err")"
! grep -q 'süresi doldu' "$T/list.err" || fail "the catalog has expired: $(head -1 "$T/list.err")"
# negative control: the same alp must refuse a changed catalog
cp "$ROOT/usr/share/alp/index.json" "$ROOT/usr/share/alp/index.json.sig" "$T/"
python3 - "$T/index.json" << 'PY'
import sys
p = sys.argv[1]; d = bytearray(open(p, "rb").read()); i = d.index(b'"entries"') + 1; d[i] ^= 1; open(p, "wb").write(d)
PY
if "${IN[@]}" --index "/var/tmp/$(basename "$T")/index.json" list > /dev/null 2> "$T/neg.err"; then
    fail "alp accepted a catalog with a changed byte"
fi
grep -q 'imzası geçersiz' "$T/neg.err" || fail "unexpected refusal text: $(head -1 "$T/neg.err")"
echo "iso-gate: PASS ($ROOT: signed catalog accepted, changed catalog refused, alpbuild present)"
