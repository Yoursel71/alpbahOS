#!/bin/bash
# CONTEXT: chroot
# REBUILD-R2 chapter 10: kernel 7.1.8 build, modules_install, and the kernel files into /boot
# (book kernel.html: make, make modules_install, cp of bzImage, System.map and .config).
# The /boot file names carry the -alpbahos local version: vmlinuz-7.1.8-alpbahos, System.map-7.1.8-alpbahos,
# config-7.1.8-alpbahos.
set -euo pipefail

KVER=7.1.8
cd "/sources/linux-$KVER"

# Local patch (CPU-BASELINE-03): KVM AVX emulation only with host AVX. The patch file is staged
# to /sources like kernel-$KVER.config (source: scripts/rebuild/ch10/patches/). Idempotent.
PATCH=/sources/kvm-emulate-host-avx-gate.patch
test -f "$PATCH"
if patch -R -p1 --dry-run -s -f < "$PATCH" >/dev/null 2>&1; then
  echo "patch already applied: kvm-emulate-host-avx-gate"
else
  patch -p1 < "$PATCH"
fi

cp /sources/kernel-$KVER.config .config
make olddefconfig

test "$(make -s kernelrelease)" = "$KVER-alpbahos"

make -j"$(nproc)"
rm -rf "/lib/modules/$KVER-alpbahos"
make modules_install

test -f "/lib/modules/$KVER-alpbahos/modules.dep"

cp -v arch/x86/boot/bzImage "/boot/vmlinuz-$KVER-alpbahos"
cp -v System.map "/boot/System.map-$KVER-alpbahos"
cp -v .config "/boot/config-$KVER-alpbahos"

test -f "/boot/vmlinuz-$KVER-alpbahos"
echo "OK 02-kernel-build"
