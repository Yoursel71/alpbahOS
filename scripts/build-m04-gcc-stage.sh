#!/usr/bin/env bash
set -Eeuo pipefail

# LFS 12.4-systemd GCC 15.2.0 isolated stage. Run as root on the Builder.
# All package installs go to DESTDIR; this script never merges into /mnt/lfs.
LFS=/mnt/lfs
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)-$$}
[[ "$RUN_ID" =~ ^[A-Za-z0-9._-]{1,48}$ ]] || { echo 'invalid RUN_ID' >&2; exit 2; }
BUILD="$LFS/build/gcc-15.2.0-m04-$RUN_ID"
BUILD_CHROOT="/build/gcc-15.2.0-m04-$RUN_ID"
STAGE_HOST="$LFS/tmp/alp-m04-gcc-stage-$RUN_ID"
STAGE_CHROOT="/tmp/alp-m04-gcc-stage-$RUN_ID"
SOURCE="$LFS/sources/gcc-15.2.0.tar.xz"
SOURCE_URL=https://ftp.gnu.org/gnu/gcc/gcc-15.2.0/gcc-15.2.0.tar.xz
EXPECTED_MD5=b861b092bf1af683c46a8aa2e689a6fd
EXPECTED_SHA256=438fd996826b0c82485a29da03a72d71d6e3541a83ec702df4271f6fe025d24e
GMP_SOURCE_URL=https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz
MPFR_SOURCE_URL=https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.2.tar.xz
MPC_SOURCE_URL=https://ftp.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz

GMP_STAGE_HOST="$LFS/tmp/alp-m04-gmp-stage-r1"; GMP_STAGE_CHROOT=/tmp/alp-m04-gmp-stage-r1
GMP_MANIFEST="$LFS/tmp/alp-m04-gmp-6.3.0-manifest-20260924-r1.json"
GMP_MANIFEST_SHA256=5e68e60e1fb1032940b25e5bd565a36e14bb0c42a6fc2a88af18ebb356f06e62
GMP_SOURCE_SHA256=a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898
MPFR_STAGE_HOST="$LFS/tmp/alp-m04-mpfr-stage-r1"; MPFR_STAGE_CHROOT=/tmp/alp-m04-mpfr-stage-r1
MPFR_MANIFEST="$LFS/tmp/alp-m04-mpfr-4.2.2-manifest-20260924-r1.json"
MPFR_MANIFEST_SHA256=f26511ca6cd5f4e9eca631dc01bc78429ee576ec35c6911c05b98965ce361582
MPFR_SOURCE_SHA256=b67ba0383ef7e8a8563734e2e889ef5ec3c3b898a01d00fa0a6869ad81c6ce01
MPC_STAGE_HOST="$LFS/tmp/alp-m04-mpc-stage-r1"; MPC_STAGE_CHROOT=/tmp/alp-m04-mpc-stage-r1
MPC_MANIFEST="$LFS/tmp/alp-m04-mpc-1.3.1-manifest-20260924-r1.json"
MPC_MANIFEST_SHA256=856147c1cba7bfc6537c0aa4c51b09215973d29ca7b65a338816788b789a24aa
MPC_SOURCE_SHA256=ab642492f5cf882b74aa0cb730cd410a81edcdbec895183ce930e706c1c759b8
LOG="$LFS/tmp/alp-logs/m04-gcc-15.2.0-stage-$RUN_ID.log"
MANIFEST="$LFS/tmp/alp-m04-gcc-15.2.0-manifest-$RUN_ID.json"
PREFLIGHT="$LFS/tmp/alp-m04-gcc-15.2.0-preflight-$RUN_ID.log"
LINK_TRACE="$LFS/tmp/alp-m04-gcc-15.2.0-link-inputs-$RUN_ID.log"
LOADER_TRACE="$LFS/tmp/alp-m04-gcc-15.2.0-loader-$RUN_ID.log"
LINK_TRACE_CHROOT="/tmp/alp-logs/$(basename "$LINK_TRACE")"
LOADER_TRACE_CHROOT="/tmp/alp-logs/$(basename "$LOADER_TRACE")"
GMP_AUDIT_MANIFEST="$LFS/tmp/alp-m04-gcc-dependency-gmp-$RUN_ID.json"
MPFR_AUDIT_MANIFEST="$LFS/tmp/alp-m04-gcc-dependency-mpfr-$RUN_ID.json"
MPC_AUDIT_MANIFEST="$LFS/tmp/alp-m04-gcc-dependency-mpc-$RUN_ID.json"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CAPTURE_TOOL="$SCRIPT_DIR/capture-package-manifest.py"
COMPARE_TOOL="$SCRIPT_DIR/compare-package-manifest.py"
ALP_SHA256=7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132
EMPTY_DB_SHA256=40a9bcde751533fc237fae2b7e5eaebbbfd5779f3069c09f0590c07be184f165
MOUNTS=(); FINISHED=0

