#!/usr/bin/env bash
set -Eeuo pipefail

# Validate the preserved r2 ACL DESTDIR install only. Never build, install,
# test, mutate /usr, or merge this stage into the rootfs.
LFS=/mnt/lfs
RUN_ID=20260924-r3
SOURCE=/mnt/lfs/sources/acl-2.3.2.tar.xz
EXPECTED_MD5=590765dee95907dbc3c856f7255bd669
EXPECTED_SOURCE_SHA256=97203a72cae99ab89a067fe2210c1cbf052bc492b479eca7d226d9830883b0bd
ALP_SHA256=7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132

R1_BUILD_LOG=/mnt/lfs/tmp/alp-logs/m04-acl-2.3.2-stage-20260924-r1.log
R1_BUILD_LOG_SHA256=9b175f7b6c0afffdc5f7ff7e4bea29cf6c0fd5d3e1730898042beee22a52319d
R1_CHECK_LOG=/mnt/lfs/build/acl-2.3.2-m04-20260924-r1/acl-check-log
R1_CHECK_LOG_SHA256=c2e87e59c64c8651c8170bf2946dc04b395df0e056dcd6f3afc912d0f13bee3b
R1_TEST_SUITE=/mnt/lfs/build/acl-2.3.2-m04-20260924-r1/test-suite.log
R1_TEST_SUITE_SHA256=cbbd1a56c207c4ed1c74d1491466f773e8928155a786b9197dc6d7afa347ab87
R1_PARSER=/mnt/lfs/build/acl-2.3.2-m04-20260924-r1/validate-acl-tests.py
R1_PARSER_SHA256=b8f5b0eba08cb9dc3d988d630cc71a2223eb3ef58d6f947eb933e3cfef2c09b1
R1_PARSER_STDOUT=/mnt/lfs/build/acl-2.3.2-m04-20260924-r1/parser-recheck.stdout
R1_PARSER_STDOUT_SHA256=d7af067fe41df53e50f45acfd9bd3391f9dea29a008abcccce844f398aa4f190
R1_BUILD_SCRIPT=/tmp/build-m04-acl-stage-review6.sh
R1_BUILD_SCRIPT_SHA256=d831fa836d70c3ba670c79ddd0c3e1d6315c9c942527e130d5e11b9665506134

R2_INSTALL_SCRIPT=/tmp/resume-m04-acl-stage-review3.sh
R2_INSTALL_SCRIPT_SHA256=c9da0ea8475c800c0e2181a946190c0fee03501f75f75fcc8c5e4813f4f09dce
R2_BUILD_LOG=/mnt/lfs/tmp/alp-logs/m04-acl-2.3.2-stage-resume-20260924-r2.log
R2_BUILD_LOG_SHA256=e94290a8e0c3b05f3a148c1bf8c1df791540ef5819ca557ba7c80914dbc80f23
R2_PREFLIGHT=/mnt/lfs/tmp/alp-m04-acl-2.3.2-preflight-20260924-r2.log
R2_PREFLIGHT_SHA256=b6679bbec9c23c56fcceca7a74a55c98f31b571e5fabf84c084fa69036e1782e
R2_LDD_FAILURE=/mnt/lfs/tmp/alp-m04-acl-dependency-resolution-20260924-r2.log
R2_LDD_FAILURE_SHA256=a34ab9523e85bf2b370e1afb84a5998de7007958c18b9a79ff32062b0035c29b
R2_PARSER=/mnt/lfs/tmp/alp-m04-acl-result-parser-20260924-r2.py
R2_PARSER_SHA256=f38c83ba7f0d43d1f3acf3606b6bb24ae54e146c8b6e4ecff341e4d33b819273

