#!/bin/bash
# INSTALLER-02: preview of the redesigned installer without an ISO build. In a WRITABLE btrfs snapshot of r4-root
# (installer02/root; r4-root is not touched) it
#   1. renders the drivers page pictures (sahne/surucu-*.qml) on an Xvfb screen and saves them as PNG into
#      scripts/rebuild/iso/live/calamares/branding/ (they are committed and installed by build-iso.sh);
#   2. runs Calamares with the live configuration and branding, but a TEST settings.conf: the pages welcome, locale,
#      keyboard, users, packagechooser@drivers, summary, then one exec job that only sleeps (shellprocess, no
#      chroot), then finished. No partition, mount, unpack or bootloader module; /dev is a small tmpfs (null, zero,
#      random, urandom, tty), the host's disks are not visible. Clicks with xdotool at the places the QEMU lanes use
#      (relative to the window), screenshots with xwd after each step.
# Same environment as the live launcher (alpbahos-install: QT_QPA_PLATFORMTHEME=kde, plugin and QML paths) and the
# image's /etc/xdg/kdeglobals. Screen 1280x800 like the QEMU lanes.
# Output: scratch-lfs-bench/installer02/{shots/*.png,calamares.log}. Run as root on the host. KEEP=1 keeps the snapshot.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
LIVE=$WT/scripts/rebuild/iso/live
W=$SB/installer02
R=$W/root
mkdir -p "$W"
[ -e "$R" ] || btrfs subvolume snapshot "$SB/r4-root" "$R" > /dev/null
cleanup() {
    chroot "$R" /bin/sh -c 'pkill -x calamares; pkill -x Xvfb; pkill -x qml' 2>/dev/null || true
    sleep 1
    for m in "$R/dev/pts" "$R/dev/shm" "$R/dev" "$R/proc" "$R/sys" "$R/run" "$R/tmp/.X11-unix"; do
        mountpoint -q "$m" && umount -l "$m"
    done
    if [ "${KEEP:-0}" != 1 ]; then btrfs subvolume delete "$R" > /dev/null; fi
}
trap cleanup EXIT
trap 'echo "failed at line $LINENO"' ERR

# Small /dev: no block devices of the host.
mount -t tmpfs -o mode=755,size=1m tmpfs "$R/dev"
for n in "null c 1 3" "zero c 1 5" "random c 1 8" "urandom c 1 9" "tty c 5 0"; do set -- $n; mknod -m 666 "$R/dev/$1" "$2" "$3" "$4"; done
mkdir -p "$R/dev/pts" "$R/dev/shm"; mount -t devpts devpts "$R/dev/pts" -o gid=5,mode=620,newinstance; mount -t tmpfs tmpfs "$R/dev/shm"
mount -t proc proc "$R/proc"; mount -t sysfs -o ro sysfs "$R/sys"; mount -t tmpfs tmpfs "$R/run"
mkdir -p "$R/tmp/.X11-unix"; mount -t tmpfs -o mode=1777 tmpfs "$R/tmp/.X11-unix"

