#!/bin/bash
# alpbahOS live ISO builder (reproduces the M09 layout from the LFS rootfs).
#
# Run as root on the Fedora host:  sudo bash build-iso.sh --out <dir> [options]
#
# What it does:
#   1. Preflight: root, Fedora host, rootfs sane, host tools, rootfs live tools
#      (check-live-tools.sh), label matches grub.cfg and the alplive dracut module.
#   2. (optional, --make-initramfs) builds the alplive initramfs inside the rootfs
#      with dracut, using the options recorded in the M09 initramfs
#      (usr/lib/dracut/build-parameter.txt). Only this step writes into the rootfs,
#      and only a temporary file under /var/tmp that is removed again.
#   3. Makes LiveOS/squashfs.img from the rootfs with zstd, 1 MiB blocks, and the
#      excludes/pseudo-directories described in README.md. Then verifies the
#      result with unsquashfs -ll and fails if the modes or excludes are wrong.
#   4. Builds the ISO tree (boot/vmlinuz, boot/initramfs-live.img,
#      boot/grub/grub.cfg, LiveOS/squashfs.img) and runs grub2-mkrescue, which
#      writes an El Torito BIOS image and an EFI image (the M09 ISO had both).
#      UEFI boot is NOT tested by this script.
#   5. Writes <out>/alpbahos-live-<YYYYMMDD>.iso and <out>/SHA256SUMS.
#
# The rootfs is never written to except by the optional --make-initramfs step.
# Nothing is written under /mnt (hard rule for this project).
set -euo pipefail
# Fixed C locale: under tr_TR.UTF-8 the bracket range [A-Z] does not match "I" (found 2026-11-06).
export LC_ALL=C

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_MOD="$SELF_DIR/dracut-alplive"
GRUB_CFG_SRC="$SELF_DIR/grub.cfg"

# Defaults taken from the M09 ISO (sha256 of boot/vmlinuz equals the rootfs kernel).
ROOTFS=/mnt/lfs
OUT=""
LABEL=ALPBAH_LIVE
KERNEL=""
INITRAMFS=""
MAKE_INITRAMFS=0
SKIP_TOOL_CHECK=0
DRACUT_OMIT='dracut-systemd systemd-initrd systemd-journald systemd-sysusers systemd systemd-udevd systemd-tmpfiles systemd-hwdb systemd-networkd systemd-battery-check'
DEFAULT_KERNEL_NAME='vmlinuz-6.16.1-lfs-12.4-systemd'
DEFAULT_INITRAMFS_NAME='initramfs-live-6.16.1.img'

WORK=""
ISO_TREE=""
ISO_OUT=""
SUCCESS=0
OWNS_OUT=0
TMP_INITRAMFS_IN_ROOT=""

usage() {
    cat <<'EOF'
Usage: sudo bash build-iso.sh --out <dir> [options]

  --out <dir>          output directory (required; must not exist or be empty;
                       must not be under /mnt)
  --rootfs <dir>       LFS rootfs (default: /mnt/lfs; read-only use)
  --label <LABEL>      ISO volume id (default: ALPBAH_LIVE; must match grub.cfg
                       root=LABEL=<LABEL>)
  --kernel <path>      kernel image (default: <rootfs>/boot/vmlinuz-6.16.1-lfs-12.4-systemd)
  --initramfs <path>   alplive initramfs (default: <rootfs>/boot/initramfs-live-6.16.1.img)
  --make-initramfs     build the initramfs with chroot <rootfs> dracut instead of
                       using --initramfs (writes only a temp file in rootfs /var/tmp)
  --skip-tool-check    do not run check-live-tools.sh on the rootfs
  -h, --help           show this help
EOF
}

die() {
    echo "DURDU: $*" >&2
    exit 1
}

log() {
    echo "[build-iso] $*"
}

cleanup() {
    local rc=$?
    set +e
    if [ -n "$TMP_INITRAMFS_IN_ROOT" ] && [ -e "$TMP_INITRAMFS_IN_ROOT" ]; then
        rm -f "$TMP_INITRAMFS_IN_ROOT"
    fi
    # Only touch --out after this run has checked it was empty and created it.
    if [ "$OWNS_OUT" = 1 ] && [ "$SUCCESS" != 1 ]; then
        rm -rf "$OUT/iso" "$OUT/LiveOS" "$OUT/.work"
        [ -n "$ISO_OUT" ] && rm -f "$ISO_OUT"
        rm -f "$OUT/SHA256SUMS"
        echo "[build-iso] FAILED (rc=$rc): partial output removed from $OUT (logs kept in $OUT/build-logs)" >&2
    elif [ "$OWNS_OUT" = 1 ]; then
        rm -rf "$WORK" "$OUT/iso" "$OUT/LiveOS"
    fi
    exit "$rc"
}
trap cleanup EXIT
trap 'echo "[build-iso] error at line $LINENO" >&2' ERR

