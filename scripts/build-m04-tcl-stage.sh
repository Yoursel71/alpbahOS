#!/usr/bin/env bash
set -Eeuo pipefail

# LFS 12.4-systemd Tcl 8.6.16 isolated package stage. Run on Builder as root.
# Copy capture-package-manifest.py and compare-package-manifest.py to /home/sa
# before running. Build/stage/manifest/preflight/log files stay under /mnt/lfs;
# this script does not install into rootfs /usr or update alp's database.

LFS=/mnt/lfs
BUILD=/mnt/lfs/build/tcl-8.6.16-m04-r1
DOC_BUILD=/mnt/lfs/build/tcl-8.6.16-html-m04-r1
STAGE_HOST=/mnt/lfs/tmp/alp-m04-tcl-stage-r1
STAGE_CHROOT=/tmp/alp-m04-tcl-stage-r1
SOURCE=/mnt/lfs/sources/tcl8.6.16-src.tar.gz
DOC_SOURCE=/mnt/lfs/sources/tcl8.6.16-html.tar.gz
LOG=/mnt/lfs/tmp/alp-logs/m04-tcl-8.6.16-stage-20260924-r1.log
MANIFEST=/mnt/lfs/tmp/alp-logs/tcl-8.6.16-2026-09-24.json
PREFLIGHT=/mnt/lfs/tmp/alp-logs/tcl-8.6.16-2026-09-24-preflight.log
CAPTURE_TOOL=${CAPTURE_TOOL:-/home/sa/capture-package-manifest.py}
COMPARE_TOOL=${COMPARE_TOOL:-/home/sa/compare-package-manifest.py}
EXPECTED_MD5=eaef5d0a27239fb840f04af8ec608242
EXPECTED_SHA256=91cb8fa61771c63c262efb553059b7c7ad6757afa5857af6265e4b0bdc2a14a5
DOC_EXPECTED_MD5=750c221bcb6f8737a6791c1fbe98b684
DOC_EXPECTED_SHA256=87e66909c00a7f6f827502f63e44740141a6ce960a321945bb113d7ecd899282
ALP_SHA256=7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132
MOUNTS=()
FINISHED=0

check_alp_invariants() {
    [[ $(sha256sum "$LFS/usr/lib/alp/alp.py" | awk '{print $1}') == "$ALP_SHA256" ]]
    python3 - "$LFS/var/lib/alp/db.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as stream:
    db = json.load(stream)
assert db.get("packages") == {}, "alp package database is not empty"
PY
}

compare_rootfs() {
    local compare_status=0
    if python3 "$COMPARE_TOOL" --manifest "$MANIFEST" --root "$LFS" > "$PREFLIGHT"; then
        compare_status=0
    else
        compare_status=$?
    fi
    (( compare_status <= 1 ))
    echo "PREFLIGHT_EXIT=$compare_status (1 means one or more differences were reported)"
    chmod 0644 "$PREFLIGHT"
    cat "$PREFLIGHT"
}