# Live installer files (as build-iso.sh installs them), then the test settings.
B=$R/usr/share/calamares/branding/alpbahos
rm -rf "$R/etc/calamares" "$B"; mkdir -p "$R/etc/calamares/modules" "$B" "$R/usr/share/alpbahos/calamares"
cp "$LIVE"/calamares/modules/*.conf "$R/etc/calamares/modules/"
cp "$LIVE"/calamares/branding/* "$B/"
cp "$LIVE/calamares/locale.gen" "$R/usr/share/alpbahos/calamares/locale.gen"
install -D -m 644 "$WT/branding/icons/hicolor/scalable/apps/alpbahos-install.svg" "$R/usr/share/icons/hicolor/scalable/apps/alpbahos-install.svg"
cat > "$R/etc/calamares/settings.conf" << 'EOF'
# INSTALLER-02 preview only (onizleme.sh): no disk module.
---
modules-search: [ local ]
branding: alpbahos
prompt-install: true
dont-chroot: true
disable-cancel: false
disable-cancel-during-exec: true
hide-back-and-next-during-exec: true
quit-at-end: false
instances:
- id: drivers
  module: packagechooser
  config: packagechooser_drivers.conf
- id: bekle
  module: shellprocess
  config: shellprocess_bekle.conf
sequence:
- show:
  - welcome
  - locale
  - keyboard
  - users
  - packagechooser@drivers
  - summary
- exec:
  - shellprocess@bekle
- show:
  - finished
EOF
cat > "$R/etc/calamares/modules/shellprocess_bekle.conf" << 'EOF'
---
dontChroot: true
timeout: 200
script:
  - "/bin/sleep 75"
EOF
# The preview has no disk, so the storage requirement is checked but not required.
sed -i '/^    required:/,/^    - storage/d' "$R/etc/calamares/modules/welcome.conf"
grep -q "required:" "$R/etc/calamares/modules/welcome.conf" && { echo "welcome.conf still requires storage"; exit 1; }

E=(env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin HOME=/root XDG_RUNTIME_DIR=/run/xdg LANG=tr_TR.UTF-8 DISPLAY=:91
   QT_PLUGIN_PATH=/usr/lib/plugins:/opt/qt6/plugins QT_QPA_PLATFORMTHEME=kde
   QML2_IMPORT_PATH=/usr/lib/qt6/qml:/opt/qt6/qml:/usr/lib/qml)
mkdir -p "$R/run/xdg"; chmod 700 "$R/run/xdg"
chroot "$R" "${E[@]}" /bin/sh -c 'Xvfb :91 -screen 0 1280x800x24 -nolisten tcp > /tmp/xvfb.log 2>&1 &'
sleep 3
X() { chroot "$R" "${E[@]}" "$@"; }
mkdir -p "$W/shots"
shot() { X xwd -root -silent > "$W/shots/$1.xwd"; magick "xwd:$W/shots/$1.xwd" "$W/shots/$1.png"; rm -f "$W/shots/$1.xwd"; echo "shot $1"; }

# 1. Drivers page pictures
for s in surucu-acik surucu-nvidia; do
    cp "$WT/scripts/rebuild/installer02/sahne/$s.qml" "$R/tmp/$s.qml"
    chroot "$R" "${E[@]}" /bin/sh -c "/opt/qt6/bin/qml /tmp/$s.qml > /tmp/$s.log 2>&1 &"
    sleep 5
    X xwd -root -silent > "$W/$s.xwd"
    magick "xwd:$W/$s.xwd" -crop 1200x640+0+0 +repage "$LIVE/calamares/branding/$s.png"
    rm -f "$W/$s.xwd"
    chroot "$R" pkill -x qml || true
    sleep 1
    cp "$LIVE/calamares/branding/$s.png" "$B/$s.png"
    echo "picture $s.png ($(magick identify -format '%wx%h' "$LIVE/calamares/branding/$s.png"))"
done
chown yrslf: "$LIVE"/calamares/branding/surucu-*.png

# 2. Calamares
chroot "$R" "${E[@]}" /bin/sh -c '/usr/bin/calamares -d > /tmp/calamares.log 2>&1 &'
sleep 12
geo() {  # prints X Y W H of the Calamares main window
    local id; id=$(X xdotool search --onlyvisible --class calamares | tail -1)
    X xdotool getwindowgeometry --shell "$id" | awk -F= '/^X=/{x=$2} /^Y=/{y=$2} /^WIDTH=/{w=$2} /^HEIGHT=/{h=$2} END{print x, y, w, h}'
}
# Next/Kur: 145 px left of the client area's right edge, 15 px above its bottom (r43 i-00: client area x 128..1152,
# y 132..652 under a 28 px title bar; the lanes click 1007,637). Users page fields and driver list rows: the lane's
# absolute clicks minus the client origin (128,132).
# The pointer must rest before the press (an immediate "mousemove ... click" was ignored).
ileri() { read -r x y w h < <(geo); X xdotool mousemove $((x + w - 145)) $((y + h - 15)); sleep 0.5; X xdotool click 1; sleep "${1:-3}"; }
tik() { read -r x y w h < <(geo); X xdotool mousemove $((x + $1)) $((y + $2)); sleep 0.5; X xdotool click 1; sleep 1; }
yaz() { X xdotool key ctrl+a BackSpace; X xdotool type --delay 30 "$1"; sleep 0.5; }
echo "window: $(geo)"
shot 01-hosgeldin
ileri; shot 02-konum
ileri; shot 03-klavye
ileri; shot 04-kullanici
tik 296 49; yaz "Test Kullanıcı"
tik 296 113; yaz "test"
tik 296 177; yaz "alpbahos-test"
tik 296 241; yaz "Deneme-12345"
tik 501 241; yaz "Deneme-12345"
shot 05-kullanici-dolu
ileri; shot 06-suruculer
tik 256 41; shot 07-suruculer-nvidia
ileri; shot 08-ozet
ileri 4; shot 09-onay
X xdotool key Return; sleep 6; shot 10-kurulum-1
sleep 11; shot 11-kurulum-2
sleep 11; shot 12-kurulum-3
sleep 11; shot 13-kurulum-4
sleep 11; shot 14-kurulum-5
sleep 11; shot 15-kurulum-6
sleep 16; shot 16-bitti
cp "$R/tmp/calamares.log" "$W/calamares.log" 2>/dev/null || true
chown -R yrslf: "$W/shots" "$W/calamares.log" 2>/dev/null || true
echo "done $(date +%T)"
