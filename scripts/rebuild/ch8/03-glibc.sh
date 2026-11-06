#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, sections 8.5.1-8.5.3: Glibc-2.44 (64-bit, then 32-bit).
# Critical test suite (book): make check. Failures are compared with the book's list;
# any failure outside that list stops this script (stop and investigate).
set -euo pipefail

PKG=glibc-2.44.tar.xz
DIR=glibc-2.44
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.5.1 Installation of Glibc
patch -Np1 -i ../glibc-fhs-1.patch
patch -Np1 -i ../glibc-2.44-upstream_fixes-1.patch

mkdir -v build
cd build

../configure --prefix=/usr \
             --disable-werror \
             --disable-nscd \
             libc_cv_slibdir=/usr/lib \
             --enable-stack-protector=strong \
             --enable-kernel=5.10

make

# Critical test suite. -k keeps going so every failure is listed.
set +e
make -k check > "$TESTS/glibc-check.log" 2>&1
set -e

collect_fails() {
    find . -name '*.sum' -exec grep -h -E '^(FAIL|ERROR|UNRESOLVED): ' {} + 2>/dev/null | sort -u || true
}
KNOWN='^(FAIL|ERROR|UNRESOLVED): (io/tst-lchmod|nss/tst-nss-files-hosts-multi|nptl/tst-thread-affinity|elf/tst-cpu-features-cpuinfo|stdlib/tst-arc4random-thread)'

fails=$(collect_fails)
echo "glibc check: PASS lines: $(find . -name '*.sum' -exec grep -h -c '^PASS: ' {} + | awk '{s+=$1} END{print s+0}')"
echo "glibc check: failing tests:"
printf '%s\n' "$fails" | sed '/^$/d' | tee "$TESTS/glibc-fails.txt"

# Timed-out tests: the book says re-run with a larger timeout factor before judging.
unexpected=$(printf '%s\n' "$fails" | sed '/^$/d' | grep -v -E "$KNOWN" || true)
if [ -n "$unexpected" ]; then
    echo "glibc: re-running non-book failures with TIMEOUTFACTOR=10"
    printf '%s\n' "$unexpected" | sed -E 's/^[A-Z]+: //' | while read -r t; do
        TIMEOUTFACTOR=10 make test t="$t" > "$TESTS/glibc-rerun-${t//\//_}.log" 2>&1 || true
    done
    still=""
    printf '%s\n' "$unexpected" | sed -E 's/^[A-Z]+: //' | while read -r t; do
        if ! grep -q "^PASS: $t" "$TESTS/glibc-rerun-${t//\//_}.log" 2>/dev/null; then
            echo "STILL FAILING: $t"
        fi
    done > "$TESTS/glibc-still-failing.txt"
    if [ -s "$TESTS/glibc-still-failing.txt" ]; then
        cat "$TESTS/glibc-still-failing.txt"
        echo "STOP: glibc test failures outside the book's list"
        exit 1
    fi
fi
echo "glibc check: all failures are in the book's known list (or passed on re-run)"

# 8.5.1 continued: install
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
localedef -i it_IT -f ISO-8859-15 it_IT@euro
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

# 8.5.2.1 Adding nsswitch.conf
cat > /etc/nsswitch.conf << "EOF"
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

# 8.5.2.2 Adding Time Zone Data
tar -xf ../../tzdata2026c.tar.gz

ZONEINFO=/usr/share/zoneinfo
mkdir -pv $ZONEINFO/{posix,right}

for tz in etcetera southamerica northamerica europe africa antarctica \
          asia australasia backward; do
    zic -L /dev/null   -d $ZONEINFO       ${tz}
    zic -L /dev/null   -d $ZONEINFO/posix ${tz}
    zic -L leapseconds -d $ZONEINFO/right ${tz}
done

cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
zic -d $ZONEINFO -p America/New_York
unset ZONEINFO tz

# Book step: tzselect is interactive. The project default is Europe/Istanbul (D120).
ln -sfv /usr/share/zoneinfo/Europe/Istanbul /etc/localtime

# 8.5.2.3 Configuring the Dynamic Loader
cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

EOF

cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf

EOF
mkdir -pv /etc/ld.so.conf.d

# 8.5.3 Building Glibc - 32-bit (the extracted source is reused; the build dir is cleaned)
cd /sources/$DIR/build
rm -rf ./*
find .. -name "*.a" -delete

CC="gcc -m32" CXX="g++ -m32" \
../configure --prefix=/usr \
             --host=i686-pc-linux-gnu \
             --build=$(../scripts/config.guess) \
             --libdir=/usr/lib32 \
             --libexecdir=/usr/lib32 \
             --disable-werror \
             --disable-nscd \
             libc_cv_slibdir=/usr/lib32 \
             --enable-stack-protector=strong \
             --enable-kernel=5.10

make

make DESTDIR=$PWD/DESTDIR install
cp -a DESTDIR/usr/lib32/* /usr/lib32/
install -vm644 DESTDIR/usr/include/gnu/{lib-names,stubs}-32.h \
    /usr/include/gnu/

# Book (8.5.3): add the 32-bit library directory to the dynamic loader config. Missing in the first
# build; the same step is applied to the existing build root by 00-glibc-lib32-conf.sh.
echo "/usr/lib32" > /etc/ld.so.conf.d/lib32.conf
ldconfig

# Caution step from the book: a basic 32-bit compile and link check.
cd /sources/$DIR/build
echo 'int main(){}' > dummy.c
gcc -m32 dummy.c
readelf -l a.out | grep '/ld-linux'
rm -v dummy.c a.out

cd /sources
rm -rf "$DIR"
echo "OK 03-glibc"
