#!/usr/bin/env bash
set -Eeuo pipefail

# LFS 12.4-systemd Acl 2.3.2 isolated stage. Draft only; no rootfs merge.
LFS=/mnt/lfs
RUN_ID=20260924-r1
BUILD=/mnt/lfs/build/acl-2.3.2-m04-$RUN_ID
BUILD_CHROOT=/build/acl-2.3.2-m04-$RUN_ID
ACL_TEST_PARSER_HOST=$BUILD/validate-acl-tests.py
ACL_TEST_PARSER_CHROOT=$BUILD_CHROOT/validate-acl-tests.py
STAGE_HOST=/mnt/lfs/tmp/alp-m04-acl-stage-$RUN_ID
STAGE_CHROOT=/tmp/alp-m04-acl-stage-$RUN_ID
SOURCE=/mnt/lfs/sources/acl-2.3.2.tar.xz
LOG=/mnt/lfs/tmp/alp-logs/m04-acl-2.3.2-stage-$RUN_ID.log
MANIFEST=/mnt/lfs/tmp/alp-m04-acl-2.3.2-manifest-$RUN_ID.json
PREFLIGHT=/mnt/lfs/tmp/alp-m04-acl-2.3.2-preflight-$RUN_ID.log
ATTR_STAGE_HOST=/mnt/lfs/tmp/alp-m04-attr-stage-20260924-r3
ATTR_STAGE_CHROOT=/tmp/alp-m04-attr-stage-20260924-r3
ATTR_MANIFEST=/mnt/lfs/tmp/alp-m04-attr-2.5.2-manifest-20260924-r3.json
ATTR_MANIFEST_SHA256=3482a3a2a6dfc24733de4cac0c79147520e86db628a8309e319f6561e50ef786
ATTR_STAGE_COMPARE=/mnt/lfs/tmp/alp-m04-acl-attr-stage-compare-$RUN_ID.log
DEPENDENCY_RESOLUTION=/mnt/lfs/tmp/alp-m04-acl-dependency-resolution-$RUN_ID.log
SMOKE_TRACE=/mnt/lfs/tmp/alp-m04-acl-smoke-loader-$RUN_ID.log
SOURCE_URL=https://download.savannah.gnu.org/releases/acl/acl-2.3.2.tar.xz
# LFS MD5; Savannah releases use detached signatures, with no primary SHA-256
# published. SHA-256 below is an independent Buildroot checksum cross-check.
# https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter03/packages.html
# https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/acl.html
# https://lists.buildroot.org/pipermail/buildroot/2024-February/370396.html
EXPECTED_MD5=590765dee95907dbc3c856f7255bd669
EXPECTED_SHA256=97203a72cae99ab89a067fe2210c1cbf052bc492b479eca7d226d9830883b0bd
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
[[ ! -e "$ACL_TEST_PARSER_HOST" ]]
[[ ! -e "$ATTR_STAGE_COMPARE" && ! -e "$DEPENDENCY_RESOLUTION" && ! -e "$SMOKE_TRACE" ]]
[[ -z $(findmnt -rn -R "$LFS" || true) && ! -s /sys/block/nbd0/pid ]]
[[ "$RUN_ID" =~ ^20260924-r[0-9]+$ ]]
[[ "$BUILD" == "/mnt/lfs/build/acl-2.3.2-m04-$RUN_ID" && "$BUILD_CHROOT" == "/build/acl-2.3.2-m04-$RUN_ID" ]]
[[ "$ACL_TEST_PARSER_HOST" == "$BUILD/validate-acl-tests.py" && "$ACL_TEST_PARSER_CHROOT" == "$BUILD_CHROOT/validate-acl-tests.py" ]]
[[ "$STAGE_HOST" == "/mnt/lfs/tmp/alp-m04-acl-stage-$RUN_ID" && "$STAGE_CHROOT" == "/tmp/alp-m04-acl-stage-$RUN_ID" ]]
for workspace_path in "$BUILD" "$BUILD_CHROOT" "$ACL_TEST_PARSER_HOST" "$ACL_TEST_PARSER_CHROOT" "$STAGE_HOST" "$STAGE_CHROOT" "$LOG" "$MANIFEST" "$PREFLIGHT" "$ATTR_STAGE_COMPARE" "$DEPENDENCY_RESOLUTION" "$SMOKE_TRACE"; do
  [[ "$workspace_path" == *"$RUN_ID"* ]] || { echo "stale workspace path for $RUN_ID: $workspace_path" >&2; exit 1; }