STAGE_HOST=/mnt/lfs/tmp/alp-m04-acl-stage-20260924-r2
STAGE_CHROOT=/tmp/alp-m04-acl-stage-20260924-r2
STAGE_LIBACL=$STAGE_HOST/usr/lib/libacl.so.1.1.2302
STAGE_SETfacl=$STAGE_HOST/usr/bin/setfacl
STAGE_GETfacl=$STAGE_HOST/usr/bin/getfacl
STAGE_LIBACL_SHA256=3749b956053361fbf32283bd53c4e1fca1310775cabcc56686112ad10b6bc9cd
STAGE_SETfacl_SHA256=6f786a5b825a2f00d5d85c54dd684a621f34a8f14a2c565d4ec0a9c95d724a86
STAGE_GETfacl_SHA256=3bdee1aa37471ad738c958d0f98b9e21112f73cd379e7be33c6fcc40f0c2b1b9
ATTR_STAGE_HOST=/mnt/lfs/tmp/alp-m04-attr-stage-20260924-r3
ATTR_STAGE_CHROOT=/tmp/alp-m04-attr-stage-20260924-r3
ATTR_MANIFEST=/mnt/lfs/tmp/alp-m04-attr-2.5.2-manifest-20260924-r3.json
ATTR_MANIFEST_SHA256=3482a3a2a6dfc24733de4cac0c79147520e86db628a8309e319f6561e50ef786
R2_STAGE_MANIFEST=/mnt/lfs/tmp/alp-m04-acl-2.3.2-stage-manifest-20260924-r2.json
R2_STAGE_MANIFEST_SHA256=541a32e7f0f50bea0b18629d015431db96c661563af7e0f6b219cf10775365cc
R2_STAGE_MANIFEST_CAPTURE=/mnt/lfs/tmp/alp-m04-acl-stage-manifest-capture-20260924-r2.log
R2_STAGE_MANIFEST_CAPTURE_SHA256=5b3c1f59dfecb0849694639d235b147e78374fe2a20797d3847e68761cfdddc8
R2_STAGE_MANIFEST_COMPARE=/mnt/lfs/tmp/alp-m04-acl-stage-manifest-compare-20260924-r2.log
R2_STAGE_MANIFEST_COMPARE_SHA256=1230a2b74c31d5d3e98559d55a5db53144a6c71b22e2b4ed114753294994d1bb

PREFLIGHT=/mnt/lfs/tmp/alp-m04-acl-2.3.2-preflight-validation-$RUN_ID.log
LOG=/mnt/lfs/tmp/alp-logs/m04-acl-2.3.2-validation-$RUN_ID.log
ATTR_COMPARE=/mnt/lfs/tmp/alp-m04-acl-attr-compare-validation-$RUN_ID.log
DEPENDENCY_RESOLUTION=/mnt/lfs/tmp/alp-m04-acl-dependency-resolution-validation-$RUN_ID.log
SMOKE_TRACE=/mnt/lfs/tmp/alp-m04-acl-smoke-loader-validation-$RUN_ID.log
SMOKE_FILE=/mnt/lfs/tmp/alp-m04-acl-smoke-file-validation-$RUN_ID
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMPARE_TOOL="$SCRIPT_DIR/compare-package-manifest.py"
FINISHED=0
SMOKE_CREATED=0

