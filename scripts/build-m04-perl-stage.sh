#!/usr/bin/env bash
set -Eeuo pipefail

# LFS 12.4-systemd Perl-5.42.0 isolated package stage. Run on the Builder.

LFS=/mnt/lfs
BUILD=/mnt/lfs/build/perl-5.42.0-m04-r1
STAGE_HOST=/mnt/lfs/tmp/alp-m04-perl-stage-r1
STAGE_CHROOT=/tmp/alp-m04-perl-stage-r1
SOURCE=/mnt/lfs/sources/perl-5.42.0.tar.xz
LOG=/mnt/lfs/tmp/alp-logs/m04-perl-5.42.0-stage-20260924-r1.log
ALP_SHA256=7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132
EXPECTED_MD5=7a6950a9f12d01eb96a9d2ed2f4e0072
EXPECTED_SHA256=73cf6cc1ea2b2b1c110a18c14bbbc73a362073003893ffcedc26d22ebdbdd0c3
MOUNTS=()
FINISHED=0

cleanup() {
    local status=$?
    trap - EXIT
    set +e
    for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}"; done
    if findmnt -rn -R "$LFS"; then
        echo "CLEANUP_FAILED: mounts remain below $LFS" >&2
        status=1
    else
        echo "CLEANUP_OK: no mounts remain below $LFS"
    fi
    if (( FINISHED )); then echo "STAGE_OK: $STAGE_HOST"; else echo 'STAGE_INCOMPLETE: preserve build/stage/log for diagnosis' >&2; fi
    exit "$status"
}
trap cleanup EXIT
trap 'status=$?; echo "FAILED line $LINENO status $status: $BASH_COMMAND" >&2; exit "$status"' ERR

[[ $EUID -eq 0 ]]
[[ -d "$LFS/etc" && -x "$LFS/usr/bin/bash" && -f "$SOURCE" ]]
[[ -z $(findmnt -rn -R "$LFS" || true) ]]
[[ ! -s /sys/block/nbd0/pid ]]
[[ $(md5sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_MD5" ]]
[[ $(sha256sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_SHA256" ]]
[[ $(sha256sum "$LFS/usr/lib/alp/alp.py" | awk '{print $1}') == "$ALP_SHA256" ]]
grep -q '"packages": {}' "$LFS/var/lib/alp/db.json"
grep -q '^tester:' "$LFS/etc/passwd"

if [[ ${1:-} == --verify-stage-only ]]; then
    [[ -d "$BUILD" && -d "$STAGE_HOST" && -f "$LOG" ]]
    exec >>"$LOG" 2>&1
    echo "STAGE_VERIFY_ONLY=$(date -Is) Builder=$(hostname)"
    chroot "$LFS" /usr/bin/env -i \
        PATH=/usr/bin:/usr/sbin:/bin:/sbin \
        LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib/perl5/5.42/core_perl/CORE:$STAGE_CHROOT/usr/lib" \
        PERL5LIB="$STAGE_CHROOT/usr/lib/perl5/5.42/core_perl:$STAGE_CHROOT/usr/lib/perl5/5.42/site_perl:$STAGE_CHROOT/usr/lib/perl5/5.42/vendor_perl" \
        "$STAGE_CHROOT/usr/bin/perl" -e 'use Config; print "perl=$^V usedl=$Config{usedl} threads=$Config{usethreads}\n"; use threads; print "threads=loaded\n";'
    [[ -x "$STAGE_HOST/usr/bin/perl" && -e "$STAGE_HOST/usr/lib/perl5/5.42/core_perl/Config.pm" ]]
    echo 'PERL_STAGE_SMOKE=passed'
    [[ $(sha256sum "$LFS/usr/lib/alp/alp.py" | awk '{print $1}') == "$ALP_SHA256" ]]
    grep -q '"packages": {}' "$LFS/var/lib/alp/db.json"
    [[ ! -s /sys/block/nbd0/pid ]]
    FINISHED=1
    exit 0
fi

[[ ! -e "$BUILD" && ! -e "$STAGE_HOST" && ! -e "$LOG" ]]
[[ -z $(pgrep -x make || true) && -z $(pgrep -x ninja || true) && -z $(pgrep -x cmake || true) ]]

mkdir -p /mnt/lfs/build /mnt/lfs/tmp/alp-logs
exec > >(tee -a "$LOG") 2>&1
echo "Builder=$(hostname) source=$(sha256sum "$SOURCE")"
free -h
df -h "$LFS"
[[ ! -s /sys/block/nbd0/pid ]]
mkdir -p "$BUILD" "$STAGE_HOST"
tar -xf "$SOURCE" -C "$BUILD" --strip-components=1
chown -R 1001:1001 "$BUILD"

bind_mount() {
    local source=$1 target=$2
    if /usr/bin/mountpoint -q "$target"; then echo "Refusing pre-existing mount: $target" >&2; return 1; fi
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
    BUILD_ZLIB=False BUILD_BZIP2=0 \
    /bin/bash --noprofile --norc -c '
        cd /build/perl-5.42.0-m04-r1
        sh Configure -des \
            -D prefix=/usr \
            -D vendorprefix=/usr \
            -D privlib=/usr/lib/perl5/5.42/core_perl \
            -D archlib=/usr/lib/perl5/5.42/core_perl \
            -D sitelib=/usr/lib/perl5/5.42/site_perl \
            -D sitearch=/usr/lib/perl5/5.42/site_perl \
            -D vendorlib=/usr/lib/perl5/5.42/vendor_perl \
            -D vendorarch=/usr/lib/perl5/5.42/vendor_perl \
            -D man1dir=/usr/share/man/man1 \
            -D man3dir=/usr/share/man/man3 \
            -D pager="/usr/bin/less -isR" \
            -D useshrplib \
            -D usethreads
        make -j2
    '
chown -R 101:101 "$BUILD"
chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
    HOME=/home/tester TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
    /bin/bash --noprofile --norc -c 'cd /build/perl-5.42.0-m04-r1 && TEST_JOBS=2 make test_harness'
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
    /bin/bash --noprofile --norc -c '
        cd /build/perl-5.42.0-m04-r1
        make DESTDIR=/tmp/alp-m04-perl-stage-r1 install
    '

chroot "$LFS" /usr/bin/env -i \
    PATH=/usr/bin:/usr/sbin:/bin:/sbin \
    LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib/perl5/5.42/core_perl/CORE:$STAGE_CHROOT/usr/lib" \
    PERL5LIB="$STAGE_CHROOT/usr/lib/perl5/5.42/core_perl:$STAGE_CHROOT/usr/lib/perl5/5.42/site_perl:$STAGE_CHROOT/usr/lib/perl5/5.42/vendor_perl:$STAGE_CHROOT/usr/lib/perl5/5.42/core_perl" \
    "$STAGE_CHROOT/usr/bin/perl" -e 'use Config; use threads; print "$^V threads=$Config{usethreads}\n";'
[[ -x "$STAGE_HOST/usr/bin/perl" && -e "$STAGE_HOST/usr/lib/perl5/5.42/core_perl/Config.pm" ]]
echo 'PERL_STAGE_SMOKE=passed'
[[ $(sha256sum "$LFS/usr/lib/alp/alp.py" | awk '{print $1}') == "$ALP_SHA256" ]]
grep -q '"packages": {}' "$LFS/var/lib/alp/db.json"
[[ ! -s /sys/block/nbd0/pid ]]
FINISHED=1