tcl_smoke() {
    local output
    output=$(printf 'puts [expr {20 + 22}]\n' | chroot "$LFS" /usr/bin/env -i \
        PATH=/usr/bin:/usr/sbin:/bin:/sbin \
        LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib" \
        TCL_LIBRARY="$STAGE_CHROOT/usr/lib/tcl8.6" \
        "$STAGE_CHROOT/usr/bin/tclsh8.6")
    [[ $output == 42 ]]
    [[ $(readlink "$STAGE_HOST/usr/bin/tclsh") == tclsh8.6 ]]
    [[ -s "$STAGE_HOST/usr/include/tcl.h" ]]
    [[ -d "$STAGE_HOST/usr/share/doc/tcl-8.6.16" ]]
    echo "TCL_STAGE_SMOKE=passed output=$output"
}

cleanup() {
    local status=$?
    trap - EXIT
    set +e
    for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do
        umount "${MOUNTS[$i]}" || status=1
    done
    if findmnt -rn -R "$LFS"; then
        echo "CLEANUP_FAILED: mounts remain below $LFS" >&2
        status=1
    else
        echo "CLEANUP_OK: no mounts remain below $LFS"
    fi
    if (( FINISHED )); then
        echo "STAGE_OK: $STAGE_HOST"
        echo "MANIFEST: $MANIFEST"
        echo "PREFLIGHT: $PREFLIGHT"
    else
        echo 'STAGE_INCOMPLETE: preserve build/stage/log for diagnosis' >&2
    fi
    exit "$status"
}
trap cleanup EXIT
trap 'status=$?; echo "FAILED line $LINENO status $status: $BASH_COMMAND" >&2; exit "$status"' ERR

[[ $EUID -eq 0 ]]
[[ -d "$LFS/etc" && -x "$LFS/usr/bin/bash" && -f "$SOURCE" && -f "$DOC_SOURCE" ]]
[[ -f "$CAPTURE_TOOL" && -f "$COMPARE_TOOL" ]]
[[ -z $(findmnt -rn -R "$LFS" || true) ]]
[[ ! -s /sys/block/nbd0/pid ]]
[[ $(md5sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_MD5" ]]
[[ $(sha256sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_SHA256" ]]
[[ $(md5sum "$DOC_SOURCE" | awk '{print $1}') == "$DOC_EXPECTED_MD5" ]]
[[ $(sha256sum "$DOC_SOURCE" | awk '{print $1}') == "$DOC_EXPECTED_SHA256" ]]
check_alp_invariants
grep -q '^tester:.*:101:101:' "$LFS/etc/passwd"
for target in "$LFS/dev" "$LFS/dev/pts" "$LFS/proc" "$LFS/sys" "$LFS/run"; do
    ! mountpoint -q "$target"
done

if [[ ${1:-} == --verify-stage-only ]]; then
    [[ -d "$BUILD/unix" && -d "$DOC_BUILD/html" ]]
    [[ -d "$STAGE_HOST" && -x "$STAGE_HOST/usr/bin/tclsh8.6" ]]
    [[ -f "$LOG" && -f "$MANIFEST" ]]
    exec >>"$LOG" 2>&1
    echo "STAGE_VERIFY_ONLY=$(date -Is) Builder=$(hostname)"
    chmod 0644 "$MANIFEST"
    tcl_smoke
    compare_rootfs
    check_alp_invariants
    [[ ! -s /sys/block/nbd0/pid ]]
    FINISHED=1
    exit 0
fi

[[ ! -e "$BUILD" && ! -e "$DOC_BUILD" && ! -e "$STAGE_HOST" ]]
[[ ! -e "$LOG" && ! -e "$MANIFEST" && ! -e "$PREFLIGHT" ]]
[[ -z $(pgrep -x make || true) && -z $(pgrep -x ninja || true) && -z $(pgrep -x cmake || true) ]]
mkdir -p /mnt/lfs/build /mnt/lfs/tmp/alp-logs
exec > >(tee -a "$LOG") 2>&1
echo "Builder=$(hostname) source=$(sha256sum "$SOURCE")"
echo "Source MD5: $(md5sum "$SOURCE")"
echo "Docs source=$(sha256sum "$DOC_SOURCE")"
echo "Docs MD5: $(md5sum "$DOC_SOURCE")"
echo "Pinned alp SHA-256: $ALP_SHA256"
df -h "$LFS"
mkdir -p "$BUILD" "$DOC_BUILD" "$STAGE_HOST"
tar -xf "$SOURCE" -C "$BUILD" --strip-components=1
tar -xf "$DOC_SOURCE" -C "$DOC_BUILD" --strip-components=1
chown -R 1001:1001 "$BUILD"

bind_mount() {
    local source=$1 target=$2
    if mountpoint -q "$target"; then
        echo "Refusing pre-existing mount: $target" >&2
        return 1
    fi
    mount --bind "$source" "$target"
    MOUNTS+=("$target")
}
bind_mount /dev "$LFS/dev"
bind_mount /dev/pts "$LFS/dev/pts"
bind_mount /proc "$LFS/proc"
bind_mount /sys "$LFS/sys"
bind_mount /run "$LFS/run"

chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
    HOME=/home/lfs TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
    /bin/bash --noprofile --norc -c '
        set -e
        cd /build/tcl-8.6.16-m04-r1
        SRCDIR=$(pwd)
        cd unix
        ./configure --prefix=/usr --mandir=/usr/share/man --disable-rpath
        make -j2
        sed -e "s|$SRCDIR/unix|/usr/lib|" -e "s|$SRCDIR|/usr/include|" -i tclConfig.sh
        sed -e "s|$SRCDIR/unix/pkgs/tdbc1.1.10|/usr/lib/tdbc1.1.10|" \
            -e "s|$SRCDIR/pkgs/tdbc1.1.10/generic|/usr/include|" \
            -e "s|$SRCDIR/pkgs/tdbc1.1.10/library|/usr/lib/tcl8.6|" \
            -e "s|$SRCDIR/pkgs/tdbc1.1.10|/usr/include|" \
            -i pkgs/tdbc1.1.10/tdbcConfig.sh
        sed -e "s|$SRCDIR/unix/pkgs/itcl4.3.2|/usr/lib/itcl4.3.2|" \
            -e "s|$SRCDIR/pkgs/itcl4.3.2/generic|/usr/include|" \
            -e "s|$SRCDIR/pkgs/itcl4.3.2|/usr/include|" \
            -i pkgs/itcl4.3.2/itclConfig.sh
        unset SRCDIR
    '
chown -R 101:101 "$BUILD"
chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
    HOME=/home/tester TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
    /bin/bash --noprofile --norc -c 'cd /build/tcl-8.6.16-m04-r1/unix && make test'

chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
    /bin/bash --noprofile --norc -c '
        set -e
        cd /build/tcl-8.6.16-m04-r1/unix
        make DESTDIR=/tmp/alp-m04-tcl-stage-r1 install
        chmod 644 /tmp/alp-m04-tcl-stage-r1/usr/lib/libtclstub8.6.a
        chmod u+w /tmp/alp-m04-tcl-stage-r1/usr/lib/libtcl8.6.so
        make DESTDIR=/tmp/alp-m04-tcl-stage-r1 install-private-headers
        ln -sfv tclsh8.6 /tmp/alp-m04-tcl-stage-r1/usr/bin/tclsh
        mv -v /tmp/alp-m04-tcl-stage-r1/usr/share/man/man3/Thread.3 \
            /tmp/alp-m04-tcl-stage-r1/usr/share/man/man3/Tcl_Thread.3
    '
mkdir -p "$STAGE_HOST/usr/share/doc/tcl-8.6.16"
cp -a "$DOC_BUILD/html/." "$STAGE_HOST/usr/share/doc/tcl-8.6.16/"

tcl_smoke
python3 "$CAPTURE_TOOL" \
    --stage "$STAGE_HOST" \
    --name tcl \
    --version 8.6.16 \
    --source-url https://downloads.sourceforge.net/tcl/tcl8.6.16-src.tar.gz \
    --source-sha256 "$EXPECTED_SHA256" \
    --output "$MANIFEST"
chmod 0644 "$MANIFEST"
compare_rootfs
check_alp_invariants
[[ ! -s /sys/block/nbd0/pid ]]
FINISHED=1
