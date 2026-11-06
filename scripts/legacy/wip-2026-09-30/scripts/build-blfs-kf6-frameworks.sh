#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build VERSION=6.17.0
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')" LOGDIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOGDIR/kf6-frameworks-$VERSION-$STAMP.log" STATUS="$LOGDIR/kf6-frameworks-$VERSION-$STAMP.status"
fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 && -d "$LFS" && -d "$DATA/lfs" ]]
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 && "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]]
[[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]]
sudo -n true
if ps -eo comm= | awk '$1=="make"||$1=="ninja"||$1=="expect"||$1=="runtest"{f=1} END{exit f?0:1}'; then fail 'Another build/test process is active.'; fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -ec '
[[ -f /usr/share/ECM/cmake/ECMConfig.cmake ]]
[[ -f /opt/qt6/lib/cmake/Qt6/Qt6Config.cmake ]]
[[ -f /opt/qt6/lib/cmake/Qt6LinguistTools/Qt6LinguistToolsConfig.cmake ]]
[[ -f /opt/qt6/lib/cmake/Qt6Svg/Qt6SvgConfig.cmake ]]
[[ -L /opt/kf6/etc/dbus-1 && -L /opt/kf6/share/dbus-1 && -L /opt/kf6/share/polkit-1 && -L /opt/kf6/lib/systemd ]]
'
mkdir -p "$LOGDIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads"
exec 9>"$DATA/locks/lfs-build-writer.lock"; flock -n 9 || fail 'Another LFS writer holds the lock.'
exec > >(tee "$LOG") 2>&1
CURRENT=initial
record(){ local rc=$?; if ((rc==0)); then printf 'KF6_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'KF6_RESULT=FAIL package=%s exit=%s\nLOG=%s\n' "$CURRENT" "$rc" "$LOG" > "$STATUS"; fi; }
trap record EXIT
printf 'BLFS 12.4 KDE Frameworks %s under /opt/kf6; tests and manual checksums skipped.\n' "$VERSION"
printf 'kapidox (documentation generator) omitted; Breeze Icons installed separately.\n'
fetch(){
 local a="$1" u="$2" t="$DATA/downloads/$1.partial-$STAMP"
 if ! sudo -n test -r "$LFS/sources/$a"; then curl -fsSL --retry 3 -o "$t" "$u"; sudo -n install -o 0 -g 0 -m 0644 "$t" "$LFS/sources/$a"; fi
}
stage_backup(){
 local stage="$1" backup="$2"
 sudo -n find "$LFS$stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$backup/staged.list0"
 python3 - "$LFS" "$backup/staged.list0" "$backup/existing.list0" <<'PY'
import os,sys
root,src,dst=sys.argv[1:]
with open(src,'rb') as f: paths=[x for x in f.read().split(b'\0') if x]
old=[]
for p in paths:
 r=os.fsdecode(p)
 if os.path.isabs(r) or '..' in r.split('/'): raise SystemExit('Unsafe staged path')
 if os.path.lexists(os.path.join(root,r)): old.append(p)
with open(dst,'wb') as f:
 for p in sorted(set(old)): f.write(p+b'\0')
print('staged',len(paths),'existing',len(set(old)))
PY
 if [[ -s "$backup/existing.list0" ]]; then
   sudo -n tar -c --numeric-owner --acls --xattrs -f "$backup/preexisting.tar" -C "$LFS" --null -T "$backup/existing.list0"
   sudo -n chown "$(id -u):$(id -g)" "$backup/preexisting.tar"
   sudo -n tar -tf "$backup/preexisting.tar" > "$backup/preexisting.list"
   [[ -s "$backup/preexisting.list" ]] || fail 'Pre-install archive is empty.'
 else printf 'No prior target files.\n' > "$backup/none.txt"; fi
}
build_one(){
 local n="$1" i="$2"; CURRENT="$n"
 local ps="$LOGDIR/kf6-$n-$VERSION.status"
 if [[ -f "$ps" ]] && grep -Eq 'RESULT=(PASS|SKIP_OPTIONAL_DEPENDENCY)' "$ps"; then printf '[%s/69] %s already recorded, skip.\n' "$i" "$n"; return; fi
 if [[ "$n" == networkmanager-qt ]] && ! sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX pkg-config --exists libnm; then
   printf 'PACKAGE=%s VERSION=%s RESULT=SKIP_OPTIONAL_DEPENDENCY MISSING=libnm\n' "$n" "$VERSION" > "$ps"
   printf '[%s/69] %s skipped: optional NetworkManager libnm development files are absent.\n' "$i" "$n"
   return
 fi
 if [[ "$n" == modemmanager-qt ]] && ! sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX pkg-config --exists mm-glib; then
   printf 'PACKAGE=%s VERSION=%s RESULT=SKIP_OPTIONAL_DEPENDENCY MISSING=mm-glib\n' "$n" "$VERSION" > "$ps"
   printf '[%s/69] %s skipped: optional ModemManager development files are absent.\n' "$i" "$n"
   return
 fi
 local a="$n-$VERSION.tar.xz" u="https://download.kde.org/stable/frameworks/6.17/$n-$VERSION.tar.xz"
 local w="/sources/kf6-$VERSION-$STAMP/$n" s="/sources/kf6-$VERSION-$STAMP/$n/$n-$VERSION"
 local b="/sources/kf6-$VERSION-$STAMP/$n/build" st="/sources/kf6-$VERSION-$STAMP/$n/stage" pl="/sources/kf6-$VERSION-$STAMP/$n/package.log"
 local bk="$DATA/backups/kf6-$n-$VERSION-before-final-$STAMP"
 local opts=""
 case "$n" in
   kdbusaddons|kguiaddons|kidletime|kcrash|kglobalaccel|kjobwidgets|kio) opts="-D WITH_X11=OFF" ;;
   kwallet) opts="-D WITH_X11=OFF" ;;
   kwindowsystem) opts="-D KWINDOWSYSTEM_X11=OFF" ;;
 esac
 fetch "$a" "$u"; mkdir -p "$bk"; printf '\n[%s/69] %s\n' "$i" "$n"
 if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX CMAKE_PREFIX_PATH=/opt/qt6:/opt/kf6:/usr ECM_DIR=/usr/share/ECM/cmake Qt6_DIR=/opt/qt6/lib/cmake/Qt6 Qt6LinguistTools_DIR=/opt/qt6/lib/cmake/Qt6LinguistTools Qt6Svg_DIR=/opt/qt6/lib/cmake/Qt6Svg PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig:/opt/kf6/lib/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig LD_LIBRARY_PATH=/opt/qt6/lib:/opt/kf6/lib:/usr/lib MAKEFLAGS=-j4 /bin/bash -s -- "$a" "$w" "$s" "$b" "$st" "$pl" "$opts" <<'BUILD'