cleanup() {
  local status=$?; trap - EXIT; set +e
  if (( SMOKE_CREATED )); then rm -f "$SMOKE_FILE" || status=1; fi
  if (( FINISHED )); then echo "VALIDATION_OK: existing stage $STAGE_HOST; no merge"; else echo 'VALIDATION_INCOMPLETE: preserve r1/r2/r3 evidence' >&2; status=1; fi
  if findmnt -rn -R "$LFS"; then echo "CLEANUP_FAILED: mounts remain below $LFS" >&2; status=1; fi
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
assert_nbd_empty() {
  local nbd_pid
  if [[ -e /sys/block/nbd0/pid ]]; then
    [[ -r /sys/block/nbd0/pid ]] || { echo 'nbd0 PID state exists but is unreadable' >&2; return 1; }
    nbd_pid=$(cat /sys/block/nbd0/pid)
    [[ -z "$nbd_pid" ]] || { echo "Refusing busy nbd0: pid=$nbd_pid" >&2; return 1; }
    echo 'NBD_CHECK: nbd0 pid attribute present and empty'
    return 0
  fi

  command -v lsblk >/dev/null || { echo 'Cannot verify NBD idle: lsblk unavailable' >&2; return 1; }
  command -v findmnt >/dev/null || { echo 'Cannot verify NBD idle: findmnt unavailable' >&2; return 1; }
  command -v pgrep >/dev/null || { echo 'Cannot verify NBD idle: pgrep unavailable' >&2; return 1; }
  [[ -r /sys/block/nbd0/size && -b /dev/nbd0 ]] || { echo 'Cannot verify NBD idle: size or block device unavailable' >&2; return 1; }
  local nbd_size mountpoints mount_sources pgrep_status
  nbd_size=$(cat /sys/block/nbd0/size)
  [[ $nbd_size == 0 ]] || { echo "Refusing nonempty nbd0: size=$nbd_size" >&2; return 1; }
  mountpoints=$(lsblk -dnro MOUNTPOINTS /dev/nbd0) || { echo 'Cannot read nbd0 mountpoints' >&2; return 1; }
  [[ -z $mountpoints ]] || { echo "Refusing mounted nbd0: $mountpoints" >&2; return 1; }
  mount_sources=$(findmnt -rn -o SOURCE) || { echo 'Cannot read mount sources' >&2; return 1; }
  if grep -Eq '^/dev/nbd[0-9]+(p[0-9]+)?$' <<< "$mount_sources"; then
    echo 'Refusing: an NBD device is mounted' >&2
    return 1
  fi
  if pgrep -a qemu-nbd >/dev/null; then
    echo 'Refusing: qemu-nbd process is running' >&2
    return 1
  else
    pgrep_status=$?
    [[ $pgrep_status -eq 1 ]] || { echo "Cannot verify qemu-nbd process state (pgrep status $pgrep_status)" >&2; return 1; }
  fi
  echo 'NBD_CHECK: pid attribute absent; size=0, block device present, no mountpoints/sources, qemu-nbd absent'
}

[[ $EUID -eq 0 && -d "$LFS/etc" && -x "$LFS/usr/bin/bash" ]]
[[ -f "$COMPARE_TOOL" && -f "$SOURCE" ]]
[[ -f "$R1_BUILD_LOG" && -f "$R1_CHECK_LOG" && -f "$R1_TEST_SUITE" && -f "$R1_PARSER" && -f "$R1_PARSER_STDOUT" && -f "$R1_BUILD_SCRIPT" ]]
[[ -f "$R2_INSTALL_SCRIPT" && -f "$R2_BUILD_LOG" && -f "$R2_PREFLIGHT" && -f "$R2_LDD_FAILURE" && -f "$R2_PARSER" ]]
[[ ! -e "$PREFLIGHT" && ! -L "$PREFLIGHT" && ! -e "$LOG" && ! -L "$LOG" && ! -e "$ATTR_COMPARE" && ! -L "$ATTR_COMPARE" && ! -e "$DEPENDENCY_RESOLUTION" && ! -L "$DEPENDENCY_RESOLUTION" && ! -e "$SMOKE_TRACE" && ! -L "$SMOKE_TRACE" && ! -e "$SMOKE_FILE" && ! -L "$SMOKE_FILE" ]]
[[ -z $(findmnt -rn -R "$LFS" || true) && ! -e "$LFS/test" ]]
assert_nbd_empty
[[ ! -e /mnt/lfs/tmp/alp-m04-acl-stage-20260924-r3 ]]
[[ $(sha256sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_SOURCE_SHA256" && $(md5sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_MD5" ]]
[[ $(sha256sum "$R1_BUILD_LOG" | awk '{print $1}') == "$R1_BUILD_LOG_SHA256" ]]
[[ $(sha256sum "$R1_CHECK_LOG" | awk '{print $1}') == "$R1_CHECK_LOG_SHA256" ]]
[[ $(sha256sum "$R1_TEST_SUITE" | awk '{print $1}') == "$R1_TEST_SUITE_SHA256" ]]
[[ $(sha256sum "$R1_PARSER" | awk '{print $1}') == "$R1_PARSER_SHA256" ]]
[[ $(sha256sum "$R1_PARSER_STDOUT" | awk '{print $1}') == "$R1_PARSER_STDOUT_SHA256" ]]
[[ $(sha256sum "$R1_BUILD_SCRIPT" | awk '{print $1}') == "$R1_BUILD_SCRIPT_SHA256" ]]
[[ $(sha256sum "$R2_INSTALL_SCRIPT" | awk '{print $1}') == "$R2_INSTALL_SCRIPT_SHA256" ]]
[[ $(sha256sum "$R2_BUILD_LOG" | awk '{print $1}') == "$R2_BUILD_LOG_SHA256" ]]
[[ $(sha256sum "$R2_PREFLIGHT" | awk '{print $1}') == "$R2_PREFLIGHT_SHA256" ]]
[[ $(sha256sum "$R2_LDD_FAILURE" | awk '{print $1}') == "$R2_LDD_FAILURE_SHA256" ]]
[[ $(sha256sum "$R2_PARSER" | awk '{print $1}') == "$R2_PARSER_SHA256" ]]
[[ $(sha256sum "$R2_STAGE_MANIFEST" | awk '{print $1}') == "$R2_STAGE_MANIFEST_SHA256" ]]
[[ $(sha256sum "$R2_STAGE_MANIFEST_CAPTURE" | awk '{print $1}') == "$R2_STAGE_MANIFEST_CAPTURE_SHA256" ]]
[[ $(sha256sum "$R2_STAGE_MANIFEST_COMPARE" | awk '{print $1}') == "$R2_STAGE_MANIFEST_COMPARE_SHA256" ]]
grep -Fq 'entries=100 types=' "$R2_STAGE_MANIFEST_CAPTURE"
grep -Fq 'entries=100 matched=100 mismatched=0' "$R2_STAGE_MANIFEST_COMPARE"
[[ $(sha256sum "$STAGE_LIBACL" | awk '{print $1}') == "$STAGE_LIBACL_SHA256" ]]
[[ $(sha256sum "$STAGE_SETfacl" | awk '{print $1}') == "$STAGE_SETfacl_SHA256" ]]
[[ $(sha256sum "$STAGE_GETfacl" | awk '{print $1}') == "$STAGE_GETfacl_SHA256" ]]
[[ -d "$STAGE_HOST" && ! -L "$STAGE_HOST" && -d "$ATTR_STAGE_HOST" && ! -L "$ATTR_STAGE_HOST" ]]
[[ -s "$STAGE_HOST/usr/lib/libacl.so.1" && -s "$ATTR_STAGE_HOST/usr/lib/libattr.so.1.1.2502" ]]
[[ $(readlink "$STAGE_HOST/usr/lib/libacl.so.1") == libacl.so.1.1.2302 && $(readlink "$STAGE_HOST/usr/lib/libacl.so") == libacl.so.1.1.2302 ]]
[[ -z $(find "$STAGE_HOST" -xtype l -print -quit) ]] || { echo 'Dangling symlink in preserved stage' >&2; exit 1; }
[[ $(sha256sum "$ATTR_MANIFEST" | awk '{print $1}') == "$ATTR_MANIFEST_SHA256" ]]
assert_alp_and_empty_db
for process in make ninja meson; do if pgrep -x "$process" >/dev/null; then echo "Refusing concurrent build: $process" >&2; exit 1; fi; done
available_kib=$(df -Pk "$LFS" | awk 'NR == 2 {print $4}')
[[ "$available_kib" =~ ^[0-9]+$ && $available_kib -ge 524288 ]]

mkdir -p /mnt/lfs/tmp/alp-logs
exec > >(tee -a "$LOG") 2>&1
echo "Builder=$(hostname) validation_id=$RUN_ID"
echo 'operation=read-only checks plus temporary smoke file; no make/install/configure/tests; no rootfs merge'
echo "source_md5=$EXPECTED_MD5 source_sha256=$EXPECTED_SOURCE_SHA256"
echo "r1_raw_log_sha256=$R1_BUILD_LOG_SHA256 r1_check_sha256=$R1_CHECK_LOG_SHA256 r1_suite_sha256=$R1_TEST_SUITE_SHA256"
echo "r2_install_log_sha256=$R2_BUILD_LOG_SHA256 stage_libacl_sha256=$STAGE_LIBACL_SHA256 stage_setfacl_sha256=$STAGE_SETfacl_SHA256"
echo "attr_manifest_sha256=$ATTR_MANIFEST_SHA256"
echo "r2_stage_manifest=$R2_STAGE_MANIFEST sha256=$R2_STAGE_MANIFEST_SHA256"
echo 'test_result_classification=8 PASS; 4 root-only SKIP; 2 upstream NFS XFAIL; known LFS FAIL test/cp.test; no rerun'

python3 "$R2_PARSER" "$R1_CHECK_LOG" "$R1_TEST_SUITE" | tee -a "$PREFLIGHT"
if python3 "$COMPARE_TOOL" --manifest "$ATTR_MANIFEST" --root "$ATTR_STAGE_HOST" > "$ATTR_COMPARE" 2>&1; then ATTR_COMPARE_STATUS=0; else ATTR_COMPARE_STATUS=$?; fi
[[ "$ATTR_COMPARE_STATUS" -eq 0 ]]
grep -Fq 'entries=75 matched=75 mismatched=0' "$ATTR_COMPARE"
readelf -d "$STAGE_LIBACL" | grep -Fq 'Shared library: [libattr.so.1]'
readelf -d "$STAGE_SETfacl" | grep -Fq 'Shared library: [libacl.so.1]'
if chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib:$ATTR_STAGE_CHROOT/usr/lib" /lib64/ld-linux-x86-64.so.2 --list "$STAGE_CHROOT/usr/bin/setfacl" > "$DEPENDENCY_RESOLUTION" 2>&1; then :; else cat "$DEPENDENCY_RESOLUTION" >&2; exit 1; fi
grep -Fq "libacl.so.1 => $STAGE_CHROOT/usr/lib/libacl.so.1" "$DEPENDENCY_RESOLUTION"
grep -Fq "libattr.so.1 => $ATTR_STAGE_CHROOT/usr/lib/libattr.so.1" "$DEPENDENCY_RESOLUTION"
SMOKE_CREATED=1
(umask 077; : > "$SMOKE_FILE")
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib:$ATTR_STAGE_CHROOT/usr/lib" LD_DEBUG=libs /bin/bash --noprofile --norc -c "'$STAGE_CHROOT/usr/bin/setfacl' -m u:1001:r-- '/tmp/alp-m04-acl-smoke-file-validation-$RUN_ID' && '$STAGE_CHROOT/usr/bin/getfacl' -ncp '/tmp/alp-m04-acl-smoke-file-validation-$RUN_ID' | grep -Fqx 'user:1001:r--'" 2> "$SMOKE_TRACE"
grep -Fq "calling init: $STAGE_CHROOT/usr/lib/libacl.so.1" "$SMOKE_TRACE"
grep -Fq "calling init: $ATTR_STAGE_CHROOT/usr/lib/libattr.so.1" "$SMOKE_TRACE"
if python3 "$COMPARE_TOOL" --manifest "$R2_STAGE_MANIFEST" --root "$STAGE_HOST" >> "$PREFLIGHT" 2>&1; then STAGE_COMPARE_STATUS=0; else STAGE_COMPARE_STATUS=$?; fi
[[ "$STAGE_COMPARE_STATUS" -eq 0 ]]
grep -Fq 'entries=100 matched=100 mismatched=0' "$PREFLIGHT"
if python3 "$COMPARE_TOOL" --manifest "$R2_STAGE_MANIFEST" --root "$LFS" >> "$PREFLIGHT" 2>&1; then ROOTFS_COMPARE_STATUS=0; else ROOTFS_COMPARE_STATUS=$?; fi
case "$ROOTFS_COMPARE_STATUS" in 0) echo 'ROOTFS_PREFLIGHT=all staged paths match' | tee -a "$PREFLIGHT" ;; 1) echo 'ROOTFS_PREFLIGHT=staged paths differ; review before adoption' | tee -a "$PREFLIGHT" ;; *) echo "ROOTFS_PREFLIGHT=comparator error $ROOTFS_COMPARE_STATUS" | tee -a "$PREFLIGHT"; exit "$ROOTFS_COMPARE_STATUS" ;; esac
cat "$ATTR_COMPARE" "$DEPENDENCY_RESOLUTION" "$PREFLIGHT"
assert_alp_and_empty_db
[[ ! -e "$LFS/test" ]]
assert_nbd_empty
FINISHED=1
