#!/bin/bash
# ALP-TRUST-01 step 3: put the signed-catalog alp into a root tree (run as root on the host).
#
# Usage: integrate-trust.sh <ROOT> <LEDGER_DIR>
#   ROOT            the root tree to change. The live r4-root is refused unless ALLOW_LIVE_R4=1 is set on purpose.
#   LEDGER_DIR      where the manifests of the new alp records are written (outside the repository)
# catalog_version is chosen by resign-catalog.py (one above the highest the root has seen). Later catalog changes:
# scripts/rebuild/trust/record-catalog.sh (make-catalog-r8.py re-signs by itself once the root is integrated).
# Needs scratch-lfs-bench/alp-signing/ from make-temp-signing-key.sh (SIGNING=... to point elsewhere).
#
# What it does, each as an alp record (stage-record-r8.py + r4_lib.py transfer + alp adopt-base, like apply-r7.sh):
#   1. alp-build-user   /usr/lib/sysusers.d/alp-build.conf, then creates the user `alpbuild` with systemd-sysusers
#                       (system uid, no login shell, locked password, home "/")
#   2. alp-keyring      /usr/share/alp/keys/alpbahos-catalog.gpg and allowed.txt (root:root 644), PUBLIC keys only
#   3. alp              /usr/lib/alp/alp.py replaced by the repository version (takes the file over from the old record)
#   4. alp-catalog      /usr/share/alp/index.json stamped (catalog_version, valid_until, signed_keyring_version,
#                       recipe_sha256) and signed; index.json.sig added
# Then it checks: alp list / check / search in a chroot of ROOT with the signed catalog.
# Order matters: the keyring and the signature go in before nothing else reads the catalog with the new alp.py.
# Every chroot mount made here is undone on exit (trap) and checked with findmnt.
set -euo pipefail
export LC_ALL=C
[ "$(id -u)" -eq 0 ] || { echo "integrate-trust: run as root" >&2; exit 1; }
[ $# -eq 2 ] || { echo "usage: integrate-trust.sh <ROOT> <LEDGER_DIR>  (the catalog version argument is gone: resign-catalog.py picks it)" >&2; exit 1; }
ROOT=$(realpath "$1"); LEDGER=$2
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
SIGNING=${SIGNING:-$SB/alp-signing}
WT=$(cd "$(dirname "$0")/../../.." && pwd)
PROTO=$WT/docs/handoffs/ai/alp-prototype
ALP=$PROTO/alp.py
LIB=$WT/scripts/rebuild/r4/r4_lib.py
REC=$WT/scripts/rebuild/r8/stage-record-r8.py
VER=0.9-trust1
die() { echo "integrate-trust: $*" >&2; exit 1; }

if [ "$ROOT" = "$(realpath "$SB/r4-root")" ] && [ "${ALLOW_LIVE_R4:-0}" != 1 ]; then
    die "ROOT is the live r4-root; set ALLOW_LIVE_R4=1 only when that is intended and no other writer is active"
fi
[ -f "$ROOT/usr/lib/alp/alp.py" ] && [ -f "$ROOT/usr/share/alp/index.json" ] && [ -f "$ROOT/var/lib/alp/db.json" ] \
    || die "$ROOT does not look like an alpbahOS root (alp.py, index.json, db.json)"
for f in alpbahos-catalog.gpg allowed.txt FINGERPRINTS primary; do
    [ -e "$SIGNING/$f" ] || die "$SIGNING/$f missing (run make-temp-signing-key.sh)"
done
grep -q verify_catalog_signature "$ALP" || die "$ALP is not the signed-catalog alp"
[ -x "$ROOT/usr/bin/gpgv" ] && [ -x "$ROOT/usr/bin/bwrap" ] || die "$ROOT has no /usr/bin/gpgv or /usr/bin/bwrap"
if findmnt -rn -o TARGET | grep -qE "^$ROOT(/|\$)"; then die "something is mounted under $ROOT"; fi
PRIMARY=$(awk '$1=="primary"{print $2}' "$SIGNING/FINGERPRINTS")

W=$(mktemp -d /var/tmp/alp-trust-integrate.XXXXXX)
cleanup() {
    set +e
    for m in dev proc; do mountpoint -q "$ROOT/$m" && umount "$ROOT/$m"; done
    rm -rf "$W"
    echo "integrate-trust: mounts left under $ROOT: $(findmnt -rn -o TARGET | grep -cE "^$ROOT(/|\$)")"
}
trap cleanup EXIT
mkdir -p "$LEDGER"

record() { # <name> <version> <stage> : files into ROOT + manifest, ownership transfer, adopt-base
    local name=$1 ver=$2 stage=$3 dir=$LEDGER/$1
    mkdir -p "$dir"
    REPLACE=1 python3 "$REC" "$ROOT" "$ALP" "$dir" "$stage" "$name" "$ver" > "$dir/record.log" 2>&1 || { cat "$dir/record.log"; die "record $name failed"; }
    local man=$dir/manifest.json sha
    sha=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["package"]["source"]["sha256"])' "$man")
    python3 "$LIB" transfer --root "$ROOT" --alp "$ALP" --manifest "$man" --name "$name" --version "$ver" --log "$dir/transfers.tsv"
    python3 "$ALP" --root "$ROOT" adopt-base --manifest "$man" --name "$name" --version "$ver" --source-sha256 "$sha" > "$dir/adopt.log" 2>&1 \
        || { cat "$dir/adopt.log"; die "adopt-base $name failed"; }
    echo "recorded $name $ver ($(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["entries"]))' "$man") entries)"
}