set -Eeuo pipefail
a="$1"; w="$2"; s="$3"; b="$4"; st="$5"; pl="$6"; opts="$7"
[[ ! -e "$w" ]] || { echo "Refusing existing work tree $w" >&2; exit 1; }
mkdir -pv "$w"; exec > "$pl" 2>&1
tar -xf "/sources/$a" -C "$w"; [[ -f "$s/CMakeLists.txt" ]]
cmake -S "$s" -B "$b" -D CMAKE_INSTALL_PREFIX=/opt/kf6 -D CMAKE_INSTALL_LIBEXECDIR=libexec -D CMAKE_INSTALL_LIBDIR=lib -D CMAKE_PREFIX_PATH=/opt/qt6 -D ECM_DIR=/usr/share/ECM/cmake -D Qt6_DIR=/opt/qt6/lib/cmake/Qt6 -D CMAKE_SKIP_INSTALL_RPATH=ON -D CMAKE_BUILD_TYPE=Release -D BUILD_TESTING=OFF -D BUILD_PYTHON_BINDINGS=OFF $opts -W no-dev > "$w/configure.log" 2>&1 || { tail -n 100 "$w/configure.log"; exit 1; }
cmake --build "$b" --parallel 4 > "$w/compile.log" 2>&1 || { tail -n 120 "$w/compile.log"; exit 1; }
mkdir -pv "$st"; DESTDIR="$st" cmake --install "$b" > "$w/staged-install.log" 2>&1 || { tail -n 100 "$w/staged-install.log"; exit 1; }
[[ -s "$b/install_manifest.txt" ]]; find "$st/opt/kf6" -mindepth 1 -print -quit | grep -q .
echo BUILD_STAGE=PASS
BUILD
 then
   sudo -n tail -n 100 "$LFS$pl" 2>/dev/null || true
   printf 'PACKAGE=%s VERSION=%s RESULT=FAIL LOG=%s\n' "$n" "$VERSION" "$LOG" > "$ps"
   fail "$n build/stage failed; source and build tree retained."
 fi
 sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$pl" "$LOGDIR/kf6-$n-$VERSION-$STAMP.package.log"
 stage_backup "$st" "$bk"
 if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX CMAKE_PREFIX_PATH=/opt/qt6:/opt/kf6:/usr Qt6_DIR=/opt/qt6/lib/cmake/Qt6 PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig:/opt/kf6/lib/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig LD_LIBRARY_PATH=/opt/qt6/lib:/opt/kf6/lib:/usr/lib /bin/bash -s -- "$b" "$pl" <<'INSTALL'