assert_no_lfs_mounts() {
    local output status
    if output=$(findmnt -rn -R "$LFS" 2>&1); then status=0; else status=$?; fi
    if [[ -n "$output" ]]; then echo "mounts found below $LFS or findmnt returned diagnostics: $output" >&2; return 1; fi
    case "$status" in
        0|1) return 0 ;;
        *) echo "findmnt failed while checking $LFS (status=$status)" >&2; return 1 ;;
    esac
}
assert_nbd_idle() {
    local pidfile=/sys/block/nbd0/pid sizefile=/sys/block/nbd0/size pid sectors
    if [[ -e "$pidfile" ]]; then
        IFS= read -r pid < "$pidfile" || true
        [[ -z "$pid" ]] || { echo "nbd0 is attached to PID $pid" >&2; return 1; }
    elif [[ -d /sys/block/nbd0 ]]; then
        [[ -r "$sizefile" ]] || { echo 'nbd0 PID is absent and its size cannot be checked' >&2; return 1; }
        IFS= read -r sectors < "$sizefile"
        [[ "$sectors" == 0 ]] || { echo "nbd0 PID attribute absent but size=$sectors sectors" >&2; return 1; }
    fi
    local output status
    if output=$(findmnt -rn -o SOURCE,TARGET 2>&1); then status=0; else status=$?; fi
    case "$status" in 0|1) ;; *) echo "findmnt failed during NBD mount check: $output" >&2; return 1 ;; esac
    if grep -E '(^|[[:space:]])/dev/nbd[0-9]+(p[0-9]+)?([[:space:]]|$)' <<< "$output" >/dev/null; then
        echo "an NBD device is mounted: $output" >&2; return 1
    fi
}
assert_no_temporary_images() {
    local directory output status
    for directory in "$LFS/tmp" /tmp; do
        [[ -d "$directory" ]] || { echo "cannot inspect image directory $directory" >&2; return 1; }
        if output=$(find "$directory" -type f \( -iname '*.vhd' -o -iname '*.vhdx' -o -iname '*.qcow' -o -iname '*.qcow2' -o -iname '*.img' \) -print 2>&1); then status=0; else status=$?; fi
        [[ $status -eq 0 ]] || { echo "image scan failed for $directory: $output" >&2; return 1; }
        [[ -z "$output" ]] || { echo "temporary image files found under $directory: $output" >&2; return 1; }
    done
}
assert_no_active_builds() {
    local process output status
    for process in make ninja meson qemu-nbd; do
        if output=$(pgrep -ax "$process" 2>&1); then
            echo "Refusing concurrent build or NBD process: $output" >&2; return 1
        else
            status=$?
            [[ $status -eq 1 ]] || { echo "pgrep failed while checking $process (status=$status): $output" >&2; return 1; }
        fi
    done
}

cleanup() {
    local status=$?
    trap - EXIT; set +e
    for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}" || status=1; done
    if ! assert_no_lfs_mounts; then echo "CLEANUP_FAILED: could not verify that mounts below $LFS are detached" >&2; status=1; fi
    if (( FINISHED )) && (( status == 0 )); then echo "STAGE_OK: $STAGE_HOST"; else echo 'STAGE_INCOMPLETE: preserve build/stage/evidence for diagnosis' >&2; status=1; fi
    exit "$status"
}
trap cleanup EXIT
trap 'status=$?; echo "FAILED line $LINENO status $status: $BASH_COMMAND" >&2; exit "$status"' ERR

