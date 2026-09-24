#!/usr/bin/env bash
set -Eeuo pipefail

# LFS 12.4-systemd Attr 2.5.2 isolated stage. Draft only; do not merge rootfs.
LFS=/mnt/lfs
RUN_ID=20260924-r3
BUILD=/mnt/lfs/build/attr-2.5.2-m04-$RUN_ID
BUILD_CHROOT=/build/attr-2.5.2-m04-$RUN_ID
STAGE_HOST=/mnt/lfs/tmp/alp-m04-attr-stage-$RUN_ID
STAGE_CHROOT=/tmp/alp-m04-attr-stage-$RUN_ID
SOURCE=/mnt/lfs/sources/attr-2.5.2.tar.gz
LOG=/mnt/lfs/tmp/alp-logs/m04-attr-2.5.2-stage-$RUN_ID.log
MANIFEST=/mnt/lfs/tmp/alp-m04-attr-2.5.2-manifest-$RUN_ID.json
PREFLIGHT=/mnt/lfs/tmp/alp-m04-attr-2.5.2-preflight-$RUN_ID.log
SOURCE_URL=https://download.savannah.gnu.org/releases/attr/attr-2.5.2.tar.gz
# LFS MD5; upstream provides detached signatures but no primary SHA-256.
# Independent SHA-256 metadata: yoebuild metadata format (non-primary source).
# https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter03/packages.html
# https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/attr.html
# https://docs.yoebuild.org/metadata-format.html
EXPECTED_MD5=227043ec2f6ca03c0948df5517f9c927
EXPECTED_SHA256=39bf67452fa41d0948c2197601053f48b3d78a029389734332a6309a680c6c87
ALP_SHA256=7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CAPTURE_TOOL="$SCRIPT_DIR/capture-package-manifest.py"
COMPARE_TOOL="$SCRIPT_DIR/compare-package-manifest.py"
MOUNTS=(); FINISHED=0
cleanup() {
  local status=$?; trap - EXIT; set +e
  for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}" || status=1; done
  if findmnt -rn -R "$LFS"; then echo "CLEANUP_FAILED: mounts remain below $LFS" >&2; status=1; fi
  if (( FINISHED )); then echo "STAGE_OK: $STAGE_HOST"; else echo 'STAGE_INCOMPLETE: preserve files for diagnosis' >&2; status=1; fi
  exit "$status"
}
trap cleanup EXIT
trap 'status=$?; echo "FAILED line $LINENO status $status: $BASH_COMMAND" >&2; exit "$status"' ERR
assert_alp_and_empty_db() {
  [[ $(sha256sum "$LFS/usr/lib/alp/alp.py" | awk '{print $1}') == "$ALP_SHA256" ]]
  python3 - "$LFS/var/lib/alp/db.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f: db=json.load(f)
if db.get("schema_version") != 1 or db.get("packages") != {}: raise SystemExit("expected pinned Alp and empty DB")
PY
}
[[ $EUID -eq 0 && -d "$LFS/etc" && -x "$LFS/usr/bin/bash" && -f "$SOURCE" ]]
[[ -f "$CAPTURE_TOOL" && -f "$COMPARE_TOOL" ]]
[[ ! -e "$BUILD" && ! -e "$STAGE_HOST" && ! -e "$LOG" && ! -e "$MANIFEST" && ! -e "$PREFLIGHT" ]]
[[ -z $(findmnt -rn -R "$LFS" || true) && ! -s /sys/block/nbd0/pid ]]
[[ "$RUN_ID" =~ ^20260924-r[0-9]+$ ]]
[[ "$BUILD" == "/mnt/lfs/build/attr-2.5.2-m04-$RUN_ID" && "$BUILD_CHROOT" == "/build/attr-2.5.2-m04-$RUN_ID" ]]
[[ "$STAGE_HOST" == "/mnt/lfs/tmp/alp-m04-attr-stage-$RUN_ID" && "$STAGE_CHROOT" == "/tmp/alp-m04-attr-stage-$RUN_ID" ]]
for workspace_path in "$BUILD" "$BUILD_CHROOT" "$STAGE_HOST" "$STAGE_CHROOT" "$LOG" "$MANIFEST" "$PREFLIGHT"; do
  [[ "$workspace_path" == *"$RUN_ID"* ]] || { echo "stale workspace path for $RUN_ID: $workspace_path" >&2; exit 1; }
