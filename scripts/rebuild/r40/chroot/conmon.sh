# DISTROBOX-01, in the chroot of r4-root, from the unpacked conmon v2.2.1 source (github.com/containers/conmon tag archive).
set -e
make PREFIX=/usr CFLAGS='-O2 -march=x86-64 -mtune=generic' VERSION=2.2.1 GIT_COMMIT=v2.2.1 bin/conmon
install -D -m 755 bin/conmon "$STAGE/usr/libexec/podman/conmon"
