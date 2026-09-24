#!/usr/bin/env bash
set -Eeuo pipefail

# LFS 12.4-systemd Shadow 4.18.0 PAM-enabled BLFS recipe, isolated DESTDIR.
LFS=/mnt/lfs
RUN_ID=20260924-r1
BUILD=/mnt/lfs/build/shadow-4.18.0-m04-$RUN_ID
STAGE_HOST=/mnt/lfs/tmp/alp-m04-shadow-stage-$RUN_ID
STAGE_CHROOT=/tmp/alp-m04-shadow-stage-$RUN_ID
SOURCE=/mnt/lfs/sources/shadow-4.18.0.tar.xz
LOG=/mnt/lfs/tmp/alp-logs/m04-shadow-4.18.0-stage-$RUN_ID.log
MANIFEST=/mnt/lfs/tmp/alp-m04-shadow-4.18.0-manifest-$RUN_ID.json
PREFLIGHT=/mnt/lfs/tmp/alp-m04-shadow-4.18.0-preflight-$RUN_ID.log
STAGE_COMPARE=/mnt/lfs/tmp/alp-m04-shadow-4.18.0-stage-compare-$RUN_ID.log
DEPCHECK=/mnt/lfs/tmp/alp-m04-libxcrypt-dependency-check-shadow-$RUN_ID.log
SOURCE_URL=https://github.com/shadow-maint/shadow/releases/download/4.18.0/shadow-4.18.0.tar.xz
# LFS package-list MD5; SHA-256 independently cross-checked against Debian's
# accepted upstream source tarball record. The upstream release provides GPG sig.
# https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter03/packages.html
# https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/shadow.html
# https://www.linuxfromscratch.org/blfs/view/12.4-systemd/postlfs/shadow.html
EXPECTED_MD5=30ef46f54363db1d624587be68794ef2
EXPECTED_SHA256=add4604d3bc410344433122a819ee4154b79dd8316a56298c60417e637c07608
ALP_SHA256=7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132
EMPTY_DB_SHA256=40a9bcde751533fc237fae2b7e5eaebbbfd5779f3069c09f0590c07be184f165
LIBXCRYPT_STAGE=/mnt/lfs/tmp/alp-m04-libxcrypt-stage-r1
LIBXCRYPT_STAGE_CHROOT=/tmp/alp-m04-libxcrypt-stage-r1
LIBXCRYPT_MANIFEST=/mnt/lfs/tmp/alp-m04-libxcrypt-4.4.38-manifest-20260924-r1.json
LIBXCRYPT_MANIFEST_SHA256=69cca7a3a093e241e697e5d0045aeda3ff34bbdd177e4ed665a9990856a914a2
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CAPTURE_TOOL="$SCRIPT_DIR/capture-package-manifest.py"
COMPARE_TOOL="$SCRIPT_DIR/compare-package-manifest.py"
MOUNTS=(); FINISHED=0

assert_no_lfs_mounts() {
  local output status
  if output=$(findmnt -rn -R "$LFS"); then
    echo "Refusing: mounts remain below $LFS: $output" >&2
    return 1
  else
    status=$?
  fi
  [[ $status -eq 1 ]] || { echo "Cannot verify mounts below $LFS (findmnt status $status)" >&2; return 1; }
}

assert_alp_and_empty_db() {
  [[ $(sha256sum "$LFS/usr/lib/alp/alp.py" | awk '{print $1}') == "$ALP_SHA256" ]]
  [[ $(sha256sum "$LFS/var/lib/alp/db.json" | awk '{print $1}') == "$EMPTY_DB_SHA256" ]]
  python3 - "$LFS/var/lib/alp/db.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as stream:
    db = json.load(stream)
if db.get("schema_version") != 1 or db.get("packages") != {}:
    raise SystemExit("expected pinned Alp and empty package database")
PY
}

