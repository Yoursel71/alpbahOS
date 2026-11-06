#!/usr/bin/env bash
set -Eeuo pipefail

# Resume the ACL stage from the preserved, successfully built r1 tree. This
# script verifies r1 evidence and only runs DESTDIR install plus stage checks.
LFS=/mnt/lfs
RUN_ID=20260924-r2
BUILD=/mnt/lfs/build/acl-2.3.2-m04-20260924-r1
BUILD_CHROOT=/build/acl-2.3.2-m04-20260924-r1
SOURCE=/mnt/lfs/sources/acl-2.3.2.tar.xz
R1_SCRIPT=/tmp/build-m04-acl-stage-review6.sh
R1_BUILD_LOG=/mnt/lfs/tmp/alp-logs/m04-acl-2.3.2-stage-20260924-r1.log
R1_CHECK_LOG=$BUILD/acl-check-log
R1_TEST_SUITE=$BUILD/test-suite.log
R1_PARSER=$BUILD/validate-acl-tests.py
R1_PARSER_STDOUT=$BUILD/parser-recheck.stdout
R1_BUILD_LOG_SHA256=9b175f7b6c0afffdc5f7ff7e4bea29cf6c0fd5d3e1730898042beee22a52319d
R1_CHECK_LOG_SHA256=c2e87e59c64c8651c8170bf2946dc04b395df0e056dcd6f3afc912d0f13bee3b
R1_TEST_SUITE_SHA256=cbbd1a56c207c4ed1c74d1491466f773e8928155a786b9197dc6d7afa347ab87
R1_PARSER_SHA256=b8f5b0eba08cb9dc3d988d630cc71a2223eb3ef58d6f947eb933e3cfef2c09b1
R1_PARSER_STDOUT_SHA256=d7af067fe41df53e50f45acfd9bd3391f9dea29a008abcccce844f398aa4f190
R1_SCRIPT_SHA256=d831fa836d70c3ba670c79ddd0c3e1d6315c9c942527e130d5e11b9665506134
STAGE_HOST=/mnt/lfs/tmp/alp-m04-acl-stage-20260924-r2
STAGE_CHROOT=/tmp/alp-m04-acl-stage-20260924-r2
MANIFEST=/mnt/lfs/tmp/alp-m04-acl-2.3.2-manifest-20260924-r2.json
PREFLIGHT=/mnt/lfs/tmp/alp-m04-acl-2.3.2-preflight-20260924-r2.log
LOG=/mnt/lfs/tmp/alp-logs/m04-acl-2.3.2-stage-resume-20260924-r2.log
ATTR_STAGE_HOST=/mnt/lfs/tmp/alp-m04-attr-stage-20260924-r3
ATTR_STAGE_CHROOT=/tmp/alp-m04-attr-stage-20260924-r3
ATTR_MANIFEST=/mnt/lfs/tmp/alp-m04-attr-2.5.2-manifest-20260924-r3.json
ATTR_MANIFEST_SHA256=3482a3a2a6dfc24733de4cac0c79147520e86db628a8309e319f6561e50ef786
ATTR_STAGE_COMPARE=/mnt/lfs/tmp/alp-m04-acl-attr-compare-20260924-r2.log
DEPENDENCY_RESOLUTION=/mnt/lfs/tmp/alp-m04-acl-dependency-resolution-20260924-r2.log
SMOKE_TRACE=/mnt/lfs/tmp/alp-m04-acl-smoke-loader-20260924-r2.log
SMOKE_FILE=/mnt/lfs/tmp/alp-m04-acl-smoke-file-20260924-r2
PARSER=/mnt/lfs/tmp/alp-m04-acl-result-parser-20260924-r2.py
EXPECTED_PARSER_SHA256=f38c83ba7f0d43d1f3acf3606b6bb24ae54e146c8b6e4ecff341e4d33b819273
PARSER_SHA256=
SOURCE_URL=https://download.savannah.gnu.org/releases/acl/acl-2.3.2.tar.xz
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
  if (( FINISHED )); then echo "STAGE_OK: $STAGE_HOST"; else echo 'STAGE_INCOMPLETE: preserve all r1/r2 evidence' >&2; status=1; fi
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