set -Eeuo pipefail
b="$1"; pl="$2"; exec >> "$pl" 2>&1
cmake --install "$b"; ldconfig
[[ -s "$b/install_manifest.txt" ]]
while IFS= read -r f; do [[ -e "$f" || -L "$f" ]] || { echo "Missing installed path $f" >&2; exit 1; }; done < "$b/install_manifest.txt"
echo INSTALL=PASS
INSTALL
 then
   sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$pl" "$LOGDIR/kf6-$n-$VERSION-$STAMP.package.log"
   sudo -n tail -n 100 "$LFS$pl" || true
   printf 'PACKAGE=%s VERSION=%s RESULT=FAIL LOG=%s BACKUP=%s\n' "$n" "$VERSION" "$LOGDIR/kf6-$n-$VERSION-$STAMP.package.log" "$bk" > "$ps"
   fail "$n final install/manifest failed; backup retained."
 fi
 sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$pl" "$LOGDIR/kf6-$n-$VERSION-$STAMP.package.log"
 printf 'PACKAGE=%s VERSION=%s RESULT=PASS LOG=%s BACKUP=%s\n' "$n" "$VERSION" "$LOGDIR/kf6-$n-$VERSION-$STAMP.package.log" "$bk" > "$ps"
 printf '[%s/69] installed %s.\n' "$i" "$n"
}
packages=(attica karchive kcodecs kconfig kcoreaddons kdbusaddons kdnssd kguiaddons ki18n kidletime kimageformats kitemmodels kitemviews kplotting kwidgetsaddons kwindowsystem networkmanager-qt solid sonnet threadweaver kauth kcompletion kcrash kdoctools kpty kunitconversion kcolorscheme kconfigwidgets kservice kglobalaccel kpackage kdesu kiconthemes knotifications kjobwidgets ktextwidgets kxmlgui kbookmarks kwallet kded kio kdeclarative kcmutils kirigami syndication knewstuff frameworkintegration kparts syntax-highlighting ktexteditor modemmanager-qt kcontacts kpeople bluez-qt kfilemetadata baloo krunner prison qqc2-desktop-style kholidays purpose kcalendarcore kquickcharts knotifyconfig kdav kstatusnotifieritem ksvg ktexttemplate kuserfeedback)
i=0
for p in ${packages[@]}; do i=$((i+1)); build_one "$p" "$i"; done
printf 'KF6_RESULT=PASS\nLOG=%s\nPACKAGE_COUNT=69\nTESTS=SKIPPED\nCHECKSUMS=SKIPPED\n' "$LOG" > "$STATUS"
printf 'KF6 Frameworks sequence completed.\nLog: %s\nStatus: %s\n' "$LOG" "$STATUS"
