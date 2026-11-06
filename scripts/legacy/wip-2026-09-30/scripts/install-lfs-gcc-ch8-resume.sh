#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
if [[ -n "${ALPBAHOS_D34_LOCK_FD:-}" ]]; then
    readonly D34_RUN_DIR="$(dirname -- "${ALPBAHOS_D34_LOG_PATH:?D34 package log path is required}")"
    readonly CHECK_HOST_LOG="$ALPBAHOS_D34_LOG_PATH"
    readonly BUILD_ROOT="$(sed -n 's/^GCC_BUILD_DIR=//p' "$CHECK_HOST_LOG" | tail -n 1)"
    [[ "$BUILD_ROOT" == /sources/gcc-15.2.0-ch8-*/gcc-15.2.0/build ]] || {
        printf 'Invalid D34 GCC build root: %s\n' "$BUILD_ROOT" >&2
        exit 1
    }
    readonly WORK_ROOT="${BUILD_ROOT%/gcc-15.2.0/build}"
    readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
    readonly LOG="$D34_RUN_DIR/install-continuation.log"
    readonly BACKUP_DIR="$D34_RUN_DIR/gcc-pass2-before-final"
else
    readonly WORK_ROOT=/sources/gcc-15.2.0-ch8-20260926T215605550993902Z
    readonly BUILD_ROOT="$WORK_ROOT/gcc-15.2.0/build"
    readonly CHECK_HOST_LOG="$DATA/logs/lfs-12.4-systemd/gcc-ch8-build-20260926T215605550993902Z.log"
    readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
    readonly LOG="$LOG_DIR/gcc-ch8-install-$STAMP.log"
    readonly BACKUP_DIR="$DATA/backups/gcc-pass2-before-final-$STAMP"