assert_nbd_idle() {
  local mounts sources status pgrep_status
  [[ -b /dev/nbd0 ]] || { echo 'Cannot verify nbd0: block device is absent' >&2; return 1; }
  if [[ -e /sys/block/nbd0/pid ]]; then
    [[ -r /sys/block/nbd0/pid ]] || { echo 'Cannot read nbd0 pid sysfs attribute' >&2; return 1; }
    [[ -z $(tr -d '[:space:]' < /sys/block/nbd0/pid) ]] || { echo 'Refusing active nbd0 PID' >&2; return 1; }
  else
    [[ $(cat /sys/block/nbd0/size) == 0 ]] || { echo 'Refusing nbd0 with nonzero size (PID sysfs attribute absent)' >&2; return 1; }
  fi
  mounts=$(lsblk -dn -o MOUNTPOINTS /dev/nbd0) || { echo 'Cannot inspect nbd0 mountpoints' >&2; return 1; }
  [[ -z $(printf '%s' "$mounts" | tr -d '[:space:]') ]] || { echo "Refusing nbd0 mountpoints: $mounts" >&2; return 1; }
  if sources=$(findmnt -rn -S /dev/nbd0); then
    echo "Refusing nbd0 source reported by findmnt: ${sources:-<empty output>}" >&2
    return 1
  else
    status=$?
    [[ $status -eq 1 ]] || { echo "Cannot verify nbd0 mount source (findmnt status $status)" >&2; return 1; }
  fi
  if pgrep -a qemu-nbd >/dev/null; then
    echo 'Refusing while qemu-nbd is running' >&2; return 1
  else
    pgrep_status=$?
    [[ $pgrep_status -eq 1 ]] || { echo "Cannot verify qemu-nbd process state (pgrep status $pgrep_status)" >&2; return 1; }
  fi
  echo 'NBD_IDLE: verified'
}

hash_tree_metadata() {
  local directory=$1
  find "$directory" -printf '%y %m %u %g %s %p %l\n' | LC_ALL=C sort | sha256sum | awk '{print $1}'
}

hash_file_tree() {
  local directory=$1
  {
    hash_tree_metadata "$directory"
    find "$directory" -type f -print0 | sort -z | xargs -0 -r sha256sum
  } | sha256sum | awk '{print $1}'
}

hash_guarded_path() {
  local path=$1
  if [[ -L "$path" ]]; then
    printf 'symlink %s %s\n' "$(stat -c '%a %u %g' "$path")" "$(readlink "$path")"
  elif [[ -f "$path" ]]; then
    printf 'file %s %s\n' "$(stat -c '%a %u %g %s' "$path")" "$(sha256sum "$path" | awk '{print $1}')"
  elif [[ -d "$path" ]]; then
    printf 'dir %s\n' "$(stat -c '%a %u %g' "$path")"
  else
    printf 'missing\n'
  fi
}