assert_alp_and_empty_db() {
    [[ $(sha256sum "$LFS/usr/lib/alp/alp.py" | awk '{print $1}') == "$ALP_SHA256" ]]
    [[ $(sha256sum "$LFS/var/lib/alp/db.json" | awk '{print $1}') == "$EMPTY_DB_SHA256" ]]
    python3 - "$LFS/var/lib/alp/db.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as stream: db = json.load(stream)
if db.get("schema_version") != 1 or db.get("packages") != {}:
    raise SystemExit("refusing: pinned Alp must retain its empty schema-1 DB")
PY
}
verify_dependency() {
    local mf=$1 hash=$2 name=$3 version=$4 source=$5 stage=$6
    [[ "$hash" =~ ^[0-9a-f]{64}$ && -s "$mf" ]]
    [[ $(sha256sum "$mf" | awk '{print $1}') == "$hash" ]]
    python3 - "$mf" "$name" "$version" "$source" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as stream: m = json.load(stream)
p, s = m.get("package", {}), m.get("package", {}).get("source", {})
if (p.get("name"), p.get("version"), s.get("sha256")) != (sys.argv[2], sys.argv[3], sys.argv[4]):
    raise SystemExit("dependency manifest identity/source mismatch: " + sys.argv[1])
PY
    [[ -d "$stage/usr/include" && -d "$stage/usr/lib" ]]
}
verify_dependency_inventory() {
    local name=$1 version=$2 source_url=$3 source_sha=$4 stage=$5 pinned=$6 recaptured=$7
    python3 "$CAPTURE_TOOL" --stage "$stage" --name "$name" --version "$version" \
        --source-url "$source_url" --source-sha256 "$source_sha" --output "$recaptured" | tee -a "$PREFLIGHT"
    echo "DEPENDENCY_RECAPTURED_MANIFEST=$recaptured SHA256=$(sha256sum "$recaptured" | awk '{print $1}')" | tee -a "$PREFLIGHT"
    python3 - "$pinned" "$recaptured" "$name" "$version" "$source_url" "$source_sha" <<'PY' | tee -a "$PREFLIGHT"
import hashlib, json, sys
with open(sys.argv[1], encoding="utf-8") as stream: old = json.load(stream)
with open(sys.argv[2], encoding="utf-8") as stream: new = json.load(stream)
expected = (sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6])
def identity(manifest):
    package = manifest.get("package", {})
    source = package.get("source", {})
    return package.get("name"), package.get("version"), source.get("url"), source.get("sha256")
if old.get("schema") != new.get("schema") or identity(old) != expected or identity(new) != expected:
    raise SystemExit("dependency inventory identity/schema differs from pinned manifest")
old_entries, new_entries = old.get("entries"), new.get("entries")
if not isinstance(old_entries, list) or not isinstance(new_entries, list) or old_entries != new_entries:
    raise SystemExit("dependency stage has missing, changed, or extra inventory entries")
payload = json.dumps(new_entries, sort_keys=True, separators=(",", ":")).encode()
print(f"EXACT_INVENTORY_OK package={expected[0]} version={expected[1]} entries={len(new_entries)} entries_sha256={hashlib.sha256(payload).hexdigest()} recaptured_manifest={sys.argv[2]}")
PY
}