fi
readonly SUMMARY_LOG="$LFS$WORK_ROOT/gcc-logs/test-summary.log"
readonly GCC_SUM="$LFS$BUILD_ROOT/gcc/testsuite/gcc/gcc.sum"
readonly GXX_SUM="$LFS$BUILD_ROOT/gcc/testsuite/g++/g++.sum"
readonly LIBSTDCXX_SUM="$LFS$BUILD_ROOT/x86_64-pc-linux-gnu/libstdc++-v3/testsuite/libstdc++.sum"
readonly CHROOT_INSTALL_LOG="$LFS$WORK_ROOT/gcc-logs/install.log"
readonly BACKUP_ARCHIVE="$BACKUP_DIR/gcc-pass2-toolchain.tar"
readonly MANIFEST0="$BACKUP_DIR/files.list0"
readonly MANIFEST="$BACKUP_DIR/files.list"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA" ]] || fail 'The LFS target or build data directory is missing.'
if [[ -z "${ALPBAHOS_D34_LOCK_FD:-}" ]]; then
    [[ -d "$DATA/lfs" ]] || fail 'The HDD-backed LFS build directory is missing.'
    [[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on ext4."
    [[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
fi
[[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
[[ -d "$LFS$BUILD_ROOT" && -f "$CHECK_HOST_LOG" && -f "$SUMMARY_LOG" ]] || fail 'The reviewed GCC build or its logs are missing.'
[[ -f "$GCC_SUM" && -f "$GXX_SUM" && -f "$LIBSTDCXX_SUM" ]] || fail 'The completed GCC, g++, or libstdc++ test summary is missing.'
rg -q '^GCC_CHECK_EXIT=0$' "$CHECK_HOST_LOG" || fail 'GCC make -k check did not complete successfully.'
rg -q '^GCC_TEST_SUMMARY_EXIT=0$' "$CHECK_HOST_LOG" || fail 'GCC test_summary did not complete successfully.'
rg -q '^# of unexpected failures[[:space:]]+4$' "$SUMMARY_LOG" || fail 'The GCC test results differ from the reviewed result.'
[[ "$(rg -c '^FAIL: gcc\.target/i386/pr90579\.c ' "$GCC_SUM" || true)" == 4 ]] || fail 'The known pr90579.c failures do not match the four reviewed cases.'
[[ "$(rg -c '^FAIL:' "$SUMMARY_LOG" || true)" == 4 ]] || fail 'There are unexpected FAIL records outside the four known pr90579.c cases.'
if rg -q '^(XPASS|UNRESOLVED|ERROR):' "$SUMMARY_LOG"; then
    fail 'The GCC test summary contains XPASS, UNRESOLVED, or ERROR records.'
fi
for path in \
    "$LFS$BUILD_ROOT/Makefile" \
    "$LFS/usr/bin/gcc" \
    "$LFS/usr/bin/g++" \
    "$LFS/usr/lib/gcc/x86_64-lfs-linux-gnu/15.2.0" \
    "$LFS/usr/include/c++/15.2.0"; do
    [[ -e "$path" || -L "$path" ]] || fail "Required GCC install path is missing: $path"
done
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'A make/check/test process is still active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$BACKUP_DIR"
if [[ -z "${ALPBAHOS_D34_LOCK_FD:-}" ]]; then
    exec 9>"$DATA/locks/lfs-build-writer.lock"
    flock -n 9 || fail 'Another LFS writer holds the build lock.'
fi
exec > >(tee "$LOG") 2>&1

printf 'Installing final LFS GCC 15.2.0.\n'
printf 'LFS root: %s\nBuild tree: %s\nStarted: %s\n\n' "$LFS" "$BUILD_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Reviewed tests: GCC known pr90579.c failures=4; g++, libstdc++, libgomp, libatomic, and libitm have no unexpected failures.\n'
printf 'Backing up the installed Pass 2 toolchain to %s before make install.\n' "$BACKUP_ARCHIVE"

(
    cd "$LFS"
    for path in \
        usr/bin/gcc usr/bin/g++ usr/bin/cc usr/bin/c++ usr/bin/cpp \
        usr/bin/gcc-ar usr/bin/gcc-nm usr/bin/gcc-ranlib \
        usr/bin/gcov usr/bin/gcov-dump usr/bin/gcov-tool usr/bin/lto-dump \
        usr/lib/gcc/x86_64-lfs-linux-gnu/15.2.0 \
        usr/libexec/gcc/x86_64-lfs-linux-gnu/15.2.0 \
        usr/include/c++/15.2.0 usr/share/gcc-15.2.0 \
        usr/share/man/man1/cc.1 usr/share/man/man1/cpp.1 \
        usr/share/man/man1/gcc.1 usr/share/man/man1/g++.1; do
        if [[ -e "$path" || -L "$path" ]]; then
            printf '%s\0' "$path"
        fi
    done
    find usr/lib -maxdepth 1 \( -type f -o -type l \) \
        \( -name 'libgcc*' -o -name 'libstdc++*' -o -name 'libatomic*' \
        -o -name 'libgomp*' -o -name 'libasan*' -o -name 'libubsan*' \
        -o -name 'libtsan*' -o -name 'liblsan*' -o -name 'libitm*' \
        -o -name 'libquadmath*' -o -name 'libcc1*' -o -name 'liblto_plugin*' \) \
        -printf '%p\0'
    if [[ -d usr/lib/pkgconfig ]]; then
        find usr/lib/pkgconfig -maxdepth 1 \( -type f -o -type l \) \
            \( -iname '*gcc*' -o -iname '*stdc++*' -o -iname '*gomp*' \) \
            -printf '%p\0'
    fi
) | sort -zu > "$MANIFEST0"
[[ -s "$MANIFEST0" ]] || fail 'The Pass 2 backup manifest is empty.'
tr '\0' '\n' < "$MANIFEST0" > "$MANIFEST"
sudo -n tar --create --file="$BACKUP_ARCHIVE" --numeric-owner --acls --xattrs \
    -C "$LFS" --null --files-from="$MANIFEST0"
sudo -n chown "$(id -u):$(id -g)" "$BACKUP_ARCHIVE"
tar --list --file="$BACKUP_ARCHIVE" > "$BACKUP_DIR/archive.list"
[[ -s "$BACKUP_DIR/archive.list" ]] || fail 'The Pass 2 backup archive is empty.'
printf 'Backup file count: %s\nBackup archive size: %s bytes\n' \
    "$(wc -l < "$MANIFEST")" "$(stat -c '%s' "$BACKUP_ARCHIVE")"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$BUILD_ROOT" "$WORK_ROOT/gcc-logs/install.log" "$STAMP" <<'CHROOT'
set -Eeuo pipefail
build_root="$1"
install_log="$2"
stamp="$3"
mkdir -p "$(dirname "$install_log")"
exec > >(tee "$install_log") 2>&1

cd "$build_root"
printf 'Running make install in %s\n' "$PWD"
make install

machine=$(/usr/bin/gcc -dumpmachine)
version=15.2.0
chown -v -R root:root "/usr/lib/gcc/$machine/$version/include" "/usr/lib/gcc/$machine/$version/include-fixed"

if [[ -e /usr/lib/cpp || -L /usr/lib/cpp ]]; then
    [[ "$(readlink -f /usr/lib/cpp)" == "$(readlink -f /usr/bin/cpp)" ]] || {
        printf 'Refusing to replace unexpected /usr/lib/cpp\n' >&2
        exit 1
    }
else
    ln -svr /usr/bin/cpp /usr/lib
fi

if [[ -e /usr/share/man/man1/cc.1 || -L /usr/share/man/man1/cc.1 ]]; then
    [[ "$(readlink /usr/share/man/man1/cc.1 || true)" == gcc.1 ]] || {
        printf 'Refusing to replace unexpected /usr/share/man/man1/cc.1\n' >&2
        exit 1
    }
else
    ln -sv gcc.1 /usr/share/man/man1/cc.1
fi

plugin="/usr/libexec/gcc/$machine/$version/liblto_plugin.so"
plugin_link=/usr/lib/bfd-plugins/liblto_plugin.so
[[ -e "$plugin" ]] || { printf 'Installed GCC LTO plugin is missing: %s\n' "$plugin" >&2; exit 1; }
mkdir -p /usr/lib/bfd-plugins
if [[ -e "$plugin_link" || -L "$plugin_link" ]]; then
    [[ "$(readlink -f "$plugin_link")" == "$(readlink -f "$plugin")" ]] || {
        printf 'Refusing to replace unexpected %s\n' "$plugin_link" >&2
        exit 1
    }
else
    ln -sv "../../libexec/gcc/$machine/$version/liblto_plugin.so" /usr/lib/bfd-plugins/
fi

sanity_dir="$build_root/gcc-final-sanity-$stamp"
mkdir -v "$sanity_dir"
cat > "$sanity_dir/main.c" <<'EOF'
int main(void) { return 0; }
EOF
cc -x c "$sanity_dir/main.c" -v -Wl,--verbose -o "$sanity_dir/a.out" > "$sanity_dir/dummy.log" 2>&1
readelf -l "$sanity_dir/a.out" | tee "$sanity_dir/program-headers.log"
grep -Eq 'Requesting program interpreter: /(usr/)?lib(64)?/ld-linux-x86-64\.so\.2' "$sanity_dir/program-headers.log"
for startup in Scrt1.o crti.o crtn.o; do
    grep -Eq "/usr/lib/.*/$startup succeeded" "$sanity_dir/dummy.log" || {
        printf 'GCC did not find %s under /usr/lib\n' "$startup" >&2
        exit 1
    }
done
grep -Eq '^ /usr/include$' "$sanity_dir/dummy.log"
grep -F 'attempt to open /usr/lib/libc.so.6 succeeded' "$sanity_dir/dummy.log"
grep -Eq 'found ld-linux-x86-64\.so\.2 at /usr/lib/ld-linux-x86-64\.so\.2' "$sanity_dir/dummy.log"
grep -F 'SEARCH_DIR("/usr/lib")' "$sanity_dir/dummy.log"

cat > "$sanity_dir/main.cc" <<'EOF'
#include <string>
int main() { const std::string text = "alpbahOS"; return text.empty(); }
EOF
g++ -std=c++17 "$sanity_dir/main.cc" -o "$sanity_dir/a-cxx.out"
"$sanity_dir/a-cxx.out"
ldd "$sanity_dir/a-cxx.out" | tee "$sanity_dir/ldd-cxx.log"
grep -q 'libstdc++\.so\.6 => /usr/lib/libstdc++\.so\.6' "$sanity_dir/ldd-cxx.log"

mkdir -pv /usr/share/gdb/auto-load/usr/lib
shopt -s nullglob
for file in /usr/lib/*gdb.py; do
    destination="/usr/share/gdb/auto-load/usr/lib/$(basename "$file")"
    if [[ -e "$destination" || -L "$destination" ]]; then
        if cmp -s "$file" "$destination"; then
            printf 'GDB auto-load file already installed: %s\n' "$destination"
            continue
        fi
        printf 'Refusing to overwrite existing GDB auto-load file: %s\n' "$destination" >&2
        exit 1
    fi
    mv -v "$file" "$destination"
done

gcc --version | head -n 1
g++ --version | head -n 1
printf 'GCC_MACHINE=%s\nGCC_FINAL_INSTALL=PASS\nSANITY_ARTIFACTS=%s\n' "$machine" "$sanity_dir"
CHROOT

printf '\nGCC final install and C/C++ linker sanity checks completed.\n'
printf 'Install log: %s\nPass 2 backup: %s\nFinished: %s\n' \
    "$CHROOT_INSTALL_LOG" "$BACKUP_ARCHIVE" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