# 1. build user ------------------------------------------------------------------------------------------------
S=$W/user; mkdir -p "$S/usr/lib/sysusers.d"
cat > "$S/usr/lib/sysusers.d/alp-build.conf" << 'EOF'
# alp runs recipe build steps as this user inside bubblewrap (ALP-TRUST-01, D170). No login, no password, no home.
u alpbuild - "alp build user" / /usr/sbin/nologin
EOF
chmod 644 "$S/usr/lib/sysusers.d/alp-build.conf"
record alp-build-user "$VER" "$S"
if ! grep -q '^alpbuild:' "$ROOT/etc/passwd"; then
    systemd-sysusers --root="$ROOT" alp-build.conf
fi
grep '^alpbuild:' "$ROOT/etc/passwd" || die "alpbuild was not created"
BUID=$(awk -F: '$1=="alpbuild"{print $3}' "$ROOT/etc/passwd")
[ "$BUID" -gt 0 ] && [ "$BUID" -lt 1000 ] || die "alpbuild has an unexpected uid $BUID"
grep -q '^alpbuild:!' "$ROOT/etc/shadow" || die "alpbuild password is not locked"

# 2. keyring (public keys only) ---------------------------------------------------------------------------------
S=$W/keys; mkdir -p "$S/usr/share/alp/keys"
install -m 644 "$SIGNING/alpbahos-catalog.gpg" "$SIGNING/allowed.txt" "$S/usr/share/alp/keys/"
if gpg --batch --list-packets "$S/usr/share/alp/keys/alpbahos-catalog.gpg" 2> /dev/null | grep -q 'secret key packet'; then
    die "the keyring to ship contains a secret key"
fi
record alp-keyring "1-temporary" "$S"

# 3. alp.py ------------------------------------------------------------------------------------------------------
S=$W/alp; mkdir -p "$S/usr/lib/alp"
install -m 755 "$ALP" "$S/usr/lib/alp/alp.py"
record alp "$VER" "$S"

# 4. signed catalog ----------------------------------------------------------------------------------------------
S=$W/catalog; mkdir -p "$S/usr/share/alp"
cp "$ROOT/usr/share/alp/index.json" "$S/usr/share/alp/index.json"
# the one signing path (same as make-catalog-r8.py): the keyring record above makes the root "applied"
python3 "$WT/scripts/rebuild/trust/resign-catalog.py" "$ROOT" "$S/usr/share/alp/index.json" --signing "$SIGNING"
CATVER=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["catalog_version"])' "$S/usr/share/alp/index.json")
record alp-catalog "$(date -u +%Y.%m.%d)-v$CATVER" "$S"

# 5. checks in a chroot of ROOT (the image's own python3, gpgv and alp) ----------------------------------------
for f in usr/share/alp/keys/alpbahos-catalog.gpg usr/share/alp/keys/allowed.txt usr/share/alp/index.json usr/share/alp/index.json.sig usr/lib/alp/alp.py; do
    [ "$(stat -c '%u:%g' "$ROOT/$f")" = 0:0 ] || die "$f is not root:root"
done
mount -t proc proc "$ROOT/proc"
mount --bind /dev "$ROOT/dev"
for c in "list" "check" "search bash"; do
    # shellcheck disable=SC2086
    if chroot "$ROOT" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=C /usr/bin/alp $c > "$LEDGER/alp-$(echo $c | tr ' ' '-').out" 2>&1; then
        echo "chroot alp $c: rc 0 ($(wc -l < "$LEDGER/alp-$(echo $c | tr ' ' '-').out") lines)"
    else
        echo "chroot alp $c: rc $?"; tail -3 "$LEDGER/alp-$(echo $c | tr ' ' '-').out"; die "check failed"
    fi
done
echo "integrate-trust: done for $ROOT (catalog_version $CATVER, signed by $PRIMARY)"
