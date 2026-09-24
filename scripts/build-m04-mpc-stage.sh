#!/usr/bin/env bash
set -Eeuo pipefail

# LFS 12.4-systemd MPC 1.3.1 isolated stage. Draft only; review before use.
# GMP and MPFR inputs must be independently reviewed staged manifests.
LFS=/mnt/lfs
BUILD=/mnt/lfs/build/mpc-1.3.1-m04-r1
STAGE_HOST=/mnt/lfs/tmp/alp-m04-mpc-stage-r1
STAGE_CHROOT=/tmp/alp-m04-mpc-stage-r1
GMP_STAGE_HOST=/mnt/lfs/tmp/alp-m04-gmp-stage-r1
GMP_STAGE_CHROOT=/tmp/alp-m04-gmp-stage-r1
MPFR_STAGE_HOST=/mnt/lfs/tmp/alp-m04-mpfr-stage-r1
MPFR_STAGE_CHROOT=/tmp/alp-m04-mpfr-stage-r1
GMP_MANIFEST=/mnt/lfs/tmp/alp-m04-gmp-6.3.0-manifest-20260924-r1.json
MPFR_MANIFEST=/mnt/lfs/tmp/alp-m04-mpfr-4.2.2-manifest-20260924-r1.json
EXPECTED_GMP_MANIFEST_SHA256=5e68e60e1fb1032940b25e5bd565a36e14bb0c42a6fc2a88af18ebb356f06e62
EXPECTED_MPFR_MANIFEST_SHA256=f26511ca6cd5f4e9eca631dc01bc78429ee576ec35c6911c05b98965ce361582
SOURCE=/mnt/lfs/sources/mpc-1.3.1.tar.gz
LOG=/mnt/lfs/tmp/alp-logs/m04-mpc-1.3.1-stage-20260924-r1.log
MANIFEST=/mnt/lfs/tmp/alp-m04-mpc-1.3.1-manifest-20260924-r1.json
PREFLIGHT=/mnt/lfs/tmp/alp-m04-mpc-1.3.1-preflight-20260924-r1.log
SOURCE_URL=https://ftp.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz
# LFS package-list MD5. MPC upstream distributes a detached signature, not a
# primary SHA-256 checksum; the SHA below is an independent Buildroot cross-check.
# https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter03/packages.html
# https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/mpc.html
# https://lists.buildroot.org/pipermail/buildroot/2024-March/750400.html
EXPECTED_MD5=5c9bc658c9fd0f940e8e3e0f09530c62
EXPECTED_SHA256=ab642492f5cf882b74aa0cb730cd410a81edcdbec895183ce930e706c1c759b8
GMP_SOURCE_SHA256=a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898
MPFR_SOURCE_SHA256=b67ba0383ef7e8a8563734e2e889ef5ec3c3b898a01d00fa0a6869ad81c6ce01
ALP_SHA256=7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CAPTURE_TOOL="$SCRIPT_DIR/capture-package-manifest.py"
COMPARE_TOOL="$SCRIPT_DIR/compare-package-manifest.py"
MOUNTS=()
FINISHED=0

cleanup() {
    local status=$?
    trap - EXIT
    set +e
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
with open(sys.argv[1], encoding="utf-8") as stream: db = json.load(stream)
if db.get("schema_version") != 1 or db.get("packages") != {}:
    raise SystemExit("refusing: expected pinned Alp with an empty schema-1 DB")
PY
}
verify_dependency() {
    local manifest_file=$1 expected_name=$2 expected_version=$3 expected_source=$4 expected_manifest=$5
    [[ "$expected_manifest" =~ ^[0-9a-f]{64}$ ]] || { echo "manifest review gate not pinned: $manifest_file" >&2; return 1; }
    [[ -s "$manifest_file" ]]
    [[ $(sha256sum "$manifest_file" | awk '{print $1}') == "$expected_manifest" ]]
    python3 - "$manifest_file" "$expected_name" "$expected_version" "$expected_source" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as stream: m = json.load(stream)
p = m.get("package", {}); s = p.get("source", {})
if (p.get("name"), p.get("version"), s.get("sha256")) != (sys.argv[2], sys.argv[3], sys.argv[4]):
    raise SystemExit(f"dependency manifest identity/source mismatch: {sys.argv[1]}")
PY
}