[[ $EUID -eq 0 && -d "$LFS/etc" && -x "$LFS/usr/bin/bash" && -f "$SOURCE" ]]
[[ $(hostname) == yrsk ]] || { echo "Refusing GCC build on unexpected Builder host: $(hostname)" >&2; exit 1; }
[[ -f "$CAPTURE_TOOL" && -f "$COMPARE_TOOL" ]]
grep -q '^tester:.*:101:101:' "$LFS/etc/passwd" || { echo 'LFS target tester UID/GID 101 is required' >&2; exit 1; }
[[ -s "$GMP_STAGE_HOST/usr/include/gmp.h" && -e "$GMP_STAGE_HOST/usr/lib/libgmp.so" ]]
[[ -s "$MPFR_STAGE_HOST/usr/include/mpfr.h" && -e "$MPFR_STAGE_HOST/usr/lib/libmpfr.so" ]]
[[ -s "$MPC_STAGE_HOST/usr/include/mpc.h" && -e "$MPC_STAGE_HOST/usr/lib/libmpc.so" ]]
verify_dependency "$GMP_MANIFEST" "$GMP_MANIFEST_SHA256" gmp 6.3.0 "$GMP_SOURCE_SHA256" "$GMP_STAGE_HOST"
verify_dependency "$MPFR_MANIFEST" "$MPFR_MANIFEST_SHA256" mpfr 4.2.2 "$MPFR_SOURCE_SHA256" "$MPFR_STAGE_HOST"
verify_dependency "$MPC_MANIFEST" "$MPC_MANIFEST_SHA256" mpc 1.3.1 "$MPC_SOURCE_SHA256" "$MPC_STAGE_HOST"
[[ ! -e "$BUILD" && ! -e "$STAGE_HOST" && ! -e "$LOG" && ! -e "$MANIFEST" && ! -e "$PREFLIGHT" ]]
[[ ! -e "$LINK_TRACE" && ! -e "$LOADER_TRACE" ]]
[[ ! -e "$GMP_AUDIT_MANIFEST" && ! -e "$MPFR_AUDIT_MANIFEST" && ! -e "$MPC_AUDIT_MANIFEST" ]]
assert_no_lfs_mounts
assert_nbd_idle
assert_no_temporary_images
assert_no_active_builds
assert_alp_and_empty_db
[[ $(md5sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_MD5" ]]
[[ $(sha256sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_SHA256" ]]
available_kib=$(df -Pk "$LFS" | awk 'NR == 2 {print $4}')
# LFS estimates 6.6 GB. Keep an additional margin for the filesystem and logs.
[[ "$available_kib" =~ ^[0-9]+$ && $available_kib -ge 8388608 ]]

mkdir -p "$LFS/tmp/alp-logs"; : > "$PREFLIGHT"
{
    echo "run_id=$RUN_ID builder=$(hostname)"
    echo 'builder_hostname_gate=yrsk'
    echo "source_url=$SOURCE_URL source_md5=$EXPECTED_MD5 source_sha256=$EXPECTED_SHA256"
    echo "gmp_manifest_sha256=$GMP_MANIFEST_SHA256 mpfr_manifest_sha256=$MPFR_MANIFEST_SHA256 mpc_manifest_sha256=$MPC_MANIFEST_SHA256"
    echo 'recipe=LFS-12.4-systemd-8.29; all three --with-* dependency prefixes use pinned stages'
    echo 'install_mode=DESTDIR; rootfs_merge=forbidden; Builder-/tmp-image=forbidden'
    echo "free_kib=$available_kib"
} >> "$PREFLIGHT"
for dep in GMP MPFR MPC; do
    case "$dep" in
        GMP) dep_manifest=$GMP_MANIFEST; dep_root=$GMP_STAGE_HOST; dep_version=6.3.0; dep_url=$GMP_SOURCE_URL; dep_sha=$GMP_SOURCE_SHA256; audit_manifest=$GMP_AUDIT_MANIFEST ;;
        MPFR) dep_manifest=$MPFR_MANIFEST; dep_root=$MPFR_STAGE_HOST; dep_version=4.2.2; dep_url=$MPFR_SOURCE_URL; dep_sha=$MPFR_SOURCE_SHA256; audit_manifest=$MPFR_AUDIT_MANIFEST ;;
        MPC) dep_manifest=$MPC_MANIFEST; dep_root=$MPC_STAGE_HOST; dep_version=1.3.1; dep_url=$MPC_SOURCE_URL; dep_sha=$MPC_SOURCE_SHA256; audit_manifest=$MPC_AUDIT_MANIFEST ;;
    esac
    dep_lower=$(printf '%s' "$dep" | tr '[:upper:]' '[:lower:]')
    verify_dependency_inventory "$dep_lower" "$dep_version" "$dep_url" "$dep_sha" "$dep_root" "$dep_manifest" "$audit_manifest"
    if python3 "$COMPARE_TOOL" --manifest "$dep_manifest" --root "$dep_root" >> "$PREFLIGHT" 2>&1; then dep_status=0; else dep_status=$?; fi
    echo "${dep}_STAGE_MANIFEST_COMPARE_EXIT=$dep_status" | tee -a "$PREFLIGHT"
    (( dep_status == 0 )) || { echo "refusing GCC: $dep stage differs from pinned manifest" >&2; exit "$dep_status"; }
    if python3 "$COMPARE_TOOL" --manifest "$dep_manifest" --root "$LFS" >> "$PREFLIGHT" 2>&1; then dep_root_status=0; else dep_root_status=$?; fi
    case "$dep_root_status" in
        0) echo "ROOTFS_${dep}_PREFLIGHT=all staged paths match" | tee -a "$PREFLIGHT" ;;
        1) echo "ROOTFS_${dep}_PREFLIGHT=differences recorded (read-only; no adoption)" | tee -a "$PREFLIGHT" ;;
        *) echo "ROOTFS_${dep}_PREFLIGHT=comparator error $dep_root_status" | tee -a "$PREFLIGHT"; exit "$dep_root_status" ;;
    esac
