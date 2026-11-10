#!/bin/bash
# INSTALL-UID-01 / INSTALL-CLEANUP-01: exit-code test of target-live-user.sh and target-cleanup.sh in a chroot of a
# CoW copy of an installed image (no ISO needed). Run as root on the host. The copy is deleted at the end.
# The installed image already went through the old cleanup, so each case first puts the live-only items back
# ("pollute": live user UID 1000 with an empty password, its home, the live polkit rule, sddm autologin User=live),
# then runs one script with a fake /proc/cmdline (bind mount) and compares the exit code with the expected one.
# Usage: a3-chroot-test.sh <installed-raw-image> <work-dir> <repo-live-dir>
set -uo pipefail
export LC_ALL=C
SRC=$1; WD=$2; LIVE_SRC=$3
IMG=$WD/a3test.raw
MNT=$WD/mnt
mkdir -p "$WD" "$MNT"
[ ! -e "$IMG" ] || { echo "$IMG exists"; exit 2; }
cp --reflink=always "$SRC" "$IMG"
LOOP=$(losetup -f --show -P "$IMG")
cleanup() {
    for m in "$MNT/proc/cmdline" "$MNT/proc" "$MNT/sys" "$MNT/dev" "$MNT"; do mountpoint -q "$m" && umount "$m"; done
    losetup -d "$LOOP"; rm -f "$IMG"
}
trap cleanup EXIT
mount "${LOOP}p1" "$MNT"
mount -t proc proc "$MNT/proc"; mount -t sysfs sys "$MNT/sys"; mount --bind /dev "$MNT/dev"
install -d "$MNT/usr/lib/alpbahos"
install -m 755 "$LIVE_SRC/target-live-user.sh" "$LIVE_SRC/target-cleanup.sh" "$MNT/usr/lib/alpbahos/"
C() { chroot "$MNT" /usr/bin/env PATH=/usr/bin:/usr/sbin "$@"; }

pollute() {
    C getent passwd live > /dev/null || C useradd -m -u 1000 -G wheel -s /bin/bash live
    C passwd -d live > /dev/null
    install -d "$MNT/etc/polkit-1/rules.d"
    install -m 644 "$LIVE_SRC/polkit-49-alpbahos-live.rules" "$MNT/etc/polkit-1/rules.d/49-alpbahos-live.rules"
    # The installed sddm.conf has no User= line (Calamares removed it): add one, as the live image has.
    sed -i '/^\[Autologin\]/,/^\[/{/^User=/d}' "$MNT/etc/sddm.conf"
    sed -i 's/^\[Autologin\]$/[Autologin]\nUser=live/' "$MNT/etc/sddm.conf"
    sed -i '/^\[Autologin\]/,/^\[/{s/^Session=.*/Session=plasma.desktop/}' "$MNT/etc/sddm.conf"
    install -d "$MNT/usr/lib/alpbahos"
    install -m 755 "$LIVE_SRC/target-live-user.sh" "$LIVE_SRC/target-cleanup.sh" "$MNT/usr/lib/alpbahos/"
}
cmdline() { echo "BOOT_IMAGE=/boot/vmlinuz root=live:CDLABEL=ALPBAH_LIVE rd.live.image $1" > "$WD/cmdline"
            mountpoint -q "$MNT/proc/cmdline" && umount "$MNT/proc/cmdline"; mount --bind "$WD/cmdline" "$MNT/proc/cmdline"; }
RESULT=0
run_case() { # name expected-rc script cmdline-extra
    local name=$1 want=$2 script=$3 extra=$4 rc
    cmdline "$extra"
    C /bin/sh "/usr/lib/alpbahos/$script" > "$WD/$name.out" 2>&1; rc=$?
    if [ "$rc" = "$want" ]; then echo "PASS $name: rc=$rc (expected $want)"; else echo "FAIL $name: rc=$rc (expected $want)"; RESULT=1; fi
    sed 's/^/    /' "$WD/$name.out"
}

echo "== state of the copied image: / owner $(stat -c %u:%g "$MNT"), uid 1000 in passwd: $(awk -F: '$3==1000{print $1}' "$MNT/etc/passwd")"
# 1. Image as installed by r19 (/ owned by UID 1000): the live-user post-checks must fail even after removal.
pollute
run_case 1-r19-root-owner 1 target-live-user.sh ""
# 2. / owned by root (as build-iso.sh now makes it), uid-1000 leftovers handed to root: removal passes.
chown 0:0 "$MNT"
find "$MNT" -xdev \( -uid 1000 -o -gid 1000 \) ! -path "$MNT/home/live*" -exec chown -h 0:0 {} + 2>/dev/null
pollute
run_case 2-live-user-normal 0 target-live-user.sh ""
# 3. Test hook: removal skipped, post-checks fail.
pollute
run_case 3-live-user-testhook 1 target-live-user.sh "alpbahos.testfail=live-user"
# 4. Cleanup, normal run (live user still present, as if the early step had not run): passes.
pollute
run_case 4-cleanup-normal 0 target-cleanup.sh ""
echo "    after case 4: live=$(C getent passwd live | cut -d: -f1) rule=$(ls "$MNT/etc/polkit-1/rules.d/" 2>/dev/null | tr '\n' ' ') autologin=$(sed -n '/^\[Autologin\]/,/^\[/{/^User=/p}' "$MNT/etc/sddm.conf")"
# 5. Cleanup rerun on a clean target ("already gone"): passes.
install -d "$MNT/usr/lib/alpbahos"
install -m 755 "$LIVE_SRC/target-cleanup.sh" "$MNT/usr/lib/alpbahos/"
run_case 5-cleanup-already-gone 0 target-cleanup.sh ""
# 6. Cleanup test hook: removals skipped, post-checks fail.
pollute
run_case 6-cleanup-testhook 1 target-cleanup.sh "alpbahos.testfail=live-cleanup"
# 7. Only one item left behind (autologin user), no hook: the autologin reset runs and passes; then a drop-in with an
#    autologin user that the reset does cover is checked too.
pollute
printf '[Autologin]\nUser=live\n' > "$MNT/etc/sddm.conf.d/zz-test-autologin.conf"
run_case 7-cleanup-dropin 0 target-cleanup.sh ""
echo "    drop-in after case 7: $(grep -h '^User=' "$MNT/etc/sddm.conf.d/zz-test-autologin.conf")"
rm -f "$MNT/etc/sddm.conf.d/zz-test-autologin.conf"
echo "== overall: $([ $RESULT = 0 ] && echo PASS || echo FAIL)"
exit $RESULT