[[ $EUID -eq 0 && -d "$LFS/etc" && -x "$LFS/usr/bin/bash" ]]
[[ -f "$SOURCE" && -f "$R1_SCRIPT" && -d "$BUILD" ]]
[[ -f "$CAPTURE_TOOL" && -f "$COMPARE_TOOL" ]]
[[ "$STAGE_HOST" == "/mnt/lfs/tmp/alp-m04-acl-stage-$RUN_ID" && "$STAGE_CHROOT" == "/tmp/alp-m04-acl-stage-$RUN_ID" ]]
[[ "$MANIFEST" == "/mnt/lfs/tmp/alp-m04-acl-2.3.2-manifest-$RUN_ID.json" && "$PREFLIGHT" == "/mnt/lfs/tmp/alp-m04-acl-2.3.2-preflight-$RUN_ID.log" ]]
[[ "$LOG" == "/mnt/lfs/tmp/alp-logs/m04-acl-2.3.2-stage-resume-$RUN_ID.log" ]]
[[ ! -e "$STAGE_HOST" && ! -e "$MANIFEST" && ! -e "$PREFLIGHT" && ! -e "$LOG" ]]
[[ ! -e "$ATTR_STAGE_COMPARE" && ! -e "$DEPENDENCY_RESOLUTION" && ! -e "$SMOKE_TRACE" && ! -e "$SMOKE_FILE" && ! -e "$PARSER" ]]
[[ -z $(findmnt -rn -R "$LFS" || true) && ! -s /sys/block/nbd0/pid ]]
[[ ! -e "$LFS/test" ]]
[[ $(sha256sum "$R1_SCRIPT" | awk '{print $1}') == "$R1_SCRIPT_SHA256" ]]
[[ $(sha256sum "$R1_BUILD_LOG" | awk '{print $1}') == "$R1_BUILD_LOG_SHA256" ]]
[[ $(sha256sum "$R1_CHECK_LOG" | awk '{print $1}') == "$R1_CHECK_LOG_SHA256" ]]
[[ $(sha256sum "$R1_TEST_SUITE" | awk '{print $1}') == "$R1_TEST_SUITE_SHA256" ]]
[[ $(sha256sum "$R1_PARSER" | awk '{print $1}') == "$R1_PARSER_SHA256" ]]
[[ $(sha256sum "$R1_PARSER_STDOUT" | awk '{print $1}') == "$R1_PARSER_STDOUT_SHA256" ]]
[[ $(md5sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_MD5" ]]
[[ $(sha256sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_SHA256" ]]
assert_alp_and_empty_db
for process in make ninja meson; do if pgrep -x "$process" >/dev/null; then echo "Refusing concurrent build: $process" >&2; exit 1; fi; done
[[ -f "$ATTR_MANIFEST" && -d "$ATTR_STAGE_HOST" && -d "$ATTR_STAGE_HOST/usr/include/attr" && -s "$ATTR_STAGE_HOST/usr/lib/libattr.so.1.1.2502" ]]
[[ $(sha256sum "$ATTR_MANIFEST" | awk '{print $1}') == "$ATTR_MANIFEST_SHA256" ]]
if python3 "$COMPARE_TOOL" --manifest "$ATTR_MANIFEST" --root "$ATTR_STAGE_HOST" > "$ATTR_STAGE_COMPARE" 2>&1; then ATTR_STAGE_COMPARE_STATUS=0; else ATTR_STAGE_COMPARE_STATUS=$?; fi
[[ "$ATTR_STAGE_COMPARE_STATUS" -eq 0 ]]
grep -Fq 'entries=75 matched=75 mismatched=0' "$ATTR_STAGE_COMPARE"
available_kib=$(df -Pk "$LFS" | awk 'NR == 2 {print $4}')
[[ "$available_kib" =~ ^[0-9]+$ && $available_kib -ge 524288 ]]

cat > "$PARSER" <<'PY'
import re, sys

check_path, suite_path = sys.argv[1:]
expected = {"TOTAL": 15, "PASS": 8, "SKIP": 4, "XFAIL": 2, "FAIL": 1, "XPASS": 0, "ERROR": 0}
check_names = {
    "FAIL": ["test/cp.test"],
    "SKIP": ["test/root/getfacl.test", "test/root/permissions.test", "test/root/restore.test", "test/root/setfacl.test"],
    "XFAIL": ["test/nfs/nfs-dir.test", "test/nfs/nfsacl.test"],
    "XPASS": [], "ERROR": [],
    "PASS": ["test/getfacl-lfs.test", "test/getfacl-noacl.test", "test/getfacl-recursive.test", "test/malformed-restore.test", "test/misc.test", "test/sbits-restore.test", "test/setfacl-X.test", "test/utf8-filenames.test"],
}
suite_names = {kind: [name.removesuffix(".test") for name in names] for kind, names in check_names.items() if kind != "PASS"}
def parse_summary(path, kinds):
    summary = {}
    rows = {key: [] for key in kinds}
    with open(path, encoding="utf-8", errors="replace") as f:
        lines = f.read().splitlines()
    for line in lines:
        if line.startswith("# "):
            match = re.fullmatch(r"# ([A-Z]+):\s+([0-9]+)", line)
            if not match or match.group(1) not in expected or match.group(1) in summary:
                raise SystemExit(f"unexpected or duplicate summary row in {path}: {line}")
            summary[match.group(1)] = int(match.group(2))
        match = re.fullmatch(r"(PASS|FAIL|SKIP|XFAIL|XPASS|ERROR):\s+(test/\S+)", line)
        if match and match.group(1) in rows:
            rows[match.group(1)].append(match.group(2))
    if summary != expected:
        raise SystemExit(f"summary mismatch in {path}: {summary}")
    return rows
check_rows = parse_summary(check_path, check_names)
suite_rows = parse_summary(suite_path, suite_names)
for kind in check_names:
    if sorted(check_rows[kind]) != sorted(check_names[kind]):
        raise SystemExit(f"unexpected {kind} test names in {check_path}: {check_rows[kind]}")
    if kind not in suite_names:
        continue
    if sorted(suite_rows[kind]) != sorted(suite_names[kind]):
        raise SystemExit(f"unexpected {kind} test names in {suite_path}: {suite_rows[kind]}")
print("ACL_R1_TEST_EVIDENCE=verified; TOTAL=15 PASS=8 SKIP=4 XFAIL=2 FAIL=1 XPASS=0 ERROR=0")
PY
chmod 644 "$PARSER"
PARSER_SHA256=$(sha256sum "$PARSER" | awk '{print $1}')
[[ "$PARSER_SHA256" == "$EXPECTED_PARSER_SHA256" ]]
export PARSER_SHA256
python3 "$PARSER" "$R1_CHECK_LOG" "$R1_TEST_SUITE" > "$PREFLIGHT" 2>&1
mkdir -p /mnt/lfs/tmp/alp-logs
exec > >(tee -a "$LOG") 2>&1
echo "Builder=$(hostname) source=$(sha256sum "$SOURCE")"
echo "resume_from_build=$BUILD; r1_log_sha256=$R1_BUILD_LOG_SHA256; r1_check_sha256=$R1_CHECK_LOG_SHA256; r1_suite_sha256=$R1_TEST_SUITE_SHA256"
echo "r1_parser_sha256=$R1_PARSER_SHA256 r2_validation_parser_sha256=$PARSER_SHA256"
echo 'operation=DESTDIR install only; configure/build/check are forbidden; rootfs_merge=forbidden'
echo "attr_manifest_sha256=$ATTR_MANIFEST_SHA256 attr_stage_comparison=$ATTR_STAGE_COMPARE_STATUS (75/75)"
cat "$PREFLIGHT"
mkdir -p "$STAGE_HOST" /mnt/lfs/tmp/alp-logs
bind_mount() { local src=$1 dst=$2; if mountpoint -q "$dst"; then echo "Refusing pre-existing mount: $dst" >&2; return 1; fi; mount --bind "$src" "$dst"; MOUNTS+=("$dst"); }
bind_mount /dev "$LFS/dev"; bind_mount /dev/pts "$LFS/dev/pts"; bind_mount /proc "$LFS/proc"; bind_mount /sys "$LFS/sys"; bind_mount /run "$LFS/run"
chroot "$LFS" /usr/bin/env -i HOME=/root TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 BUILD_CHROOT="$BUILD_CHROOT" /bin/bash --noprofile --norc -c 'cd "$BUILD_CHROOT" && make DESTDIR="/tmp/alp-m04-acl-stage-20260924-r2" install' 2>&1 | tee -a "$LOG"
[[ -x "$STAGE_HOST/usr/bin/chacl" && -x "$STAGE_HOST/usr/bin/getfacl" && -x "$STAGE_HOST/usr/bin/setfacl" ]]
[[ -s "$STAGE_HOST/usr/lib/libacl.so" || -L "$STAGE_HOST/usr/lib/libacl.so" ]]
[[ -s "$STAGE_HOST/usr/lib/libacl.so.1" || -L "$STAGE_HOST/usr/lib/libacl.so.1" ]]
readelf -d "$STAGE_HOST/usr/lib/libacl.so.1" | grep -Fq 'Shared library: [libattr.so.1]'
if chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib:$ATTR_STAGE_CHROOT/usr/lib" /usr/bin/ldd "$STAGE_CHROOT/usr/lib/libacl.so.1" > "$DEPENDENCY_RESOLUTION" 2>&1; then :; else cat "$DEPENDENCY_RESOLUTION" >&2; exit 1; fi
grep -Fq "libattr.so.1 => $ATTR_STAGE_CHROOT/usr/lib/libattr.so.1" "$DEPENDENCY_RESOLUTION"
install -m 600 /dev/null "$SMOKE_FILE"
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib:$ATTR_STAGE_CHROOT/usr/lib" LD_DEBUG=libs /bin/bash --noprofile --norc -c "'$STAGE_CHROOT/usr/bin/setfacl' -m u:1001:r-- '/tmp/alp-m04-acl-smoke-file-20260924-r2' && '$STAGE_CHROOT/usr/bin/getfacl' -ncp '/tmp/alp-m04-acl-smoke-file-20260924-r2' | grep -Fqx 'user:1001:r--'" 2> "$SMOKE_TRACE"
grep -Fq "calling init: $STAGE_CHROOT/usr/lib/libacl.so.1" "$SMOKE_TRACE"
grep -Fq "calling init: $ATTR_STAGE_CHROOT/usr/lib/libattr.so.1" "$SMOKE_TRACE"
rm -f "$SMOKE_FILE"
python3 "$CAPTURE_TOOL" --stage "$STAGE_HOST" --name acl --version 2.3.2 --source-url "$SOURCE_URL" --source-sha256 "$EXPECTED_SHA256" --output "$MANIFEST" | tee -a "$PREFLIGHT" "$LOG"
if python3 "$COMPARE_TOOL" --manifest "$MANIFEST" --root "$STAGE_HOST" >> "$PREFLIGHT" 2>&1; then STAGE_COMPARE_STATUS=0; else STAGE_COMPARE_STATUS=$?; fi
[[ "$STAGE_COMPARE_STATUS" -eq 0 ]]
if python3 "$COMPARE_TOOL" --manifest "$MANIFEST" --root "$LFS" >> "$PREFLIGHT" 2>&1; then ROOTFS_COMPARE_STATUS=0; else ROOTFS_COMPARE_STATUS=$?; fi
case "$ROOTFS_COMPARE_STATUS" in 0) echo 'ROOTFS_PREFLIGHT=all staged paths match' | tee -a "$PREFLIGHT" ;; 1) echo 'ROOTFS_PREFLIGHT=staged paths differ; review before adoption' | tee -a "$PREFLIGHT" ;; *) echo "ROOTFS_PREFLIGHT=comparator error $ROOTFS_COMPARE_STATUS" | tee -a "$PREFLIGHT"; exit "$ROOTFS_COMPARE_STATUS" ;; esac
cat "$DEPENDENCY_RESOLUTION" "$PREFLIGHT"; assert_alp_and_empty_db
[[ ! -e "$LFS/test" && ! -s /sys/block/nbd0/pid ]]
FINISHED=1