# ---------------------------------------------------------------- arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --rootfs) ROOTFS=${2:?--rootfs needs a value}; shift 2 ;;
        --out) OUT=${2:?--out needs a value}; shift 2 ;;
        --label) LABEL=${2:?--label needs a value}; shift 2 ;;
        --kernel) KERNEL=${2:?--kernel needs a value}; shift 2 ;;
        --initramfs) INITRAMFS=${2:?--initramfs needs a value}; shift 2 ;;
        --make-initramfs) MAKE_INITRAMFS=1; shift ;;
        --skip-tool-check) SKIP_TOOL_CHECK=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "unknown argument: $1" ;;
    esac
done

# ---------------------------------------------------------------- preflight
[ "$(id -u)" = 0 ] || die "must run as root (sudo bash build-iso.sh ...)"
grep -qx 'ID=fedora' /etc/os-release 2>/dev/null || die "host is not Fedora (/etc/os-release)"
[ -n "$OUT" ] || { usage >&2; die "--out is required"; }
[[ "$LABEL" =~ ^[A-Z0-9_]{1,32}$ ]] || die "--label must be 1-32 chars of A-Z, 0-9, _ (got: $LABEL)"

[ -d "$ROOTFS" ] || die "rootfs does not exist: $ROOTFS"
ROOT_REAL=$(readlink -f "$ROOTFS")
[ "$ROOT_REAL" != / ] || die "refusing to use / as rootfs"
[ -d "$ROOT_REAL/usr/bin" ] && [ -d "$ROOT_REAL/etc" ] || die "rootfs does not look like an LFS root: $ROOT_REAL"

if [ -e "$OUT" ]; then
    [ -d "$OUT" ] || die "--out exists and is not a directory: $OUT"
    [ -z "$(ls -A "$OUT")" ] || die "--out must be empty: $OUT"
