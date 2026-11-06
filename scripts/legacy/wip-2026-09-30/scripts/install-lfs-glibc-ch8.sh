#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly SOURCE_REL=/sources/glibc-2.42-ch8-20260926T183002Z/glibc-2.42
readonly BUILD_REL="$SOURCE_REL/build"
readonly SOURCE="$LFS$SOURCE_REL"
readonly BUILD="$LFS$BUILD_REL"
readonly SUMMARY="$BUILD/complete-tests.sum"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
readonly LOG="$LOG_DIR/glibc-ch8-install-$RUN_ID.log"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" ]] || fail 'The LFS target or HDD build directory is missing.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on ext4."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
[[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
[[ -f "$SOURCE/Makefile" && -f "$BUILD/config.status" ]] || fail 'The configured Glibc Chapter 8 build tree is missing.'
[[ -s "$SUMMARY" ]] || fail 'The complete Glibc test summary is missing.'

readonly -a SUBDIRS=(
    csu iconv locale localedata iconvdata assert ctype intl catgets math
    setjmp signal stdlib stdio-common libio dlfcn nptl rt malloc string
    wcsmbs timezone time dirent posix io termios resource misc socket sysvipc
    gmon gnulib wctype manual po argp conform debug mathvec support nptl_db
    inet resolv nss hesiod sunrpc nis nscd login elf
)
for dir in "${SUBDIRS[@]}"; do
    [[ -f "$BUILD/$dir/subdir-tests.sum" ]] || fail "Missing test summary for $dir."
done

expected_fails=$'FAIL: io/tst-lchmod\nFAIL: misc/tst-preadvwritev2\nFAIL: misc/tst-preadvwritev64v2\nFAIL: misc/tst-rseq'
actual_fails="$(grep '^FAIL:' "$SUMMARY" || true)"
[[ "$actual_fails" == "$expected_fails" ]] || fail 'The Glibc summary contains a different set of FAIL results.'
if grep -Eq '^(ERROR|UNRESOLVED):' "$SUMMARY"; then
    fail 'The Glibc summary contains ERROR or UNRESOLVED results.'
fi

expected_xpasses=$'XPASS: elf/tst-ifunc-isa-1\nXPASS: elf/tst-ifunc-isa-1-static\nXPASS: elf/tst-ifunc-isa-2\nXPASS: elf/tst-ifunc-isa-2-static'
actual_xpasses="$(grep '^XPASS:' "$SUMMARY" || true)"
[[ "$actual_xpasses" == "$expected_xpasses" ]] || fail 'The Glibc summary contains a different set of XPASS results.'
[[ "$(grep -Ec '^XPASS:' "$SUMMARY")" == 4 ]] || fail 'Unexpected XPASS result count.'
grep -q '^with-lld = no$' "$BUILD/config.make" || fail 'Expected binutils linker configuration was not found.'
for test in tst-ifunc-isa-1 tst-ifunc-isa-1-static tst-ifunc-isa-2 tst-ifunc-isa-2-static; do
    grep -q '^original exit status 0$' "$BUILD/elf/$test.test-result" || fail "$test did not exit successfully."
done

[[ "$(grep -Ec '^PASS:' "$SUMMARY")" == 6563 ]] || fail 'Unexpected Glibc PASS count.'
[[ "$(grep -Ec '^FAIL:' "$SUMMARY")" == 4 ]] || fail 'Unexpected Glibc FAIL count.'
[[ "$(grep -Ec '^XFAIL:' "$SUMMARY")" == 16 ]] || fail 'Unexpected Glibc XFAIL count.'
[[ "$(grep -Ec '^UNSUPPORTED:' "$SUMMARY")" == 521 ]] || fail 'Unexpected Glibc UNSUPPORTED count.'
[[ "$(grep -Ec '^XPASS:' "$SUMMARY")" == 4 ]] || fail 'Unexpected Glibc XPASS count.'

for file in /etc/ld.so.conf /etc/nsswitch.conf /etc/localtime; do
    [[ ! -e "$LFS$file" && ! -L "$LFS$file" ]] || fail "Refusing to overwrite existing target configuration: $file"
done
[[ -r "$LFS/sources/tzdata2025b.tar.gz" ]] || fail 'tzdata2025b archive is missing.'
if pgrep -af 'make (check|.*subdir=.*tests|install)' | grep -v '[i]nstall-lfs-glibc-ch8'; then
    fail 'Another LFS make/check/install process is active.'
fi

mkdir -p "$LOG_DIR"
exec >"$LOG" 2>&1
printf 'Installing Glibc 2.42 after the complete 51-subdirectory test run.\n'
printf 'Host kernel: %s\n' "$(uname -r)"
printf 'Test summary: %s\n' "$SUMMARY"
printf 'Result counts: PASS=6563 FAIL=4 XFAIL=16 UNSUPPORTED=521 XPASS=4\n'
printf 'The four FAIL and four XPASS entries were checked against the captured outputs and current build configuration.\n'
printf 'Started: %s\n\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -c '
        set -Eeuo pipefail
        work_root=/sources/glibc-2.42-ch8-20260926T183002Z
        source_root="$work_root/glibc-2.42"
        build_root="$source_root/build"

        cd "$build_root"
        touch /etc/ld.so.conf
        sed "/test-installation/s@\$(PERL)@echo not running@" -i ../Makefile
        make install
        sed "/RTLDLIST=/s@/usr@@g" -i /usr/bin/ldd

        localedef -i C -f UTF-8 C.UTF-8
        localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
        localedef -i de_DE -f ISO-8859-1 de_DE
        localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
        localedef -i de_DE -f UTF-8 de_DE.UTF-8
        localedef -i el_GR -f ISO-8859-7 el_GR
        localedef -i en_GB -f ISO-8859-1 en_GB
        localedef -i en_GB -f UTF-8 en_GB.UTF-8
        localedef -i en_HK -f ISO-8859-1 en_HK
        localedef -i en_PH -f ISO-8859-1 en_PH
        localedef -i en_US -f ISO-8859-1 en_US
        localedef -i en_US -f UTF-8 en_US.UTF-8
        localedef -i es_ES -f ISO-8859-15 es_ES@euro
        localedef -i es_MX -f ISO-8859-1 es_MX
        localedef -i fa_IR -f UTF-8 fa_IR
        localedef -i fr_FR -f ISO-8859-1 fr_FR
        localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
        localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
        localedef -i is_IS -f ISO-8859-1 is_IS
        localedef -i is_IS -f UTF-8 is_IS.UTF-8
        localedef -i it_IT -f ISO-8859-1 it_IT
        localedef -i it_IT@euro -f ISO-8859-15 it_IT@euro
        localedef -i it_IT -f UTF-8 it_IT.UTF-8
        localedef -i ja_JP -f EUC-JP ja_JP
        localedef -i ja_JP -f UTF-8 ja_JP.UTF-8
        localedef -i nl_NL@euro -f ISO-8859-15 nl_NL@euro
        localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
        localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
        localedef -i se_NO -f UTF-8 se_NO.UTF-8
        localedef -i ta_IN -f UTF-8 ta_IN.UTF-8
        localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
        localedef -i zh_CN -f GB18030 zh_CN.GB18030
        localedef -i zh_HK -f BIG5-HKSCS zh_HK.BIG5-HKSCS
        localedef -i zh_TW -f UTF-8 zh_TW.UTF-8

        mkdir -pv "$work_root/tzdata"
        tar -xf /sources/tzdata2025b.tar.gz -C "$work_root/tzdata"
        cd "$work_root/tzdata"
        zoneinfo=/usr/share/zoneinfo
        mkdir -pv "$zoneinfo/posix" "$zoneinfo/right"
        for tz in etcetera southamerica northamerica europe africa antarctica asia australasia backward; do
            zic -L /dev/null -d "$zoneinfo" "$tz"
            zic -L /dev/null -d "$zoneinfo/posix" "$tz"
            zic -L leapseconds -d "$zoneinfo/right" "$tz"
        done
        cp -v zone.tab zone1970.tab iso3166.tab "$zoneinfo"
        zic -d "$zoneinfo" -p America/New_York
        ln -sv /usr/share/zoneinfo/Europe/Istanbul /etc/localtime

        cat > /etc/nsswitch.conf <<"EOF"
# Begin /etc/nsswitch.conf

passwd: files systemd
group: files systemd
shadow: files systemd

hosts: mymachines resolve [!UNAVAIL=return] files myhostname dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF

        cat > /etc/ld.so.conf <<"EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib
include /etc/ld.so.conf.d/*.conf
# End /etc/ld.so.conf
EOF
        mkdir -pv /etc/ld.so.conf.d
        printf "Installed Glibc 2.42, LFS locales, tr_TR.UTF-8, tzdata2025b, and Europe/Istanbul.\\n"
    '

printf '\nFinished: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Status: PASS\nLog: %s\n' "$LOG"