[[ $EUID -eq 0 ]]
[[ -d "$LFS/etc" && -x "$LFS/usr/bin/bash" && -f "$SOURCE" ]]
[[ -f "$CAPTURE_TOOL" && -f "$COMPARE_TOOL" ]]
[[ -d "$GMP_STAGE_HOST/usr/include" && -s "$GMP_STAGE_HOST/usr/include/gmp.h" ]]
[[ -s "$GMP_STAGE_HOST/usr/lib/libgmp.so" || -L "$GMP_STAGE_HOST/usr/lib/libgmp.so" ]]
[[ -d "$MPFR_STAGE_HOST/usr/include" && -s "$MPFR_STAGE_HOST/usr/include/mpfr.h" ]]
[[ -s "$MPFR_STAGE_HOST/usr/lib/libmpfr.so" || -L "$MPFR_STAGE_HOST/usr/lib/libmpfr.so" ]]
verify_dependency "$GMP_MANIFEST" gmp 6.3.0 "$GMP_SOURCE_SHA256" "$EXPECTED_GMP_MANIFEST_SHA256"
verify_dependency "$MPFR_MANIFEST" mpfr 4.2.2 "$MPFR_SOURCE_SHA256" "$EXPECTED_MPFR_MANIFEST_SHA256"
[[ ! -e "$BUILD" && ! -e "$STAGE_HOST" && ! -e "$LOG" && ! -e "$MANIFEST" && ! -e "$PREFLIGHT" ]]
[[ -z $(findmnt -rn -R "$LFS" || true) && ! -s /sys/block/nbd0/pid ]]
for process in make ninja meson; do if pgrep -x "$process" >/dev/null; then echo "Refusing concurrent build: $process" >&2; exit 1; fi; done
assert_alp_and_empty_db
[[ $(md5sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_MD5" ]]
[[ $(sha256sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_SHA256" ]]
available_kib=$(df -Pk "$LFS" | awk 'NR == 2 {print $4}')
[[ "$available_kib" =~ ^[0-9]+$ && $available_kib -ge 524288 ]]

# Both dependency stages must exactly match their reviewed, pinned manifests
# before MPC configure or build begins.
: > "$PREFLIGHT"
{
  echo "gmp_manifest_sha256=$EXPECTED_GMP_MANIFEST_SHA256"
  echo "mpfr_manifest_sha256=$EXPECTED_MPFR_MANIFEST_SHA256"
} >> "$PREFLIGHT"
if python3 "$COMPARE_TOOL" --manifest "$GMP_MANIFEST" --root "$GMP_STAGE_HOST" >> "$PREFLIGHT" 2>&1; then gmp_status=0; else gmp_status=$?; fi
echo "GMP_STAGE_MANIFEST_COMPARE_EXIT=$gmp_status" | tee -a "$PREFLIGHT"
if (( gmp_status != 0 )); then echo 'Refusing MPC configure: staged GMP differs from its pinned manifest' >&2; exit "$gmp_status"; fi
if python3 "$COMPARE_TOOL" --manifest "$MPFR_MANIFEST" --root "$MPFR_STAGE_HOST" >> "$PREFLIGHT" 2>&1; then mpfr_status=0; else mpfr_status=$?; fi
echo "MPFR_STAGE_MANIFEST_COMPARE_EXIT=$mpfr_status" | tee -a "$PREFLIGHT"
if (( mpfr_status != 0 )); then echo 'Refusing MPC configure: staged MPFR differs from its pinned manifest' >&2; exit "$mpfr_status"; fi

mkdir -p /mnt/lfs/build /mnt/lfs/tmp/alp-logs
exec > >(tee -a "$LOG") 2>&1
echo "MPC source=$(sha256sum "$SOURCE") GMP_MANIFEST=$EXPECTED_GMP_MANIFEST_SHA256 MPFR_MANIFEST=$EXPECTED_MPFR_MANIFEST_SHA256"
echo 'LFS_REQUIRED_PATCH=none; install_mode=DESTDIR; rootfs_merge=forbidden'
mkdir -p "$BUILD" "$STAGE_HOST"
tar -xzf "$SOURCE" -C "$BUILD" --strip-components=1
mkdir -p "$BUILD/tmp"
chown -R 1001:1001 "$BUILD"
bind_mount() { local src=$1 dst=$2; if mountpoint -q "$dst"; then echo "Refusing pre-existing mount: $dst" >&2; return 1; fi; mount --bind "$src" "$dst"; MOUNTS+=("$dst"); }
bind_mount /dev "$LFS/dev"; bind_mount /dev/pts "$LFS/dev/pts"; bind_mount /proc "$LFS/proc"; bind_mount /sys "$LFS/sys"; bind_mount /run "$LFS/run"

# LFS 8.23 recipe; dependency include/lib/pkg-config paths are explicitly staged.
chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
  HOME=/home/lfs TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
  TMPDIR=/build/mpc-1.3.1-m04-r1/tmp TMP=/build/mpc-1.3.1-m04-r1/tmp TEMP=/build/mpc-1.3.1-m04-r1/tmp \
  GMP_STAGE="$GMP_STAGE_CHROOT" MPFR_STAGE="$MPFR_STAGE_CHROOT" \
  CPPFLAGS="-I$GMP_STAGE_CHROOT/usr/include -I$MPFR_STAGE_CHROOT/usr/include" \
  LDFLAGS="-L$MPFR_STAGE_CHROOT/usr/lib -L$GMP_STAGE_CHROOT/usr/lib" \
  LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib:$MPFR_STAGE_CHROOT/usr/lib:$GMP_STAGE_CHROOT/usr/lib" \
  LD_PRELOAD="$GMP_STAGE_CHROOT/usr/lib/libgmp.so.10.5.0:$MPFR_STAGE_CHROOT/usr/lib/libmpfr.so.6.2.2" \
  PKG_CONFIG_PATH="$MPFR_STAGE_CHROOT/usr/lib/pkgconfig:$GMP_STAGE_CHROOT/usr/lib/pkgconfig" \
  /bin/bash --noprofile --norc -c '
    cd /build/mpc-1.3.1-m04-r1
    ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/mpc-1.3.1
    make
    make html
    set -o pipefail
    if make check 2>&1 | tee mpc-check-log; then :; else status=$?; cat mpc-check-log >&2; exit "$status"; fi
  '
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c '
  cd /build/mpc-1.3.1-m04-r1
  make DESTDIR=/tmp/alp-m04-mpc-stage-r1 install
  make DESTDIR=/tmp/alp-m04-mpc-stage-r1 install-html
'
cat > "$BUILD/mpc-stage-smoke.c" <<'EOF'
#include <mpc.h>
int main(void) { mpc_t z; mpc_init2(z, 128); mpc_set_d_d(z, 2.0, 3.0, MPC_RNDNN); mpc_mul(z, z, z, MPC_RNDNN); int bad = mpfr_cmp_d(mpc_realref(z), -5.0) != 0 || mpfr_cmp_d(mpc_imagref(z), 12.0) != 0; mpc_clear(z); return bad; }
EOF
chown 1001:1001 "$BUILD/mpc-stage-smoke.c"
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c '
  gcc -I/tmp/alp-m04-mpc-stage-r1/usr/include -I/tmp/alp-m04-mpfr-stage-r1/usr/include -I/tmp/alp-m04-gmp-stage-r1/usr/include /build/mpc-1.3.1-m04-r1/mpc-stage-smoke.c -L/tmp/alp-m04-mpc-stage-r1/usr/lib -L/tmp/alp-m04-mpfr-stage-r1/usr/lib -L/tmp/alp-m04-gmp-stage-r1/usr/lib -lmpc -lmpfr -lgmp -o /build/mpc-1.3.1-m04-r1/mpc-stage-smoke
  LD_PRELOAD=/tmp/alp-m04-gmp-stage-r1/usr/lib/libgmp.so.10.5.0:/tmp/alp-m04-mpfr-stage-r1/usr/lib/libmpfr.so.6.2.2 \
  LD_LIBRARY_PATH=/tmp/alp-m04-mpc-stage-r1/usr/lib:/tmp/alp-m04-mpfr-stage-r1/usr/lib:/tmp/alp-m04-gmp-stage-r1/usr/lib /build/mpc-1.3.1-m04-r1/mpc-stage-smoke
'
[[ -s "$STAGE_HOST/usr/lib/libmpc.so" || -L "$STAGE_HOST/usr/lib/libmpc.so" ]]
[[ -d "$STAGE_HOST/usr/share/doc/mpc-1.3.1" ]]
assert_alp_and_empty_db; [[ ! -s /sys/block/nbd0/pid ]]
{
  echo 'package=mpc version=1.3.1'; echo "source_url=$SOURCE_URL"; echo "source_md5=$EXPECTED_MD5"; echo "source_sha256=$EXPECTED_SHA256"
  echo "gmp_manifest_sha256=$EXPECTED_GMP_MANIFEST_SHA256"; echo "mpfr_manifest_sha256=$EXPECTED_MPFR_MANIFEST_SHA256"
  echo 'critical_tests=make check passed'; echo 'install_mode=DESTDIR; rootfs_merge=forbidden'
} >> "$PREFLIGHT"
python3 "$CAPTURE_TOOL" --stage "$STAGE_HOST" --name mpc --version 1.3.1 --source-url "$SOURCE_URL" --source-sha256 "$EXPECTED_SHA256" --output "$MANIFEST" | tee -a "$PREFLIGHT"
if python3 "$COMPARE_TOOL" --manifest "$MANIFEST" --root "$LFS" >> "$PREFLIGHT" 2>&1; then compare_status=0; else compare_status=$?; fi
case "$compare_status" in 0) echo 'ROOTFS_PREFLIGHT=all staged paths match' | tee -a "$PREFLIGHT" ;; 1) echo 'ROOTFS_PREFLIGHT=staged paths differ; review before adoption' | tee -a "$PREFLIGHT" ;; *) echo "ROOTFS_PREFLIGHT=comparator error $compare_status" | tee -a "$PREFLIGHT"; exit "$compare_status" ;; esac
cat "$PREFLIGHT"; assert_alp_and_empty_db; [[ ! -s /sys/block/nbd0/pid ]]; FINISHED=1