cleanup() {
  local status=$? i
  trap - EXIT
  set +e
  for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do
    umount "${MOUNTS[$i]}" || { echo "CLEANUP_FAILED: cannot unmount ${MOUNTS[$i]}" >&2; status=1; }
  done
  assert_no_lfs_mounts || status=1
  if (( FINISHED )) && (( status == 0 )); then
    echo "STAGE_OK: $STAGE_HOST"
  else
    echo 'STAGE_INCOMPLETE: preserve files for diagnosis' >&2
    (( status != 0 )) || status=1
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'status=$?; echo "FAILED line $LINENO status $status: $BASH_COMMAND" >&2; exit "$status"' ERR

[[ $EUID -eq 0 && -d "$LFS/etc" && -x "$LFS/usr/bin/bash" && -x "$LFS/usr/bin/passwd" && -x "$LFS/usr/bin/login" && -f "$SOURCE" ]]
[[ "$ALP_SHA256" =~ ^[0-9a-f]{64}$ && "$EMPTY_DB_SHA256" =~ ^[0-9a-f]{64}$ && "$LIBXCRYPT_MANIFEST_SHA256" =~ ^[0-9a-f]{64}$ ]]
[[ -f "$CAPTURE_TOOL" && -f "$COMPARE_TOOL" && -f "$LIBXCRYPT_MANIFEST" && -d "$LIBXCRYPT_STAGE/usr" ]]
[[ -r "$LFS/usr/include/security/pam_appl.h" && -e "$LFS/usr/lib/libpam.so" ]]
[[ $(sha256sum "$LIBXCRYPT_MANIFEST" | awk '{print $1}') == "$LIBXCRYPT_MANIFEST_SHA256" ]]
[[ ! -e "$BUILD" && ! -e "$STAGE_HOST" && ! -e "$LOG" && ! -e "$MANIFEST" && ! -e "$PREFLIGHT" && ! -e "$STAGE_COMPARE" && ! -e "$DEPCHECK" ]]
assert_no_lfs_mounts
assert_nbd_idle
for process in make ninja meson cmake; do
  if pgrep -x "$process" >/dev/null; then
    echo "Refusing concurrent build: $process" >&2; exit 1
  else
    pgrep_status=$?
    [[ $pgrep_status -eq 1 ]] || { echo "Cannot inspect process state for $process (pgrep status $pgrep_status)" >&2; exit 1; }
  fi
done
if temp_images=$(find /tmp /mnt/lfs/tmp -maxdepth 3 -type f \( -iname '*.vhdx' -o -iname '*.vhd' -o -iname '*.raw' \)); then
  [[ -z "$temp_images" ]] || { echo "Refusing to start while an image is present in a temporary directory: $temp_images" >&2; exit 1; }
else
  echo 'Cannot inspect temporary directories for disk images' >&2; exit 1
fi
assert_alp_and_empty_db
[[ $(md5sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_MD5" ]]
[[ $(sha256sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_SHA256" ]]
available_kib=$(df -Pk "$LFS" | awk 'NR == 2 {print $4}')
[[ "$available_kib" =~ ^[0-9]+$ && $available_kib -ge 524288 ]]

if python3 "$COMPARE_TOOL" --manifest "$LIBXCRYPT_MANIFEST" --root "$LIBXCRYPT_STAGE" > "$DEPCHECK" 2>&1; then
  dependency_status=0
else
  dependency_status=$?
fi
[[ $dependency_status -eq 0 ]]
python3 - "$DEPCHECK" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
match = re.search(r"entries=(\d+) matched=(\d+) mismatched=(\d+)", text)
if not match or tuple(map(int, match.groups())) != (25, 25, 0):
    raise SystemExit("pinned Libxcrypt dependency stage is not an exact 25/25 match")
PY

PAM_TREE_BEFORE=$(hash_file_tree "$LFS/etc/pam.d")
LOGIN_DEFS_BEFORE=$(hash_guarded_path "$LFS/etc/login.defs")
PASSWD_DB_BEFORE=$(hash_guarded_path "$LFS/etc/passwd")
SHADOW_DB_BEFORE=$(hash_guarded_path "$LFS/etc/shadow")
GROUP_DB_BEFORE=$(hash_guarded_path "$LFS/etc/group")
GSHADOW_DB_BEFORE=$(hash_guarded_path "$LFS/etc/gshadow")
USERADD_DEFAULTS_BEFORE=$(hash_guarded_path "$LFS/etc/default/useradd")
assert_alp_and_empty_db

mkdir -p /mnt/lfs/build /mnt/lfs/tmp/alp-logs
exec > >(tee -a "$LOG") 2>&1
echo "Builder=$(hostname) run_id=$RUN_ID source=$(sha256sum "$SOURCE")"
echo 'Recipe=BLFS 12.4-systemd Shadow with Linux-PAM; upstream test suite=none'
echo 'install_mode=DESTDIR; pamddir=; rootfs_merge=forbidden'
echo "ROOTFS_ALP_SHA256=$ALP_SHA256 ROOTFS_ALP_DB_SHA256=$EMPTY_DB_SHA256"
echo "LIBXCRYPT_MANIFEST_SHA256=$LIBXCRYPT_MANIFEST_SHA256 dependency_stage_entries=25/25"
echo "LIBXCRYPT_DEPENDENCY_CHECK_SHA256=$(sha256sum "$DEPCHECK" | awk '{print $1}')"
echo "AVAILABLE_KIB=$available_kib"
echo "PAM_TREE_BEFORE=$PAM_TREE_BEFORE"
echo "LOGIN_DEFS_BEFORE=$LOGIN_DEFS_BEFORE"
echo "PASSWD_DB_BEFORE=$PASSWD_DB_BEFORE"
echo "SHADOW_DB_BEFORE=$SHADOW_DB_BEFORE"
echo "GROUP_DB_BEFORE=$GROUP_DB_BEFORE"
echo "GSHADOW_DB_BEFORE=$GSHADOW_DB_BEFORE"
echo "USERADD_DEFAULTS_BEFORE=$USERADD_DEFAULTS_BEFORE"

mkdir -p "$BUILD" "$STAGE_HOST"
tar -xJf "$SOURCE" -C "$BUILD" --strip-components=1
mkdir -p "$BUILD/tmp"
chown -R 1001:1001 "$BUILD"
bind_mount() {
  local src=$1 dst=$2
  if mountpoint -q "$dst"; then echo "Refusing pre-existing mount: $dst" >&2; return 1; fi
  mount --bind "$src" "$dst"
  MOUNTS+=("$dst")
}
bind_mount /dev "$LFS/dev"
bind_mount /dev/pts "$LFS/dev/pts"
bind_mount /proc "$LFS/proc"
bind_mount /sys "$LFS/sys"
bind_mount /run "$LFS/run"

# Follow BLFS 12.4's PAM rebuild recipe. Keep its config-file edits in source;
# pamddir= ensures no shipped /etc/pam.d file can replace the custom rootfs PAM.
chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
  HOME=/home/lfs TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
  TMPDIR=/build/shadow-4.18.0-m04-$RUN_ID/tmp \
  CPPFLAGS=-I/tmp/alp-m04-libxcrypt-stage-r1/usr/include \
  LDFLAGS=-L/tmp/alp-m04-libxcrypt-stage-r1/usr/lib\ -L/usr/lib \
  LD_LIBRARY_PATH=/tmp/alp-m04-libxcrypt-stage-r1/usr/lib \
  /bin/bash --noprofile --norc -c '
    set -Eeuo pipefail
    cd /build/shadow-4.18.0-m04-20260924-r1
    sed -i '\''s/groups$(EXEEXT) //'\'' src/Makefile.in
    find man -name Makefile.in -exec sed -i '\''s/groups\.1 / /'\'' {} \;
    find man -name Makefile.in -exec sed -i '\''s/getspnam\.3 / /'\'' {} \;
    find man -name Makefile.in -exec sed -i '\''s/passwd\.5 / /'\'' {} \;
    sed -e '\''s@#ENCRYPT_METHOD DES@ENCRYPT_METHOD YESCRYPT@'\'' \
        -e '\''s@/var/spool/mail@/var/mail@'\''                   \
        -e '\''/PATH=/{s@/sbin:@@;s@/bin:@@}'\''                  \
        -i etc/login.defs
    ./configure --prefix=/usr --sysconfdir=/etc --disable-static \
      --without-libbsd --with-libpam --with-bcrypt --with-yescrypt
    grep -Fx '\''ac_cv_lib_pam_pam_start=yes'\'' config.log >/dev/null
    make
  '

chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
  CPPFLAGS=-I/tmp/alp-m04-libxcrypt-stage-r1/usr/include \
  LDFLAGS=-L/tmp/alp-m04-libxcrypt-stage-r1/usr/lib\ -L/usr/lib \
  LD_LIBRARY_PATH=/tmp/alp-m04-libxcrypt-stage-r1/usr/lib \
  /bin/bash --noprofile --norc -c '
    set -Eeuo pipefail
    cd /build/shadow-4.18.0-m04-20260924-r1
    make DESTDIR=/tmp/alp-m04-shadow-stage-20260924-r1 exec_prefix=/usr pamddir= install
  '
if [[ -e "$STAGE_HOST/etc/pam.d" || -L "$STAGE_HOST/etc/pam.d" ]]; then
  [[ ! -L "$STAGE_HOST/etc/pam.d" && -d "$STAGE_HOST/etc/pam.d" && -z $(find "$STAGE_HOST/etc/pam.d" -mindepth 1 -print -quit) ]] || {
    echo 'Refusing: staged Shadow contains PAM config files despite pamddir=' >&2; exit 1;
  }
fi
[[ -x "$STAGE_HOST/usr/bin/passwd" && -x "$STAGE_HOST/usr/bin/login" ]]
[[ -x "$STAGE_HOST/usr/bin/su" && -x "$STAGE_HOST/usr/sbin/useradd" ]]
[[ -s "$STAGE_HOST/etc/login.defs" ]]
for pam_binary in "$STAGE_HOST/usr/bin/login" "$STAGE_HOST/usr/bin/su"; do
  readelf -d "$pam_binary" | grep -F 'Shared library: [libpam.so.0]' >/dev/null || {
    echo "Refusing: $pam_binary was not linked to Linux-PAM" >&2; exit 1;
  }
  nm -D "$pam_binary" | grep -Eq '[[:space:]]U[[:space:]]pam_start(@|$)' || {
    echo "Refusing: $pam_binary does not reference pam_start" >&2; exit 1;
  }
done

# No test suite is shipped. Exercise staged passwd help and assert that its
# libcrypt dependency resolves from the pinned Libxcrypt stage, not rootfs.
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
  LD_LIBRARY_PATH=/tmp/alp-m04-shadow-stage-20260924-r1/usr/lib:/tmp/alp-m04-libxcrypt-stage-r1/usr/lib \
  LD_DEBUG=libs \
  /bin/bash --noprofile --norc -c '
    set -Eeuo pipefail
    readelf -d /tmp/alp-m04-shadow-stage-20260924-r1/usr/bin/passwd | grep -F "Shared library: [libcrypt.so.2]"
    /tmp/alp-m04-shadow-stage-20260924-r1/usr/bin/passwd --help >/dev/null
  ' 2> "$BUILD/passwd-stage-loader-trace.log"
grep -Eq "calling init: $LIBXCRYPT_STAGE_CHROOT/usr/lib/libcrypt\.so\.2(\.0\.0)?$" "$BUILD/passwd-stage-loader-trace.log"
grep -F "$LIBXCRYPT_STAGE_CHROOT/usr/lib/libcrypt.so.2" "$BUILD/passwd-stage-loader-trace.log" >/dev/null

assert_alp_and_empty_db
assert_nbd_idle
[[ $(hash_file_tree "$LFS/etc/pam.d") == "$PAM_TREE_BEFORE" ]]
[[ $(hash_guarded_path "$LFS/etc/login.defs") == "$LOGIN_DEFS_BEFORE" ]]
[[ $(hash_guarded_path "$LFS/etc/passwd") == "$PASSWD_DB_BEFORE" ]]
[[ $(hash_guarded_path "$LFS/etc/shadow") == "$SHADOW_DB_BEFORE" ]]
[[ $(hash_guarded_path "$LFS/etc/group") == "$GROUP_DB_BEFORE" ]]
[[ $(hash_guarded_path "$LFS/etc/gshadow") == "$GSHADOW_DB_BEFORE" ]]
[[ $(hash_guarded_path "$LFS/etc/default/useradd") == "$USERADD_DEFAULTS_BEFORE" ]]

{
  echo 'package=shadow version=4.18.0'
  echo "source_url=$SOURCE_URL"
  echo "source_md5=$EXPECTED_MD5 (LFS package list)"
  echo "source_sha256=$EXPECTED_SHA256 (Debian accepted upstream source record; not labeled as upstream sidecar)"
  echo 'recipe=BLFS 12.4-systemd PAM-enabled rebuild; no upstream test suite'
  echo "libxcrypt_dependency_manifest_sha256=$LIBXCRYPT_MANIFEST_SHA256"
  echo "libxcrypt_dependency_check_sha256=$(sha256sum "$DEPCHECK" | awk '{print $1}')"
  echo "passwd_loader_trace_sha256=$(sha256sum "$BUILD/passwd-stage-loader-trace.log" | awk '{print $1}')"
  echo "pam_tree_sha256=$PAM_TREE_BEFORE"
  echo "login_defs_sha256=$LOGIN_DEFS_BEFORE"
  echo "etc_passwd_sha256=$PASSWD_DB_BEFORE"
  echo "etc_shadow_sha256=$SHADOW_DB_BEFORE"
  echo "etc_group_sha256=$GROUP_DB_BEFORE"
  echo "etc_gshadow_sha256=$GSHADOW_DB_BEFORE"
  echo "etc_default_useradd_sha256=$USERADD_DEFAULTS_BEFORE"
  echo 'install_mode=DESTDIR; pamddir=; rootfs_merge=forbidden'
} > "$PREFLIGHT"

python3 "$CAPTURE_TOOL" --stage "$STAGE_HOST" --name shadow --version 4.18.0 --source-url "$SOURCE_URL" --source-sha256 "$EXPECTED_SHA256" --output "$MANIFEST" | tee -a "$PREFLIGHT"
if python3 "$COMPARE_TOOL" --manifest "$MANIFEST" --root "$STAGE_HOST" > "$STAGE_COMPARE" 2>&1; then
  stage_compare_status=0
else
  stage_compare_status=$?
fi
[[ $stage_compare_status -eq 0 ]]
python3 - "$MANIFEST" "$STAGE_COMPARE" <<'PY' | tee -a "$PREFLIGHT"
import json, re, sys
with open(sys.argv[1], encoding="utf-8") as stream:
    expected = len(json.load(stream)["entries"])
with open(sys.argv[2], encoding="utf-8") as stream:
    report = stream.read()
match = re.search(r"entries=(\d+) matched=(\d+) mismatched=(\d+)", report)
if not match:
    raise SystemExit("stage comparator summary missing")
entries, matched, mismatched = map(int, match.groups())
if entries != expected or matched != expected or mismatched != 0:
    raise SystemExit(f"stage manifest mismatch: expected={expected}, report={entries}/{matched}/{mismatched}")
print(f"STAGE_COMPARE_OK: entries={entries} matched={matched} mismatched=0")
PY
if python3 "$COMPARE_TOOL" --manifest "$MANIFEST" --root "$LFS" >> "$PREFLIGHT" 2>&1; then
  rootfs_compare_status=0
else
  rootfs_compare_status=$?
fi
case "$rootfs_compare_status" in
  0) echo 'ROOTFS_PREFLIGHT=all staged paths match' | tee -a "$PREFLIGHT" ;;
  1) echo 'ROOTFS_PREFLIGHT=staged paths differ; review before adoption' | tee -a "$PREFLIGHT" ;;
  *) echo "ROOTFS_PREFLIGHT=comparator error $rootfs_compare_status" | tee -a "$PREFLIGHT"; exit "$rootfs_compare_status" ;;
esac
cat "$PREFLIGHT"
assert_alp_and_empty_db
assert_nbd_idle
[[ $(hash_file_tree "$LFS/etc/pam.d") == "$PAM_TREE_BEFORE" ]]
[[ $(hash_guarded_path "$LFS/etc/login.defs") == "$LOGIN_DEFS_BEFORE" ]]
[[ $(hash_guarded_path "$LFS/etc/passwd") == "$PASSWD_DB_BEFORE" ]]
[[ $(hash_guarded_path "$LFS/etc/shadow") == "$SHADOW_DB_BEFORE" ]]
[[ $(hash_guarded_path "$LFS/etc/group") == "$GROUP_DB_BEFORE" ]]
[[ $(hash_guarded_path "$LFS/etc/gshadow") == "$GSHADOW_DB_BEFORE" ]]
[[ $(hash_guarded_path "$LFS/etc/default/useradd") == "$USERADD_DEFAULTS_BEFORE" ]]
FINISHED=1