done
assert_alp_and_empty_db

exec > >(tee -a "$LOG") 2>&1
echo "Builder=$(hostname) run_id=$RUN_ID source=$(sha256sum "$SOURCE")"
echo 'LFS_REQUIRED_PATCH=none; DESTDIR-only; no ownership claim'
df -h "$LFS"
mkdir -p "$BUILD" "$STAGE_HOST"
tar -xJf "$SOURCE" -C "$BUILD" --strip-components=1
mkdir -p "$BUILD/build" "$BUILD/tmp"
bind_mount() { local src=$1 dst=$2; mountpoint -q "$dst" && { echo "pre-existing mount: $dst" >&2; return 1; }; mount --bind "$src" "$dst"; MOUNTS+=("$dst"); }
bind_mount /dev "$LFS/dev"; bind_mount /dev/pts "$LFS/dev/pts"
bind_mount /proc "$LFS/proc"; bind_mount /sys "$LFS/sys"; bind_mount /run "$LFS/run"

# LFS recipe with dependency paths explicitly selected for configure and runtime.
chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
    TMPDIR="$BUILD_CHROOT/tmp" TMP="$BUILD_CHROOT/tmp" TEMP="$BUILD_CHROOT/tmp" \
    CPPFLAGS="-I$MPC_STAGE_CHROOT/usr/include -I$MPFR_STAGE_CHROOT/usr/include -I$GMP_STAGE_CHROOT/usr/include" \
    LDFLAGS="-L$MPC_STAGE_CHROOT/usr/lib -L$MPFR_STAGE_CHROOT/usr/lib -L$GMP_STAGE_CHROOT/usr/lib" \
    LD_LIBRARY_PATH="$MPC_STAGE_CHROOT/usr/lib:$MPFR_STAGE_CHROOT/usr/lib:$GMP_STAGE_CHROOT/usr/lib" \
    PKG_CONFIG_PATH="$MPC_STAGE_CHROOT/usr/lib/pkgconfig:$MPFR_STAGE_CHROOT/usr/lib/pkgconfig:$GMP_STAGE_CHROOT/usr/lib/pkgconfig" \
    /bin/bash --noprofile --norc -c '
      set -Eeuo pipefail
      cd '"$BUILD_CHROOT"'/gcc/config/i386
      sed -e "/m64=/s/lib64/lib/" -i.orig t-linux64
      cd '"$BUILD_CHROOT"'/build
      ../configure --prefix=/usr LD=ld --enable-languages=c,c++ \
        --enable-default-pie --enable-default-ssp --enable-host-pie \
        --disable-multilib --disable-bootstrap --disable-fixincludes --with-system-zlib \
        --with-gmp="'"$GMP_STAGE_CHROOT"'/usr" \
        --with-mpfr="'"$MPFR_STAGE_CHROOT"'/usr" \
        --with-mpc="'"$MPC_STAGE_CHROOT"'/usr"
      for stage in "'"$GMP_STAGE_CHROOT"'/usr" "'"$MPFR_STAGE_CHROOT"'/usr" "'"$MPC_STAGE_CHROOT"'/usr"; do
        grep -F -- "$stage" config.log >/dev/null || { echo "configure did not record $stage" >&2; exit 1; }
      done
      make -j2
      ulimit -s -H unlimited
      sed -e "/cpython/d" -i ../gcc/testsuite/gcc.dg/plugin/plugin.exp
      chown -R tester .
      set +e
      su tester -c "PATH=$PATH make -k check"
      check_status=$?
      set -e
      ../contrib/test_summary > gcc-test-summary.log
      cat gcc-test-summary.log
      echo "GCC_MAKE_CHECK_EXIT=$check_status"
    '

