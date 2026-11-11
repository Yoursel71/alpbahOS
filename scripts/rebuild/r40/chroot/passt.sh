# DISTROBOX-01, in the chroot of r4-root, from passt-2026_10_02.cba3570 (passt.top snapshot): pasta, the user-mode network
# of rootless Podman. passt also builds passt.avx2 and selects it at run time on CPUs with AVX2.
set -e
make CFLAGS='-O2 -march=x86-64 -mtune=generic' VERSION=2026_10_02.cba3570
make DESTDIR="$STAGE" prefix=/usr install