fi
OUT_REAL=$(readlink -m "$OUT")
case "$OUT_REAL" in
    /mnt|/mnt/*) die "--out must not be under /mnt (project rule): $OUT_REAL" ;;
    "$ROOT_REAL"|"$ROOT_REAL"/*) die "--out must not be inside the rootfs: $OUT_REAL" ;;
esac

for t in mksquashfs unsquashfs xorriso grub2-mkrescue sha256sum; do
    command -v "$t" >/dev/null 2>&1 || die "host tool missing: $t (dnf install squashfs-tools xorriso grub2-tools-extra grub2-pc-modules grub2-efi-x64-modules)"
done

[ -f "$GRUB_CFG_SRC" ] || die "missing $GRUB_CFG_SRC"
grep -q "root=LABEL=$LABEL " "$GRUB_CFG_SRC" || die "grub.cfg does not contain 'root=LABEL=$LABEL' (label mismatch)"
grep -q "rootfstype=iso9660" "$GRUB_CFG_SRC" || die "grub.cfg does not contain rootfstype=iso9660"
grep -q 'alp.live' "$GRUB_CFG_SRC" || die "grub.cfg does not contain alp.live (alplive module switch)"
[ -f "$REPO_MOD/module-setup.sh" ] && [ -f "$REPO_MOD/alplive-pivot.sh" ] || die "missing dracut-alplive module in repo: $REPO_MOD"

if [ "$SKIP_TOOL_CHECK" = 0 ]; then
    /bin/sh "$SELF_DIR/check-live-tools.sh" "$ROOT_REAL" || die "rootfs live tools missing (see above); fix the rootfs or pass --skip-tool-check"
else
    log "tool check skipped (--skip-tool-check)"
fi

if [ "$MAKE_INITRAMFS" = 1 ]; then
    [ -z "$INITRAMFS" ] || die "--make-initramfs and --initramfs are mutually exclusive"
    mountpoint -q "$ROOT_REAL/proc" || die "--make-initramfs needs the chroot mounts (scripts/lfs-blfs/mount_lfs.sh): $ROOT_REAL/proc not mounted"
    for f in module-setup.sh alplive-pivot.sh; do
        cmp -s "$REPO_MOD/$f" "$ROOT_REAL/usr/lib/dracut/modules.d/90alplive/$f" \
            || die "rootfs dracut module 90alplive/$f differs from repo ($REPO_MOD/$f); install the repo module first"
    done
    KVER_LIST=$(ls -1 "$ROOT_REAL/lib/modules" 2>/dev/null || true)
    [ "$(printf '%s\n' "$KVER_LIST" | grep -c .)" = 1 ] || die "expected exactly one kernel version in $ROOT_REAL/lib/modules, found: $KVER_LIST"
    KVER=$KVER_LIST
    [ -d "$ROOT_REAL/var/tmp" ] || die "rootfs has no /var/tmp"
else
    KERNEL=${KERNEL:-$ROOT_REAL/boot/$DEFAULT_KERNEL_NAME}
    INITRAMFS=${INITRAMFS:-$ROOT_REAL/boot/$DEFAULT_INITRAMFS_NAME}
    [ -f "$KERNEL" ] || die "kernel not found: $KERNEL"
    [ -f "$INITRAMFS" ] || die "initramfs not found: $INITRAMFS (or use --make-initramfs)"
fi

# ---------------------------------------------------------------- setup
mkdir -p "$OUT"
OWNS_OUT=1
WORK="$OUT/.work"
ISO_TREE="$OUT/iso"
LOGS="$OUT/build-logs"
mkdir -p "$WORK" "$LOGS"
DATE=$(date +%Y%m%d)
ISO_OUT="$OUT/alpbahos-live-$DATE.iso"
[ ! -e "$ISO_OUT" ] || die "ISO already exists: $ISO_OUT"

log "rootfs=$ROOT_REAL out=$OUT label=$LABEL date=$DATE"

# ---------------------------------------------------------------- initramfs
if [ "$MAKE_INITRAMFS" = 1 ]; then
    log "building alplive initramfs in rootfs (kver $KVER) with dracut"
    TMP_INITRAMFS_IN_ROOT="$ROOT_REAL/var/tmp/alp-live-initramfs.$$.img"
    [ ! -e "$TMP_INITRAMFS_IN_ROOT" ] || die "temp file exists: $TMP_INITRAMFS_IN_ROOT"
    # Options as recorded in the M09 initramfs (usr/lib/dracut/build-parameter.txt).
    chroot "$ROOT_REAL" dracut --force --no-hostonly --no-kernel --add 'alplive' \
        --omit "$DRACUT_OMIT" "/var/tmp/$(basename "$TMP_INITRAMFS_IN_ROOT")" "$KVER" \
        > "$LOGS/10-dracut.log" 2>&1 || die "dracut failed (log: $LOGS/10-dracut.log)"
    cp "$TMP_INITRAMFS_IN_ROOT" "$WORK/initramfs-live.img"
    rm -f "$TMP_INITRAMFS_IN_ROOT"
    TMP_INITRAMFS_IN_ROOT=""
    INITRAMFS="$WORK/initramfs-live.img"
    KERNEL=${KERNEL:-$ROOT_REAL/boot/$DEFAULT_KERNEL_NAME}
    [ -f "$KERNEL" ] || die "kernel not found: $KERNEL"
fi

# ---------------------------------------------------------------- squashfs
log "writing squashfs (zstd, 1 MiB blocks)"
EXCL="$WORK/exclude.txt"
PSEUDO="$WORK/pseudo.txt"
# System directories are excluded as whole entries, so the pseudo definitions below
# create them with exact modes. mksquashfs does not change the mode of an existing
# source directory from a pseudo definition, and its wildcards do not cross '/'
# (so depth-specific patterns are used for history and secret files).
cat > "$EXCL" <<'EOF'
dev
proc
sys
run
tmp
mnt
media
blfs-work
sources
tools
root/m11-runner
usr/lib/live
var/cache/*
var/tmp/*
lost+found
test-secrets
*/test-secrets
*/*/test-secrets
home/*/.bash_history
root/.bash_history
EOF
# Directories created with exact modes (M11-FIX-02). /root keeps its rootfs mode
# (0750, as the LFS book creates it); it is checked below.
cat > "$PSEUDO" <<'EOF'
tmp d 1777 0 0
root d 0750 0 0
dev d 0755 0 0
proc d 0755 0 0
sys d 0755 0 0
run d 0755 0 0
mnt d 0755 0 0
media d 0755 0 0
EOF

mkdir -p "$OUT/LiveOS"
SQ_TMP="$OUT/LiveOS/squashfs.img"
mksquashfs "$ROOT_REAL" "$SQ_TMP" -comp zstd -b 1M -noappend -no-progress \
    -wildcards -ef "$EXCL" -pf "$PSEUDO" \
    -xattrs-exclude '^security\.selinux$' > "$LOGS/20-mksquashfs.log" 2>&1 \
    || die "mksquashfs failed (log: $LOGS/20-mksquashfs.log)"