# Install using DESTDIR, then apply LFS post-install adjustments inside the stage.
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
    /bin/bash --noprofile --norc -c '
      set -Eeuo pipefail
      cd '"$BUILD_CHROOT"'/build
      make DESTDIR="'"$STAGE_CHROOT"'" install
      triplet=$(gcc -dumpmachine); gccver=15.2.0
      chown -R root:root "'"$STAGE_CHROOT"'/usr/lib/gcc/$triplet/$gccver/include" "'"$STAGE_CHROOT"'/usr/lib/gcc/$triplet/$gccver/include-fixed"
      ln -svr "'"$STAGE_CHROOT"'/usr/bin/cpp" "'"$STAGE_CHROOT"'/usr/lib/cpp"
      ln -sv gcc.1 "'"$STAGE_CHROOT"'/usr/share/man/man1/cc.1"
      mkdir -pv "'"$STAGE_CHROOT"'/usr/lib/bfd-plugins"
      ln -sfv "../../libexec/gcc/$triplet/$gccver/liblto_plugin.so" "'"$STAGE_CHROOT"'/usr/lib/bfd-plugins/liblto_plugin.so"
      mkdir -pv "'"$STAGE_CHROOT"'/usr/share/gdb/auto-load/usr/lib"
      find "'"$STAGE_CHROOT"'/usr/lib" -maxdepth 1 -name "*-gdb.py" -exec mv -v {} "'"$STAGE_CHROOT"'/usr/share/gdb/auto-load/usr/lib/" \;
    '

cat > "$BUILD/gcc-dependency-smoke.c" <<'EOF'
#include <gmp.h>
#include <mpfr.h>
#include <mpc.h>
int main(void) {
  mpz_t z; mpz_init_set_ui(z, 21); mpz_mul_ui(z, z, 2);
  mpfr_t f; mpfr_init2(f, 128); mpfr_set_z(f, z, MPFR_RNDN);
  mpc_t c; mpc_init2(c, 128); mpc_set_fr_fr(c, f, f, MPC_RNDNN);
  int bad = mpz_cmp_ui(z, 42) != 0 || mpfr_cmp_ui(f, 42) != 0 || mpfr_cmp_ui(mpc_realref(c), 42) != 0;
  mpc_clear(c); mpfr_clear(f); mpz_clear(z); return bad;
}
EOF
chown root:root "$BUILD/gcc-dependency-smoke.c"
chroot "$LFS" /usr/bin/env -i \
    PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
    GCC_EXEC_PREFIX="$STAGE_CHROOT/usr/lib/gcc/" \
    LD_LIBRARY_PATH="$MPC_STAGE_CHROOT/usr/lib:$MPFR_STAGE_CHROOT/usr/lib:$GMP_STAGE_CHROOT/usr/lib" \
    /bin/bash --noprofile --norc -c '
      set -Eeuo pipefail; cd '"$BUILD_CHROOT"'
      gcc_bin="'"$STAGE_CHROOT"'/usr/bin/gcc"
      triplet=$("$gcc_bin" -dumpmachine)
      gcc_prefix="'"$STAGE_CHROOT"'/usr/lib/gcc/$triplet/15.2.0/"
      cc1=$("$gcc_bin" -B"$gcc_prefix" -print-prog-name=cc1)
      case "$cc1" in "$gcc_prefix"*) ;; *) echo "staged GCC selected non-stage cc1: $cc1" >&2; exit 1 ;; esac
      test -x "$cc1"
      echo "STAGED_GCC=$gcc_bin TRIPLET=$triplet STAGED_CC1=$cc1"
      "$gcc_bin" -B"$gcc_prefix" -I"'"$MPC_STAGE_CHROOT"'/usr/include" -I"'"$MPFR_STAGE_CHROOT"'/usr/include" -I"'"$GMP_STAGE_CHROOT"'/usr/include" \
        gcc-dependency-smoke.c -Wl,-t -L"'"$MPC_STAGE_CHROOT"'/usr/lib" -L"'"$MPFR_STAGE_CHROOT"'/usr/lib" -L"'"$GMP_STAGE_CHROOT"'/usr/lib" \
        -lmpc -lmpfr -lgmp -o gcc-dependency-smoke 2> "'"$LINK_TRACE_CHROOT"'"
      grep -F "'"$MPC_STAGE_CHROOT"'/usr/lib/libmpc.so" "'"$LINK_TRACE_CHROOT"'" >/dev/null
      grep -F "'"$MPFR_STAGE_CHROOT"'/usr/lib/libmpfr.so" "'"$LINK_TRACE_CHROOT"'" >/dev/null
      grep -F "'"$GMP_STAGE_CHROOT"'/usr/lib/libgmp.so" "'"$LINK_TRACE_CHROOT"'" >/dev/null
      LD_DEBUG=libs ./gcc-dependency-smoke 2> "'"$LOADER_TRACE_CHROOT"'"
      grep -F "'"$MPC_STAGE_CHROOT"'/usr/lib/libmpc.so.3" "'"$LOADER_TRACE_CHROOT"'" >/dev/null
      grep -F "'"$MPFR_STAGE_CHROOT"'/usr/lib/libmpfr.so.6" "'"$LOADER_TRACE_CHROOT"'" >/dev/null
      grep -F "'"$GMP_STAGE_CHROOT"'/usr/lib/libgmp.so.10" "'"$LOADER_TRACE_CHROOT"'" >/dev/null
      echo GCC_DEPENDENCY_SMOKE=passed
    '

