#!/bin/bash
# REBUILD-R2: download every source of the MLFS 13.1 book into $LFS/sources.
# Source: book chapter 3 (wget-list-systemd = 87 packages + 9 patches, md5sums).
# The book's two lists are fetched at run time and kept in the log directory.
#
# Usage: fetch-sources.sh <manifest.tsv>
#   Run as the normal user (yrslf) after ch4-root.sh. Refuses anything except
#   /mnt/lfs13/sources. Downloads with curl (resume + retries, UA alpbahOS-build).
#   A file that fails at the book URL is tried once on the mirror of the book's
#   mirrors page (ftp.osuosl.org LFS 13.1 package dir). Every file is accepted
#   only if its md5 matches the book's md5sums, whatever the source.
#   Ends with the book's own check: md5sum -c md5sums (run in $LFS/sources).
#   Writes the manifest TSV (file, md5, url) to the path given. Exit 1 on any
#   missing or bad file.

set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/config.sh"
lfs_guard

BOOK=https://linuxfromscratch.org/mlfs/view/13.1
MIRROR=https://ftp.osuosl.org/pub/lfs/lfs-packages/13.1
UA=alpbahOS-build
LOGROOT=/home/yrslf/alpbahOS/scratch-lfs-bench/lfs13-logs
FETCHDIR=$LOGROOT/fetch
SRC=$LFS/sources

if [ $# -lt 1 ]; then
    echo "usage: $0 <manifest.tsv>" >&2
    exit 1
fi
MANIFEST=$1

if [ "$SRC" != /mnt/lfs13/sources ]; then
    echo "refusing SRC=$SRC (must be /mnt/lfs13/sources)" >&2
    exit 1
fi

TS=$(date +%Y%m%d-%H%M%S)
mkdir -p "$FETCHDIR"
LOG=$FETCHDIR/fetch-$TS.log
exec > >(tee -a "$LOG") 2>&1

echo "== fetch-sources $(date -Is) user=$(id -un) SRC=$SRC"

curl -fsSL --retry 5 --retry-delay 5 --retry-all-errors -A "$UA" \
    -o "$FETCHDIR/wget-list-systemd" "$BOOK/wget-list-systemd"
curl -fsSL --retry 5 --retry-delay 5 --retry-all-errors -A "$UA" \
    -o "$FETCHDIR/md5sums" "$BOOK/md5sums"
echo "book wget-list-systemd sha256: $(sha256sum "$FETCHDIR/wget-list-systemd" | cut -d' ' -f1)"
echo "book md5sums           sha256: $(sha256sum "$FETCHDIR/md5sums" | cut -d' ' -f1)"

WGET_LIST=$FETCHDIR/wget-list-systemd
MD5_LIST=$FETCHDIR/md5sums

# Expected md5 per file name, from the book's md5sums ("hash  name").
declare -A WANT=()
while read -r h n; do
    [ -n "${h:-}" ] && [ -n "${n:-}" ] && WANT[$n]=$h
done < <(tr -d '\r' < "$MD5_LIST")

md5_of() { md5sum "$1" | awk '{ print $1 }'; }

# fetch_one URL FNAME: returns 0 when $SRC/FNAME exists with the book's md5.
fetch_one() {
    local url=$1 fname=$2 want=${WANT[$2]:-} dest part u rc n
    dest=$SRC/$fname
    part=$SRC/$fname.part
    if [ -z "$want" ]; then
        echo "FAIL     $fname: no md5 in book md5sums"
        return 1
    fi
    if [ -f "$dest" ] && [ "$(md5_of "$dest")" = "$want" ]; then
        echo "have     $fname"
        return 0
    fi
    for u in "$url" "$MIRROR/$fname"; do
        for n in 1 2 3; do
            rc=0
            curl -fL --connect-timeout 30 --retry 3 --retry-delay 10 --retry-all-errors \
                -C - -A "$UA" -o "$part" "$u" || rc=$?
            if [ "$rc" -eq 33 ]; then
                # Range not satisfiable: the partial file is already the full size; start over.
                rm -f "$part"
                continue
            fi
            if [ "$rc" -eq 0 ]; then
                if [ "$(md5_of "$part")" = "$want" ]; then
                    mv -f "$part" "$dest"
                    echo "got      $fname  <- $u"
                    return 0
                fi
                echo "md5 mismatch for $fname from $u (not accepted)"
                rm -f "$part"
                break
            fi
            echo "curl rc=$rc for $fname from $u (attempt $n)"
        done
    done
    echo "FAIL     $fname: could not get a file with the book's md5"
    return 1
}

OK_N=0
FAILED=()
total=0
while read -r url; do
    [ -n "$url" ] || continue
    total=$((total + 1))
    fname=${url##*/}
    if fetch_one "$url" "$fname"; then
        OK_N=$((OK_N + 1))
    else
        FAILED+=("$fname")
    fi
done < <(tr -d '\r' < "$WGET_LIST" | grep -E '^https?://')

echo
echo "== md5sum -c (book check, in $SRC)"
MD5_OUT=$FETCHDIR/md5sum-check-$TS.txt
md5rc=0
(cd "$SRC" && md5sum -c "$MD5_LIST") > "$MD5_OUT" 2>&1 || md5rc=$?
md5_ok=$(grep -c ': OK$' "$MD5_OUT" || true)
grep -v ': OK$' "$MD5_OUT" || true
echo "md5sum -c: $md5_ok OK of $(wc -l < "$MD5_LIST") (rc=$md5rc), output: $MD5_OUT"

# Manifest: file, md5, book URL (header always written).
mkdir -p "$(dirname "$MANIFEST")"
{
    printf 'file\tmd5\turl\n'
    while read -r url; do
        [ -n "$url" ] || continue
        fname=${url##*/}
        printf '%s\t%s\t%s\n' "$fname" "${WANT[$fname]:-MISSING}" "$url"
    done < <(tr -d '\r' < "$WGET_LIST" | grep -E '^https?://')
} > "$MANIFEST"

echo
echo "== summary"
echo "book wget entries: $total   book md5sums entries: $(awk 'NF' "$MD5_LIST" | wc -l)"
echo "fetched or already present with book md5: $OK_N"
echo "failed: ${#FAILED[@]}${FAILED[*]:+ (${FAILED[*]})}"
echo "md5sum -c: $md5_ok OK (rc=$md5rc)"
echo "manifest: $MANIFEST"
echo "log: $LOG"

if [ "${#FAILED[@]}" -gt 0 ] || [ "$md5rc" -ne 0 ]; then
    echo "RESULT: FAIL"
    exit 1
fi
echo "RESULT: PASS"
exit 0
