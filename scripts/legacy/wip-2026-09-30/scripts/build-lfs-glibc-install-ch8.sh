#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly WORK_ROOT=/sources/glibc-2.42-ch8-20260926T183002Z
readonly SOURCE_DIR="$WORK_ROOT/glibc-2.42"
readonly BUILD_DIR="$SOURCE_DIR/build"
readonly SUMMARY="$BUILD_DIR/complete-tests.sum"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" == 0 ]] || fail 'Run as root inside the LFS chroot.'
[[ "${ALPBAHOS_D34_INITIAL_EXIT_CODE:-}" == 2 ]] || fail 'Initial Glibc make check did not return the reviewed status 2.'
[[ -f "$SOURCE_DIR/Makefile" && -f "$BUILD_DIR/config.status" ]] || fail 'Preserved Glibc build tree is missing.'

readonly -a SUBDIRS=(csu iconv locale localedata iconvdata assert ctype intl catgets math setjmp signal stdlib stdio-common libio dlfcn nptl rt malloc string wcsmbs timezone time dirent posix io termios resource misc socket sysvipc gmon gnulib wctype manual po argp conform debug mathvec support nptl_db inet resolv nss hesiod sunrpc nis nscd login elf)
for directory in "${SUBDIRS[@]}"; do
    [[ -f "$BUILD_DIR/$directory/subdir-tests.sum" ]] || fail "Missing Glibc test summary for $directory."
done

cd "$BUILD_DIR"
"$SOURCE_DIR/scripts/merge-test-results.sh" -t "$BUILD_DIR/" subdir-tests.sum "${SUBDIRS[@]}" . > "$SUMMARY"
expected_fails=$'FAIL: io/tst-lchmod\nFAIL: misc/tst-rseq'
[[ "$(grep '^FAIL:' "$SUMMARY" || true)" == "$expected_fails" ]] || fail 'Glibc FAIL results differ from the two reviewed D34 candidate cases.'
expected_xpasses=$'XPASS: elf/tst-ifunc-isa-1\nXPASS: elf/tst-ifunc-isa-1-static\nXPASS: elf/tst-ifunc-isa-2\nXPASS: elf/tst-ifunc-isa-2-static'
[[ "$(grep '^XPASS:' "$SUMMARY" || true)" == "$expected_xpasses" ]] || fail 'Glibc XPASS results differ from the four previously reviewed cases.'
! grep -Eq '^(ERROR|UNRESOLVED):' "$SUMMARY" || fail 'Glibc results contain ERROR or UNRESOLVED.'
grep -qx 'PASS: misc/tst-preadvwritev2' "$SUMMARY" || fail 'The previously reported preadv/writev test is not PASS in this candidate run.'
[[ "$(grep -Ec '^PASS:' "$SUMMARY")" == 6565 ]] || fail 'Unexpected Glibc PASS count.'
[[ "$(grep -Ec '^FAIL:' "$SUMMARY")" == 2 ]] || fail 'Unexpected Glibc FAIL count.'
[[ "$(grep -Ec '^XFAIL:' "$SUMMARY")" == 16 ]] || fail 'Unexpected Glibc XFAIL count.'
[[ "$(grep -Ec '^UNSUPPORTED:' "$SUMMARY")" == 521 ]] || fail 'Unexpected Glibc UNSUPPORTED count.'
[[ "$(grep -Ec '^XPASS:' "$SUMMARY")" == 4 ]] || fail 'Unexpected Glibc XPASS count.'
grep -q '^with-lld = no$' "$BUILD_DIR/config.make" || fail 'Expected linker configuration was not found.'
for test in tst-ifunc-isa-1 tst-ifunc-isa-1-static tst-ifunc-isa-2 tst-ifunc-isa-2-static; do
    grep -q '^original exit status 0$' "$BUILD_DIR/elf/$test.test-result" || fail "$test did not exit successfully."
done
for file in /etc/ld.so.conf /etc/nsswitch.conf /etc/localtime; do
    [[ ! -e "$file" && ! -L "$file" ]] || fail "Refusing to overwrite existing configuration: $file"
done
[[ -r /sources/tzdata2025b.tar.gz ]] || fail 'tzdata2025b archive is missing.'

printf 'Glibc D34 candidate test summary retained: PASS=6565 FAIL=2 XFAIL=16 UNSUPPORTED=521 XPASS=4.\n'
printf 'The two FAIL and four XPASS results were checked against the D34 review; none were suppressed.\n'
touch /etc/ld.so.conf
sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
make install
sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd

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
localedef -i zh_HK -f BIG5-HKSCS zh_HK.UTF-8
localedef -i zh_TW -f UTF-8 zh_TW.UTF-8

mkdir -pv "$WORK_ROOT/tzdata"
tar -xf /sources/tzdata2025b.tar.gz -C "$WORK_ROOT/tzdata"
cd "$WORK_ROOT/tzdata"
readonly ZONEINFO=/usr/share/zoneinfo
mkdir -pv "$ZONEINFO/posix" "$ZONEINFO/right"
for zone in etcetera southamerica northamerica europe africa antarctica asia australasia backward; do
    zic -L /dev/null -d "$ZONEINFO" "$zone"
    zic -L /dev/null -d "$ZONEINFO/posix" "$zone"
    zic -L leapseconds -d "$ZONEINFO/right" "$zone"
done
cp -v zone.tab zone1970.tab iso3166.tab "$ZONEINFO"
zic -d "$ZONEINFO" -p America/New_York
ln -sv /usr/share/zoneinfo/Europe/Istanbul /etc/localtime

printf '%s\n' '# Begin /etc/nsswitch.conf' '' 'passwd: files systemd' 'group: files systemd' 'shadow: files systemd' '' 'hosts: mymachines resolve [!UNAVAIL=return] files myhostname dns' 'networks: files' '' 'protocols: files' 'services: files' 'ethers: files' 'rpc: files' '' '# End /etc/nsswitch.conf' > /etc/nsswitch.conf
printf '%s\n' '# Begin /etc/ld.so.conf' '/usr/local/lib' '/opt/lib' 'include /etc/ld.so.conf.d/*.conf' '# End /etc/ld.so.conf' > /etc/ld.so.conf
mkdir -pv /etc/ld.so.conf.d
printf 'Installed LFS Chapter 8 Glibc 2.42 and configured tr_TR.UTF-8 / Europe/Istanbul.\n'