done
for process in make ninja meson; do if pgrep -x "$process" >/dev/null; then echo "Refusing concurrent build: $process" >&2; exit 1; fi; done
assert_alp_and_empty_db
[[ $(md5sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_MD5" ]]
[[ $(sha256sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_SHA256" ]]
available_kib=$(df -Pk "$LFS" | awk 'NR == 2 {print $4}')
[[ "$available_kib" =~ ^[0-9]+$ && $available_kib -ge 524288 ]]
command -v setfacl >/dev/null && command -v getfacl >/dev/null
mkdir -p /mnt/lfs/build /mnt/lfs/tmp/alp-logs
mkdir -p "$BUILD" "$STAGE_HOST"
# Verify the actual build filesystem provides user xattrs and ACL operations.
python3 - "$BUILD" <<'PY'
import os, sys
p=os.path.join(sys.argv[1], ".attr-fs-probe")
fd=os.open(p, os.O_CREAT|os.O_EXCL|os.O_WRONLY, 0o600); os.close(fd)
try:
    os.setxattr(p, b"user.alp_m04_probe", b"ok")
    if os.getxattr(p, b"user.alp_m04_probe") != b"ok": raise RuntimeError("xattr readback mismatch")
finally: os.unlink(p)
PY
acl_probe="$BUILD/.acl-fs-probe"
[[ ! -e "$acl_probe" ]]
: > "$acl_probe"
if setfacl -m u:1001:r-- "$acl_probe" && getfacl -cpn "$acl_probe" | grep -Fq 'user:1001:r--'; then :; else rm -f "$acl_probe"; echo 'filesystem ACL probe failed' >&2; exit 1; fi
rm -f "$acl_probe"
exec > >(tee -a "$LOG") 2>&1
echo "Builder=$(hostname) source=$(sha256sum "$SOURCE")"; echo 'filesystem_probe=xattr+POSIX_ACL passed'
echo 'LFS_REQUIRED_PATCH=none; install_mode=DESTDIR; rootfs_merge=forbidden'; df -h "$LFS"
tar -xzf "$SOURCE" -C "$BUILD" --strip-components=1
mkdir -p "$BUILD/tmp"; chown -R 1001:1001 "$BUILD"
bind_mount() { local src=$1 dst=$2; if mountpoint -q "$dst"; then echo "Refusing pre-existing mount: $dst" >&2; return 1; fi; mount --bind "$src" "$dst"; MOUNTS+=("$dst"); }
bind_mount /dev "$LFS/dev"; bind_mount /dev/pts "$LFS/dev/pts"; bind_mount /proc "$LFS/proc"; bind_mount /sys "$LFS/sys"; bind_mount /run "$LFS/run"
# LFS 8.24 exact configure/make/check recipe; tests require xattr-capable FS.
chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i HOME=/home/lfs TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 TMPDIR="$BUILD_CHROOT/tmp" /bin/bash --noprofile --norc -c "
  cd '$BUILD_CHROOT'
  ./configure --prefix=/usr --disable-static --sysconfdir=/etc --docdir=/usr/share/doc/attr-2.5.2
  make
  set -o pipefail
  if make check 2>&1 | tee attr-check-log; then :; else status=\$?; cat attr-check-log >&2; exit \"\$status\"; fi
"
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c "cd '$BUILD_CHROOT' && make DESTDIR='$STAGE_CHROOT' install"
[[ -x "$STAGE_HOST/usr/bin/attr" && -x "$STAGE_HOST/usr/bin/getfattr" && -x "$STAGE_HOST/usr/bin/setfattr" ]]
[[ -s "$STAGE_HOST/usr/lib/libattr.so" || -L "$STAGE_HOST/usr/lib/libattr.so" ]]
[[ -d "$STAGE_HOST/usr/share/doc/attr-2.5.2" ]]
probe="$BUILD/attr-stage-smoke"; : > "$probe"
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib" /bin/bash --noprofile --norc -c "
  '$STAGE_CHROOT/usr/bin/setfattr' -n user.alp_stage_probe -v ok '$BUILD_CHROOT/attr-stage-smoke'
  '$STAGE_CHROOT/usr/bin/getfattr' --only-values -n user.alp_stage_probe '$BUILD_CHROOT/attr-stage-smoke' | grep -qx ok
"
rm -f "$probe"
assert_alp_and_empty_db; [[ ! -s /sys/block/nbd0/pid ]]
{ echo 'package=attr version=2.5.2'; echo "source_url=$SOURCE_URL"; echo "source_md5=$EXPECTED_MD5"; echo "source_sha256=$EXPECTED_SHA256"; echo 'critical_tests=make check passed on xattr-capable filesystem'; echo 'install_mode=DESTDIR; rootfs_merge=forbidden'; } > "$PREFLIGHT"
python3 "$CAPTURE_TOOL" --stage "$STAGE_HOST" --name attr --version 2.5.2 --source-url "$SOURCE_URL" --source-sha256 "$EXPECTED_SHA256" --output "$MANIFEST" | tee -a "$PREFLIGHT"
if python3 "$COMPARE_TOOL" --manifest "$MANIFEST" --root "$LFS" >> "$PREFLIGHT" 2>&1; then compare_status=0; else compare_status=$?; fi
case "$compare_status" in 0) echo 'ROOTFS_PREFLIGHT=all staged paths match' | tee -a "$PREFLIGHT" ;; 1) echo 'ROOTFS_PREFLIGHT=staged paths differ; review before adoption' | tee -a "$PREFLIGHT" ;; *) echo "ROOTFS_PREFLIGHT=comparator error $compare_status" | tee -a "$PREFLIGHT"; exit "$compare_status" ;; esac
cat "$PREFLIGHT"; assert_alp_and_empty_db; [[ ! -s /sys/block/nbd0/pid ]]; FINISHED=1