# ---------------------------------------------------------------- squashfs verify
log "verifying squashfs directory modes and excludes"
LL="$WORK/squashfs-ll.txt"
unsquashfs -ll "$SQ_TMP" > "$LL" 2>/dev/null || die "unsquashfs -ll failed on $SQ_TMP"
check_dir() {
    local path=$1 want=$2 line mode owner
    line=$(awk -v p="squashfs-root/$path" '$NF == p' "$LL" | head -1)
    [ -n "$line" ] || die "squashfs missing directory /$path"
    mode=$(printf '%s\n' "$line" | awk '{print $1}')
    owner=$(printf '%s\n' "$line" | awk '{print $2}')
    [ "$mode" = "$want" ] || die "squashfs /$path mode is $mode, expected $want"
    [ "$owner" = root/root ] || die "squashfs /$path owner is $owner, expected root/root"
}
check_dir tmp     drwxrwxrwt
check_dir root    drwxr-x---
check_dir dev     drwxr-xr-x
check_dir proc    drwxr-xr-x
check_dir sys     drwxr-xr-x
check_dir run     drwxr-xr-x
for forbidden in 'blfs-work' 'sources' 'tools' 'root/m11-runner' 'usr/lib/live'; do
    if awk -v p="squashfs-root/$forbidden" '$NF == p || index($NF, p "/") == 1 {f=1} END{exit !f}' "$LL"; then
        die "squashfs still contains /$forbidden"
    fi
done
if grep -qE ' squashfs-root/[^ ]*test-secrets' "$LL"; then die "squashfs contains test-secrets"; fi
if grep -qE ' squashfs-root/([^ ]*/)?\.bash_history$' "$LL"; then die "squashfs contains a bash history"; fi
if grep -qE ' squashfs-root/(proc|sys|dev|run|tmp)/[^ ]+$' "$LL"; then die "squashfs contains files under proc/sys/dev/run/tmp"; fi
# The Fedora build host labels every file (security.selinux=...mnt_t); alpbahOS has no SELinux and
# the labels made rsync in the installer fail with exit 23 (2026-11-06). They are excluded above.
SQCHK=$(mktemp -d)
mount -o loop,ro "$SQ_TMP" "$SQCHK"
if getfattr -R -m '^security\.selinux$' -d "$SQCHK/usr/bin" 2>/dev/null | grep -q selinux; then
    umount "$SQCHK"; rmdir "$SQCHK"; die "squashfs still contains security.selinux xattrs"
fi
umount "$SQCHK"; rmdir "$SQCHK"
log "squashfs OK: /tmp 1777, /root 0750, /dev /proc /sys /run 0755; no blfs-work/sources/tools"

# ---------------------------------------------------------------- ISO tree
log "building ISO tree"
mkdir -p "$ISO_TREE/boot/grub" "$ISO_TREE/LiveOS"
mv "$SQ_TMP" "$ISO_TREE/LiveOS/squashfs.img"
rmdir "$OUT/LiveOS"
cp "$KERNEL" "$ISO_TREE/boot/vmlinuz"
cp "$INITRAMFS" "$ISO_TREE/boot/initramfs-live.img"
cp "$GRUB_CFG_SRC" "$ISO_TREE/boot/grub/grub.cfg"
rm -rf "$WORK/initramfs-live.img"

# ---------------------------------------------------------------- ISO image
log "running grub2-mkrescue (BIOS El Torito + EFI, hybrid MBR/GPT)"
grub2-mkrescue -o "$ISO_OUT" "$ISO_TREE" -volid "$LABEL" > "$LOGS/30-grub2-mkrescue.log" 2>&1 \
    || die "grub2-mkrescue failed (log: $LOGS/30-grub2-mkrescue.log)"
[ -s "$ISO_OUT" ] || die "ISO not produced: $ISO_OUT"

# Structural check only (read-only): volume id and both boot entries.
xorriso -indev "$ISO_OUT" -report_el_torito plain > "$LOGS/40-el-torito.log" 2>&1 || die "xorriso report failed"
grep -q "Volume id    : '$LABEL'" "$LOGS/40-el-torito.log" || die "ISO volume id is not $LABEL"
grep -q "El Torito boot img :   1  BIOS" "$LOGS/40-el-torito.log" || die "ISO has no BIOS El Torito entry"
grep -q "El Torito boot img :   2  UEFI" "$LOGS/40-el-torito.log" || die "ISO has no UEFI El Torito entry"

# ---------------------------------------------------------------- checksums
( cd "$OUT" && sha256sum "$(basename "$ISO_OUT")" > SHA256SUMS )

SUCCESS=1
rm -rf "$ISO_TREE"

echo
echo "==== build-iso summary ===="
echo "ISO:        $ISO_OUT ($(du -h "$ISO_OUT" | awk '{print $1}'))"
echo "SHA256SUMS: $OUT/SHA256SUMS"
echo "Logs:       $LOGS"
echo "Rootfs:     $ROOT_REAL (read-only use$( [ "$MAKE_INITRAMFS" = 1 ] && echo ', plus temp dracut file removed' ))"
echo "Kernel:     $KERNEL"
echo "Initramfs:  $INITRAMFS"
echo "Boot:       BIOS + UEFI El Torito entries present (structure only; not boot-tested)"
echo "Not verified here: boot in QEMU, UEFI boot, installer run from this ISO."
