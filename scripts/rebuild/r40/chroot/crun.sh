# DISTROBOX-01, in the chroot of r4-root, from crun-1.30.1.tar.gz (release tarball, signature by Giuseppe Scrivano checked
# on the host). JSON through json-c (recorded before it).
set -e
./configure --prefix=/usr CFLAGS='-O2 -march=x86-64 -mtune=generic'
make -j"$JOBS"
make DESTDIR="$STAGE" install