[[ -x "$STAGE_HOST/usr/bin/gcc" && -x "$STAGE_HOST/usr/bin/g++" ]]
[[ -e "$STAGE_HOST/usr/lib/libstdc++.so" && -e "$STAGE_HOST/usr/lib/libgcc_s.so" ]]
assert_alp_and_empty_db; assert_nbd_idle
python3 "$CAPTURE_TOOL" --stage "$STAGE_HOST" --name gcc --version 15.2.0 \
    --source-url "$SOURCE_URL" --source-sha256 "$EXPECTED_SHA256" --output "$MANIFEST" | tee -a "$PREFLIGHT"
if python3 "$COMPARE_TOOL" --manifest "$MANIFEST" --root "$STAGE_HOST" >> "$PREFLIGHT" 2>&1; then stage_status=0; else stage_status=$?; fi
echo "GCC_STAGE_MANIFEST_COMPARE_EXIT=$stage_status" | tee -a "$PREFLIGHT"
(( stage_status == 0 )) || { echo 'GCC stage differs from its manifest' >&2; exit "$stage_status"; }
if python3 "$COMPARE_TOOL" --manifest "$MANIFEST" --root "$LFS" >> "$PREFLIGHT" 2>&1; then root_status=0; else root_status=$?; fi
case "$root_status" in
    0) echo 'ROOTFS_PREFLIGHT=all staged GCC paths match' | tee -a "$PREFLIGHT" ;;
    1) echo 'ROOTFS_PREFLIGHT=staged GCC differences recorded (no merge performed)' | tee -a "$PREFLIGHT" ;;
    *) echo "rootfs comparator error=$root_status" | tee -a "$PREFLIGHT"; exit "$root_status" ;;
esac
{
    echo "link_trace_sha256=$(sha256sum "$LINK_TRACE" | awk '{print $1}') path=$LINK_TRACE"
    echo "loader_trace_sha256=$(sha256sum "$LOADER_TRACE" | awk '{print $1}') path=$LOADER_TRACE"
    check_status=$(awk -F= '/^GCC_MAKE_CHECK_EXIT=/ { status=$2 } END { print status }' "$LOG")
    [[ "$check_status" =~ ^[0-9]+$ ]]
    echo "GCC_MAKE_CHECK_EXIT=$check_status"
    echo "GCC_TEST_SUMMARY=$BUILD/build/gcc-test-summary.log SHA256=$(sha256sum "$BUILD/build/gcc-test-summary.log" | awk '{print $1}')"
    echo 'adoption=not performed; stage only'
} | tee -a "$PREFLIGHT"
cat "$PREFLIGHT"; assert_alp_and_empty_db; assert_nbd_idle; assert_no_temporary_images
FINISHED=1