done
for process in make ninja meson; do if pgrep -x "$process" >/dev/null; then echo "Refusing concurrent build: $process" >&2; exit 1; fi; done
assert_alp_and_empty_db
[[ -f "$ATTR_MANIFEST" && -d "$ATTR_STAGE_HOST" && -d "$ATTR_STAGE_HOST/usr/include/attr" && -s "$ATTR_STAGE_HOST/usr/lib/libattr.so.1.1.2502" ]]
[[ $(sha256sum "$ATTR_MANIFEST" | awk '{print $1}') == "$ATTR_MANIFEST_SHA256" ]]
if python3 "$COMPARE_TOOL" --manifest "$ATTR_MANIFEST" --root "$ATTR_STAGE_HOST" > "$ATTR_STAGE_COMPARE" 2>&1; then
  ATTR_STAGE_COMPARE_STATUS=0
else
  ATTR_STAGE_COMPARE_STATUS=$?
fi
[[ "$ATTR_STAGE_COMPARE_STATUS" -eq 0 ]]
grep -Fq 'entries=75 matched=75 mismatched=0' "$ATTR_STAGE_COMPARE"
[[ $(md5sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_MD5" ]]
[[ $(sha256sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_SHA256" ]]
available_kib=$(df -Pk "$LFS" | awk 'NR == 2 {print $4}')
[[ "$available_kib" =~ ^[0-9]+$ && $available_kib -ge 524288 ]]
command -v setfacl >/dev/null && command -v getfacl >/dev/null
mkdir -p /mnt/lfs/build /mnt/lfs/tmp/alp-logs
mkdir -p "$BUILD" "$STAGE_HOST"
cat > "$ACL_TEST_PARSER_HOST" <<'PY'
import re, sys

log_path, status_text = sys.argv[1:]
status = int(status_text)
with open(log_path, encoding="utf-8", errors="replace") as f:
    lines = f.read().splitlines()
keys = ("TOTAL", "PASS", "SKIP", "XFAIL", "FAIL", "XPASS", "ERROR")
summary = {}
for line in lines:
    if line.startswith("# "):
        match = re.fullmatch(r"# ([A-Z]+):\s+([0-9]+)", line)
        if not match or match.group(1) not in keys or match.group(1) in summary:
            raise SystemExit(f"unexpected or duplicate Automake summary row: {line}")
        summary[match.group(1)] = int(match.group(2))
missing = set(keys) - summary.keys()
if missing:
    raise SystemExit(f"missing Automake summary fields: {sorted(missing)}")
if summary["TOTAL"] != sum(summary[k] for k in keys[1:]):
    raise SystemExit("Automake summary total is inconsistent")
diagnostics = [line for line in lines if re.match(r"^(FAIL:|ERROR:|XPASS:|UNRESOLVED:|UNTESTED:)", line)]
status_rows = {key: [] for key in ("FAIL", "SKIP", "XFAIL", "XPASS", "ERROR")}
for line in lines:
    match = re.fullmatch(r"(FAIL|SKIP|XFAIL|XPASS|ERROR):\s+(test/\S+)", line)
    if match:
        status_rows[match.group(1)].append(match.group(2))
expected_summary = {"TOTAL": 15, "PASS": 8, "SKIP": 4, "XFAIL": 2, "FAIL": 1, "XPASS": 0, "ERROR": 0}
expected_rows = {
    "FAIL": ["test/cp.test"],
    "SKIP": ["test/root/getfacl.test", "test/root/permissions.test", "test/root/restore.test", "test/root/setfacl.test"],
    "XFAIL": ["test/nfs/nfs-dir.test", "test/nfs/nfsacl.test"],
    "XPASS": [],
    "ERROR": [],
}
if status != 1 or summary != expected_summary or diagnostics:
    raise SystemExit(f"make check result differs from pinned LFS stage result: status={status} summary={summary}")
if any(sorted(status_rows[k]) != sorted(expected_rows[k]) for k in expected_rows):
    raise SystemExit(f"test result names differ from the reviewed exact allowlist: {status_rows}")
print("ACL_MAKE_CHECK_CLASSIFIED=FAIL cp.test; SKIP four root-only fixtures; XFAIL two NFS fixtures; 15/8/4/2/1/0/0")
PY
chmod 644 "$ACL_TEST_PARSER_HOST"
chown 1001:1001 "$ACL_TEST_PARSER_HOST"
[[ $(stat -c '%a:%u:%g' "$ACL_TEST_PARSER_HOST") == '644:1001:1001' ]]
# LFS requires an ACL-capable test filesystem. Probe the real build filesystem.
acl_probe="$BUILD/.acl-fs-probe"; [[ ! -e "$acl_probe" ]]; : > "$acl_probe"
if setfacl -m u:1001:r-- "$acl_probe" && getfacl -ncp "$acl_probe" | grep -Fq 'user:1001:r--'; then :; else rm -f "$acl_probe"; echo 'filesystem ACL probe failed' >&2; exit 1; fi
rm -f "$acl_probe"
exec > >(tee -a "$LOG") 2>&1
echo "acl_test_parser_sha256=$(sha256sum "$ACL_TEST_PARSER_HOST" | awk '{print $1}') path=$ACL_TEST_PARSER_CHROOT mode=644 owner=1001:1001"
echo "Builder=$(hostname) source=$(sha256sum "$SOURCE")"; echo 'filesystem_probe=POSIX_ACL passed'
echo 'LFS_REQUIRED_PATCH=none; install_mode=DESTDIR; rootfs_merge=forbidden'
echo "attr_manifest_sha256=$ATTR_MANIFEST_SHA256 attr_stage_comparison=$ATTR_STAGE_COMPARE_STATUS (75/75)"
echo "dependency_flags=CPPFLAGS=-I$ATTR_STAGE_CHROOT/usr/include LDFLAGS=-L$ATTR_STAGE_CHROOT/usr/lib LD_LIBRARY_PATH=$ATTR_STAGE_CHROOT/usr/lib; no LD_PRELOAD"
df -h "$LFS"
tar -xJf "$SOURCE" -C "$BUILD" --strip-components=1
mkdir -p "$BUILD/tmp"; chown -R 1001:1001 "$BUILD"
bind_mount() { local src=$1 dst=$2; if mountpoint -q "$dst"; then echo "Refusing pre-existing mount: $dst" >&2; return 1; fi; mount --bind "$src" "$dst"; MOUNTS+=("$dst"); }
bind_mount /dev "$LFS/dev"; bind_mount /dev/pts "$LFS/dev/pts"; bind_mount /proc "$LFS/proc"; bind_mount /sys "$LFS/sys"; bind_mount /run "$LFS/run"
# LFS 8.25 exact recipe. The upstream book explicitly documents test/cp.test
# as a known failure because Coreutils lacks Acl support at this stage.
chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i HOME=/home/lfs TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 TMPDIR="$BUILD_CHROOT/tmp" BUILD_CHROOT="$BUILD_CHROOT" ACL_TEST_PARSER_CHROOT="$ACL_TEST_PARSER_CHROOT" CPPFLAGS="-I$ATTR_STAGE_CHROOT/usr/include" LDFLAGS="-L$ATTR_STAGE_CHROOT/usr/lib" LD_LIBRARY_PATH="$ATTR_STAGE_CHROOT/usr/lib" /bin/bash --noprofile --norc -c '
  set -e
  cd "$BUILD_CHROOT"
  ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/acl-2.3.2
  make
  if make check > acl-check-log 2>&1; then check_status=0; else check_status=$?; fi
  cat acl-check-log
  python3 "$ACL_TEST_PARSER_CHROOT" acl-check-log "$check_status"
'
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c "cd '$BUILD_CHROOT' && make DESTDIR='$STAGE_CHROOT' install"
[[ -x "$STAGE_HOST/usr/bin/chacl" && -x "$STAGE_HOST/usr/bin/getfacl" && -x "$STAGE_HOST/usr/bin/setfacl" ]]
[[ -s "$STAGE_HOST/usr/lib/libacl.so" || -L "$STAGE_HOST/usr/lib/libacl.so" ]]
[[ -s "$STAGE_HOST/usr/lib/libacl.so.1" || -L "$STAGE_HOST/usr/lib/libacl.so.1" ]]
[[ -d "$STAGE_HOST/usr/share/doc/acl-2.3.2" ]]
readelf -d "$STAGE_HOST/usr/lib/libacl.so.1" | grep -Fq 'Shared library: [libattr.so.1]'
if chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib:$ATTR_STAGE_CHROOT/usr/lib" /usr/bin/ldd "$STAGE_CHROOT/usr/lib/libacl.so.1" > "$DEPENDENCY_RESOLUTION" 2>&1; then :; else cat "$DEPENDENCY_RESOLUTION" >&2; exit 1; fi
grep -Fq "libattr.so.1 => $ATTR_STAGE_CHROOT/usr/lib/libattr.so.1" "$DEPENDENCY_RESOLUTION"
smoke="$BUILD/acl-stage-smoke"; : > "$smoke"
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib:$ATTR_STAGE_CHROOT/usr/lib" LD_DEBUG=libs /bin/bash --noprofile --norc -c "
  '$STAGE_CHROOT/usr/bin/setfacl' -m u:1001:r-- '$BUILD_CHROOT/acl-stage-smoke'
  '$STAGE_CHROOT/usr/bin/getfacl' -ncp '$BUILD_CHROOT/acl-stage-smoke' | grep -Fqx 'user:1001:r--'
" 2> "$SMOKE_TRACE"
grep -Fq "calling init: $ATTR_STAGE_CHROOT/usr/lib/libattr.so.1" "$SMOKE_TRACE"
rm -f "$smoke"
assert_alp_and_empty_db; [[ ! -s /sys/block/nbd0/pid ]]
{ echo 'package=acl version=2.3.2'; echo "source_url=$SOURCE_URL"; echo "source_md5=$EXPECTED_MD5"; echo "source_sha256=$EXPECTED_SHA256"; echo "attr_manifest_sha256=$ATTR_MANIFEST_SHA256"; echo "attr_stage_compare=$ATTR_STAGE_COMPARE (75/75)"; echo 'critical_tests=make check; only documented test/cp.test failure may be allowed'; echo 'install_mode=DESTDIR; rootfs_merge=forbidden'; } > "$PREFLIGHT"
cat "$ATTR_STAGE_COMPARE" "$DEPENDENCY_RESOLUTION" >> "$PREFLIGHT"
python3 "$CAPTURE_TOOL" --stage "$STAGE_HOST" --name acl --version 2.3.2 --source-url "$SOURCE_URL" --source-sha256 "$EXPECTED_SHA256" --output "$MANIFEST" | tee -a "$PREFLIGHT"
if python3 "$COMPARE_TOOL" --manifest "$MANIFEST" --root "$LFS" >> "$PREFLIGHT" 2>&1; then compare_status=0; else compare_status=$?; fi
case "$compare_status" in 0) echo 'ROOTFS_PREFLIGHT=all staged paths match' | tee -a "$PREFLIGHT" ;; 1) echo 'ROOTFS_PREFLIGHT=staged paths differ; review before adoption' | tee -a "$PREFLIGHT" ;; *) echo "ROOTFS_PREFLIGHT=comparator error $compare_status" | tee -a "$PREFLIGHT"; exit "$compare_status" ;; esac
cat "$PREFLIGHT"; assert_alp_and_empty_db; [[ ! -s /sys/block/nbd0/pid ]]; FINISHED=1
